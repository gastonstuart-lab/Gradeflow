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
const OPENAI_MAX_OUTPUT_TOKENS = 450;

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

const PLACEHOLDER_REPLY =
  "Ask InstructOS backend is ready. Real AI connection will be added in a later slice.";

const PROVIDER_FALLBACK_REPLY =
  "Ask InstructOS is temporarily unable to reach the AI provider. Please try again soon.";

const ASSISTANT_INSTRUCTIONS = [
  "Ask InstructOS is a teacher assistant inside InstructOS.",
  "It can help plan lessons, draft ideas, create quizzes, and organise teaching work.",
  "It must not claim access to class data, student records, planner data, or live app tools yet.",
  "It should be concise, useful, and teacher-friendly.",
  "It should refuse to pretend it has accessed data it has not been given.",
].join(" ");

export const askInstructOS = onCall<AskInstructOSPayload>(
  {region: "us-central1", secrets: [OPENAI_API_KEY]},
  async (request): Promise<AskInstructOSResponse> => {
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
      logger.info("Ask InstructOS OpenAI secret unavailable; using fallback", {
        uid: request.auth.uid,
        messageLength: payload.message.length,
        conversationItems: payload.conversation?.length ?? 0,
        contextMode: payload.contextMode ?? "none",
      });
      return {reply: PLACEHOLDER_REPLY};
    }

    const reply = await fetchOpenAiReply(payload, apiKey, request.auth.uid);
    return {reply};
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
      logger.warn("Ask InstructOS OpenAI request failed", {
        uid,
        status: response.status,
        statusClass: `${Math.floor(response.status / 100)}xx`,
        latencyMs,
      });
      return PROVIDER_FALLBACK_REPLY;
    }

    const data = await response.json() as unknown;
    const reply = extractOpenAiReply(data);
    if (reply === undefined) {
      logger.warn("Ask InstructOS OpenAI response missing text", {
        uid,
        latencyMs,
      });
      return PROVIDER_FALLBACK_REPLY;
    }

    logger.info("Ask InstructOS OpenAI request succeeded", {
      uid,
      latencyMs,
      replyLength: reply.length,
    });
    return reply;
  } catch (error) {
    const latencyMs = Date.now() - startedAt;
    logger.warn("Ask InstructOS OpenAI request errored", {
      uid,
      latencyMs,
      errorName: error instanceof Error ? error.name : "unknown",
    });
    return PROVIDER_FALLBACK_REPLY;
  } finally {
    clearTimeout(timeout);
  }
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
