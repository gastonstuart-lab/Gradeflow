import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const MAX_MESSAGE_LENGTH = 2000;
const MAX_CONVERSATION_ITEMS = 20;
const MAX_CONVERSATION_CONTENT_LENGTH = 2000;
const MAX_CONTEXT_MODE_LENGTH = 64;

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

export const askInstructOS = onCall<AskInstructOSPayload>(
  {region: "us-central1"},
  (request): AskInstructOSResponse => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in is required to use Ask InstructOS.",
      );
    }

    const payload = validatePayload(request.data);

    // Do not log full user messages. Keep logs limited to safe operational
    // metadata until privacy review, rate limiting, and real AI are added.
    logger.info("Ask InstructOS placeholder invoked", {
      uid: request.auth.uid,
      messageLength: payload.message.length,
      conversationItems: payload.conversation?.length ?? 0,
      contextMode: payload.contextMode ?? "none",
    });

    return {reply: PLACEHOLDER_REPLY};
  },
);

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
