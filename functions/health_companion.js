const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
const GROQ_MODEL = "llama-3.3-70b-versatile";

const ACUTE_RISK_PATTERNS = [
  /kill myself/i,
  /want to die/i,
  /end my life/i,
  /hurt myself/i,
  /self.?harm/i,
  /not safe/i,
  /being abused/i,
];

function hasAcuteRisk(text) {
  return ACUTE_RISK_PATTERNS.some((pattern) => pattern.test(text));
}

function detectReplyLanguage(message, appLanguage) {
  const text = String(message ?? "");
  const arabicCount = (text.match(/\p{Script=Arabic}/gu) || []).length;
  const latinCount = (text.match(/\p{Script=Latin}/gu) || []).length;
  if (arabicCount > 0 && arabicCount >= latinCount) return "Arabic";
  if (latinCount > 0) return "English";
  return String(appLanguage ?? "en").toLowerCase().startsWith("ar")
    ? "Arabic"
    : "English";
}

function buildHealthPrompt(appLanguage, message) {
  const selected = String(appLanguage ?? "en").toLowerCase().startsWith("ar")
    ? "Arabic"
    : "English";
  const replyLanguage = detectReplyLanguage(message, appLanguage);
  return `You are Kuda+Lumi Health Companion, a supportive mobile wellbeing assistant.

Your role is early support and safe navigation, not diagnosis or treatment.

Rules:
- Be warm, concise, culturally respectful, and easy to understand.
- Reflect what the user reported; do not invent symptoms, measurements, or history.
- Clearly distinguish user-reported information from an AI interpretation.
- Never diagnose, prescribe, or claim that a result is medically normal or abnormal without clinician review.
- Suggest one or two practical, low-risk next steps.
- Encourage professional care when symptoms persist, worsen, or concern the user.
- If the user indicates self-harm, abuse, or immediate danger, acknowledge it seriously and encourage contacting local emergency services or a trusted person now. Do not ask for method details.
- Do not encourage secrecy or imply that you replace a clinician.
- User's selected app language is: ${selected}. You MUST reply ONLY in ${selected}. Never reply in ${selected === "Arabic" ? "English" : "Arabic"} unless the user types in ${selected === "Arabic" ? "English" : "Arabic"}.
- Detect language from the latest user message, not just settings. The latest message indicates ${replyLanguage}; reply ONLY in ${replyLanguage} for this turn. Never mix languages in one reply.
- Use plain text only, with no Markdown, headings, bold, or bullet lists. Reply warmly and briefly in 2–3 sentences. For Arabic, use Gulf-friendly Modern Standard Arabic suitable for Dubai, not Egyptian dialect.

After the user-facing response, output one JSON line with exactly this shape:
{"safety_flag":true|false,"suggested_action":"self_care|monitor|contact_clinician|urgent_help|none","confidence":"low|medium|high"}

Set safety_flag true only for acute danger, self-harm, abuse, or immediate safety concerns.`;
}

function parseOutput(rawText) {
  const lines = rawText.trim().split("\n");
  let metadata = {};
  let replyLines = lines;

  for (let i = lines.length - 1; i >= 0; i -= 1) {
    const candidate = lines[i].trim();
    if (candidate.startsWith("{") && candidate.endsWith("}")) {
      try {
        metadata = JSON.parse(candidate);
        replyLines = lines.slice(0, i);
      } catch (_) {
        // Keep the full response as user-facing text if metadata is malformed.
      }
      break;
    }
  }

  return {
    reply: stripMarkdown(replyLines.join("\n").trim()),
    safetyFlagFromModel: metadata.safety_flag === true,
    suggestedAction: metadata.suggested_action || "none",
    confidence: metadata.confidence || "low",
  };
}

function stripMarkdown(text) {
  return String(text ?? "")
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/^[ \t]{0,3}#{1,6}[ \t]+/gm, "")
    .replace(/^[ \t]*[-*+][ \t]+/gm, "")
    .replace(/^[ \t]*\d+[.)][ \t]+/gm, "")
    .replace(/\*\*(.*?)\*\*|__(.*?)__/g, (_, a, b) => a ?? b ?? "")
    .replace(/(?<!\w)\*([^*\n]+)\*(?!\w)/g, "$1")
    .replace(/(?<!\w)_([^_\n]+)_(?!\w)/g, "$1")
    .trim();
}

exports.healthCompanionChat = onCall(
  { secrets: [GROQ_API_KEY], region: "us-central1", maxInstances: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }

    const message = (request.data?.message || "").toString().trim();
    const appLanguage = request.data?.appLanguage ?? request.data?.locale ?? "en";
    if (!message) {
      throw new HttpsError("invalid-argument", "message is required.");
    }
    if (message.length > 2000) {
      throw new HttpsError("invalid-argument", "message too long.");
    }

    const acuteRiskDetected = hasAcuteRisk(message);
    const groqResponse = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${GROQ_API_KEY.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        temperature: 0.2,
        max_completion_tokens: 450,
        messages: [
          { role: "system", content: buildHealthPrompt(appLanguage, message) },
          { role: "user", content: message },
        ],
      }),
    });

    if (!groqResponse.ok) {
      console.error("Groq request failed", groqResponse.status);
      throw new HttpsError("unavailable", "The health companion is temporarily unavailable.");
    }

    const payload = await groqResponse.json();
    const rawText = payload.choices?.[0]?.message?.content?.toString().trim();
    if (!rawText) {
      throw new HttpsError("internal", "The health companion returned an empty response.");
    }

    const parsed = parseOutput(rawText);
    return {
      reply: parsed.reply,
      safetyFlagRaised: acuteRiskDetected || parsed.safetyFlagFromModel,
      suggestedAction: acuteRiskDetected ? "urgent_help" : parsed.suggestedAction,
      confidence: parsed.confidence,
      model: GROQ_MODEL,
    };
  },
);
