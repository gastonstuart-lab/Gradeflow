import {logger} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const MAX_MESSAGE_LENGTH = 2000;
const MAX_CONVERSATION_ITEMS = 20;
const MAX_CONVERSATION_CONTENT_LENGTH = 2000;
const MAX_CONTEXT_MODE_LENGTH = 64;
const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const OPENAI_MODEL = "gpt-4.1-mini";
const OPENAI_TIMEOUT_MS = 12000;
const OPENAI_MAX_OUTPUT_TOKENS = 700;

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

type AssistantRole = "user" | "assistant" | "system";

interface ConversationItem {
  role: AssistantRole;
  content: string;
}

interface AskInstructOSPayload {
  message: string;
  conversation?: ConversationItem[];
  contextMode?: string;
}

interface AskInstructOSResponse {
  reply: string;
}

const ASSISTANT_INSTRUCTIONS = [
  "Ask InstructOS is a premium teacher co-pilot inside InstructOS.",
  "Sound calm, professional, practical, and already embedded in the teacher's workspace.",
  "Use any provided InstructOS home or class context as working context, but never claim access to data, records, or tools that were not included in the request.",
  "For factual questions about classes, students, reminders, or the current workspace, answer directly from the provided InstructOS context when the value is present.",
  "Never invent student counts, roster details, names, or class membership. If a value is unknown, say what context is visible and what specific data is missing.",
  "If the context includes a total student count, use it when asked how many students the teacher has. If per-class counts are included, use the matching class count for class-specific questions.",
  "Do not respond like a generic chatbot. Prefer a useful draft, checklist, rubric, message, or plan over asking for broad clarification.",
  "For lesson-planning requests, infer a sensible next-lesson plan from the available class, subject, date, syllabus, reminders, and conversation context.",
  "If exact topic or grade context is missing, still provide a teacher-ready starter plan with warm-up, main activity, check for understanding, and exit task, then ask one focused follow-up question at the end.",
  "Avoid opening with 'please provide the subject, grade level, and topic' unless there is truly no usable context and no productive default.",
  "Keep replies concise, structured, and classroom-ready. Use bullets or short sections when helpful.",
  "When making assumptions, state them briefly and make them easy for the teacher to correct.",
].join(" ");

export const askInstructOS = onCall<AskInstructOSPayload>(
  {region: "us-central1", secrets: [OPENAI_API_KEY], invoker: "public"},
  async (request): Promise<AskInstructOSResponse> => {
    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "Sign in is required to use Ask InstructOS.",
        );
      }

      const payload = validatePayload(request.data);

      // Do not log full user messages. Keep logs limited to safe operational
      // metadata until privacy review, rate limiting, and real AI are added.
      logger.info("Ask InstructOS invoked", {
        uid: request.auth.uid,
        messageLength: payload.message.length,
        conversationItems: payload.conversation?.length ?? 0,
        contextMode: payload.contextMode ?? "none",
      });

      const apiKey = getOpenAiApiKey();
      if (apiKey === undefined) {
        logger.warn("Ask InstructOS OpenAI secret unavailable", {
          uid: request.auth.uid,
        });
        throw new HttpsError(
          "failed-precondition",
          "OPENAI_API_KEY is not available to this function.",
        );
      }

      const reply = await fetchOpenAiReply(payload, apiKey, request.auth.uid);
      return {reply};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error("Ask InstructOS unexpected handler error", {
        errorName: error instanceof Error ? error.name : "unknown",
        errorMessage:
          error instanceof Error ? sanitizeForLog(error.message) : undefined,
      });
      throw new HttpsError("internal", "Ask InstructOS failed unexpectedly.");
    }
  },
);

function getOpenAiApiKey(): string | undefined {
  try {
    const value = OPENAI_API_KEY.value().trim();
    return value.length === 0 ? undefined : value;
  } catch {
    return undefined;
  }
}

async function fetchOpenAiReply(
  payload: AskInstructOSPayload,
  apiKey: string,
  uid: string,
): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), OPENAI_TIMEOUT_MS);
  const startedAt = Date.now();

  try {
    const response = await fetch(OPENAI_RESPONSES_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        instructions: ASSISTANT_INSTRUCTIONS,
        input: buildOpenAiInput(payload),
        max_output_tokens: OPENAI_MAX_OUTPUT_TOKENS,
      }),
      signal: controller.signal,
    });

    const latencyMs = Date.now() - startedAt;
    if (!response.ok) {
      const providerMessage = await readProviderErrorMessage(response);
      logger.warn("Ask InstructOS OpenAI request failed", {
        uid,
        status: response.status,
        statusClass: `${Math.floor(response.status / 100)}xx`,
        providerMessage,
        latencyMs,
      });
      throw new HttpsError("unavailable", "AI provider request failed.");
    }

    const data = await response.json() as unknown;
    const reply = extractOpenAiReply(data);
    if (reply === undefined) {
      logger.warn("Ask InstructOS OpenAI response missing text", {
        uid,
        latencyMs,
      });
      throw new HttpsError(
        "unavailable",
        "AI provider response did not include usable reply text.",
      );
    }

    logger.info("Ask InstructOS OpenAI request succeeded", {
      uid,
      latencyMs,
      replyLength: reply.length,
    });
    return reply;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    const latencyMs = Date.now() - startedAt;
    logger.warn("Ask InstructOS OpenAI request errored", {
      uid,
      latencyMs,
      errorName: error instanceof Error ? error.name : "unknown",
      errorMessage:
        error instanceof Error ? sanitizeForLog(error.message) : undefined,
    });

    if (error instanceof Error && error.name === "AbortError") {
      throw new HttpsError(
        "unavailable",
        "AI provider request timed out. Please try again.",
      );
    }

    throw new HttpsError(
      "unavailable",
      "AI provider is currently unavailable. Please try again.",
    );
  } finally {
    clearTimeout(timeout);
  }
}

async function readProviderErrorMessage(
  response: Response,
): Promise<string | undefined> {
  try {
    const data = await response.json() as unknown;
    if (!isRecord(data)) return undefined;

    const errorValue = data.error;
    if (!isRecord(errorValue)) return undefined;

    const message = errorValue.message;
    if (typeof message !== "string") return undefined;

    return sanitizeForLog(message);
  } catch {
    return undefined;
  }
}

function sanitizeForLog(value: string): string {
  return value.replace(/\s+/g, " ").trim().slice(0, 240);
}

function buildOpenAiInput(payload: AskInstructOSPayload): string {
  const lines = [
    "Use only the information below. Do not claim access to app data or tools.",
  ];

  if (payload.contextMode !== undefined) {
    lines.push(`Context mode: ${payload.contextMode}`);
  }

  if (payload.conversation !== undefined && payload.conversation.length > 0) {
    lines.push("Recent conversation:");
    for (const item of payload.conversation) {
      lines.push(`${item.role}: ${item.content}`);
    }
  }

  lines.push(`Current user message: ${payload.message}`);
  return lines.join("\n");
}

function extractOpenAiReply(value: unknown): string | undefined {
  if (!isRecord(value)) return undefined;

  const outputText = value.output_text;
  if (typeof outputText === "string" && outputText.trim().length > 0) {
    return outputText.trim();
  }

  const output = value.output;
  if (!Array.isArray(output)) return undefined;

  const chunks: string[] = [];
  for (const item of output) {
    if (!isRecord(item)) continue;
    const content = item.content;
    if (!Array.isArray(content)) continue;
    for (const contentItem of content) {
      if (!isRecord(contentItem)) continue;
      const text = contentItem.text;
      if (typeof text === "string" && text.trim().length > 0) {
        chunks.push(text.trim());
      }
    }
  }

  const reply = chunks.join("\n").trim();
  return reply.length === 0 ? undefined : reply;
}

function validatePayload(value: unknown): AskInstructOSPayload {
  if (!isRecord(value)) {
    throw invalidArgument("Payload must be an object.");
  }

  const rawMessage = value.message;
  if (typeof rawMessage !== "string") {
    throw invalidArgument("Message must be a string.");
  }

  const message = rawMessage.trim();
  if (message.length === 0) {
    throw invalidArgument("Message must not be empty.");
  }

  if (message.length > MAX_MESSAGE_LENGTH) {
    throw invalidArgument(
      `Message must be ${MAX_MESSAGE_LENGTH} characters or fewer.`,
    );
  }

  const contextMode = validateContextMode(value.contextMode);
  const conversation = validateConversation(value.conversation);

  return {
    message,
    ...(conversation === undefined ? {} : {conversation}),
    ...(contextMode === undefined ? {} : {contextMode}),
  };
}

function validateConversation(value: unknown): ConversationItem[] | undefined {
  if (value === undefined) return undefined;
  if (!Array.isArray(value)) {
    throw invalidArgument("Conversation must be an array when provided.");
  }

  if (value.length > MAX_CONVERSATION_ITEMS) {
    throw invalidArgument(
      `Conversation must include ${MAX_CONVERSATION_ITEMS} items or fewer.`,
    );
  }

  return value.map((item, index) => {
    if (!isRecord(item)) {
      throw invalidArgument(`Conversation item ${index} must be an object.`);
    }

    const role = item.role;
    if (role !== "user" && role !== "assistant" && role !== "system") {
      throw invalidArgument(
        `Conversation item ${index} has an unsupported role.`,
      );
    }

    const content = item.content;
    if (typeof content !== "string") {
      throw invalidArgument(
        `Conversation item ${index} content must be a string.`,
      );
    }

    const trimmedContent = content.trim();
    if (trimmedContent.length === 0) {
      throw invalidArgument(
        `Conversation item ${index} content must not be empty.`,
      );
    }

    if (trimmedContent.length > MAX_CONVERSATION_CONTENT_LENGTH) {
      throw invalidArgument(
        `Conversation item ${index} content must be ${MAX_CONVERSATION_CONTENT_LENGTH} characters or fewer.`,
      );
    }

    return {role, content: trimmedContent};
  });
}

function validateContextMode(value: unknown): string | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== "string") {
    throw invalidArgument("contextMode must be a string when provided.");
  }

  const contextMode = value.trim();
  if (contextMode.length === 0) return undefined;
  if (contextMode.length > MAX_CONTEXT_MODE_LENGTH) {
    throw invalidArgument(
      `contextMode must be ${MAX_CONTEXT_MODE_LENGTH} characters or fewer.`,
    );
  }

  return contextMode;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function invalidArgument(message: string): never {
  throw new HttpsError("invalid-argument", message);
}
