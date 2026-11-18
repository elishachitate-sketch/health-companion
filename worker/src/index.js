import { classifyVisitMessage } from "./visit_routing.js";

const ACUTE_RISK_PATTERNS = [
  /kill myself/i,
  /want to die/i,
  /end my life/i,
  /hurt myself/i,
  /self.?harm/i,
  /not safe/i,
  /being abused/i,
];

const SYSTEM_PROMPT = `You are Kuda+Lumi Health Companion, a supportive mobile wellbeing assistant.
Provide early support and safe navigation, not diagnosis or treatment.
Be warm, concise, and plain-spoken. Reflect only what the user reports.
Never diagnose, prescribe, invent medical measurements, or claim to replace a clinician.
Suggest one or two practical low-risk next steps.
For self-harm, abuse, or immediate danger, encourage local emergency services or a trusted person now and do not ask for method details.
Use plain text only. Do not use Markdown, headings, bold, or bullet lists.
Reply warmly and briefly in 2–3 sentences. Never mix languages within one reply.
When replying in Arabic, use Gulf-friendly Modern Standard Arabic suitable for Dubai, not Egyptian dialect.
After the reply, output JSON: {"safety_flag":true|false,"suggested_action":"self_care|monitor|contact_clinician|urgent_help|none","confidence":"low|medium|high"}`;

export function detectReplyLanguage(message, appLanguage) {
  const text = String(message ?? "");
  const arabicCount = (text.match(/\p{Script=Arabic}/gu) || []).length;
  const latinCount = (text.match(/\p{Script=Latin}/gu) || []).length;
  if (arabicCount > 0 && arabicCount >= latinCount) return "ar";
  if (latinCount > 0) return "en";
  return String(appLanguage ?? "en").toLowerCase().startsWith("ar") ? "ar" : "en";
}

export function buildLanguageInstruction(appLanguage, message) {
  const selected = String(appLanguage ?? "en").toLowerCase().startsWith("ar")
    ? "Arabic"
    : "English";
  const replyLanguage = detectReplyLanguage(message, appLanguage);
  const replyName = replyLanguage === "ar" ? "Arabic" : "English";
  const selectedRule = selected === "Arabic"
    ? "You MUST reply ONLY in Arabic. Never reply in English unless user types in English."
    : "You MUST reply ONLY in English. Never reply in Arabic unless user types in Arabic.";
  return `User's selected app language is: ${selected}. ${selectedRule} The user's latest message is in ${replyName}, so reply ONLY in ${replyName} for this turn. Detect language from the latest message, not just settings. If it has no detectable language, use the selected app language. Never mix languages in one reply.`;
}

export function stripMarkdown(text) {
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

function acuteRisk(message) {
  return ACUTE_RISK_PATTERNS.some((pattern) => pattern.test(message));
}

export function parseResponse(text) {
  const source = String(text ?? "").trim();
  try {
    const complete = JSON.parse(source.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, ""));
    if (complete && typeof complete === "object" && !Array.isArray(complete)) {
      const explicitReply = complete.reply ?? complete.message ?? complete.content;
      if (typeof explicitReply === "string") {
        return { reply: stripMarkdown(explicitReply), metadata: complete };
      }
    }
  } catch (_) {
    // The model may place a trailing metadata object after ordinary prose.
  }
  const starts = [...source.matchAll(/\{/g)].map((match) => match.index);

  for (const start of starts.reverse()) {
    const candidate = source.slice(start)
      .replace(/^```(?:json)?\s*/i, "")
      .replace(/\s*```$/, "")
      .trim();
    try {
      const value = JSON.parse(candidate);
      if (!value || typeof value !== "object" || Array.isArray(value)) continue;

      const hasMetadata = "safety_flag" in value || "saftey_flag" in value ||
        "suggested_action" in value || "confidence" in value;
      const explicitReply = value.reply ?? value.message ?? value.content;
      if (typeof explicitReply === "string") {
        return { reply: stripMarkdown(explicitReply), metadata: value };
      }
      if (hasMetadata) {
        const reply = source.slice(0, start)
          .replace(/```(?:json)?\s*$/i, "")
          .trim();
        return { reply: stripMarkdown(reply), metadata: value };
      }
    } catch (_) {
      // Try an earlier opening brace; JSON may be pretty-printed over lines.
    }
  }

  return { reply: stripMarkdown(source.replace(/```/g, "")), metadata: {} };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/voice") {
      return handleVoiceUpgrade(request, env);
    }
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }
    if (request.method !== "POST") {
      return json({ error: "POST required" }, 405);
    }

    const body = await request.json().catch(() => null);
    const message = body?.message?.toString().trim();
    const routing = classifyVisitMessage(message || "", "user_report");
    const backendUrgent = routing.urgentHandoff;
    const appLanguage = (body?.appLanguage ?? body?.locale ?? "en").toString()
      .toLowerCase().startsWith("ar") ? "ar" : "en";
    const locale = appLanguage === "ar" ? "ar-SA" : "en-US";
    const history = Array.isArray(body?.history) ? body.history : [];
    if (!message || message.length > 2000) {
      return json({ error: "message must be between 1 and 2000 characters" }, 400);
    }

    const risk = acuteRisk(message);
    const groq = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "openai/gpt-oss-20b",
        temperature: 0.2,
        max_completion_tokens: 450,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "system", content: buildLanguageInstruction(appLanguage, message) },
          { role: "system", content: `Routing metadata: ${JSON.stringify(routing)}. Treat this as a request for human routing, not a diagnosis. If urgentHandoff is true, tell the user to seek immediate local human help. Do not ignore this safety flag.` },
          ...history.slice(-12).filter((item) =>
            (item?.role === "user" || item?.role === "assistant") &&
            typeof item?.content === "string" && item.content.length <= 4000,
          ),
          { role: "user", content: message },
        ],
      }),
    });

    if (!groq.ok) {
      const errorBody = await groq.text();
      console.error('Groq request failed', groq.status, errorBody.slice(0, 500));
      return json({ error: "Health companion unavailable" }, 503);
    }
    const payload = await groq.json();
    const raw = payload.choices?.[0]?.message?.content?.toString();
    if (!raw) return json({ error: "Empty model response" }, 502);

    const parsed = parseResponse(raw);
    return json({
      reply: stripMarkdown(parsed.reply),
      safetyFlagRaised: risk || backendUrgent || parsed.metadata.safety_flag === true || parsed.metadata.saftey_flag === true,
      suggestedAction: (risk || backendUrgent) ? "urgent_help" : routing.route === "clinician_review" ? "contact_clinician" : parsed.metadata.suggested_action || "none",
      confidence: parsed.metadata.confidence || "low",
      visitRouting: routing,
      locale,
      appLanguage,
    });
  },
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

async function handleVoiceUpgrade(request, env) {
  if (request.method !== "GET" || request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
    return json({ error: "WebSocket upgrade required" }, 426);
  }
  const allowedOrigin = env.ALLOWED_ORIGIN;
  const origin = request.headers.get("Origin");
  if (allowedOrigin && origin && origin !== allowedOrigin) {
    return json({ error: "Origin not allowed" }, 403);
  }
  if (!env.VOICE_GATEWAY_URL) {
    return json({ error: "Live voice gateway is not configured" }, 503);
  }
  let upstreamUrl;
  try {
    upstreamUrl = new URL(env.VOICE_GATEWAY_URL);
  } catch (_) {
    return json({ error: "Live voice gateway configuration is invalid" }, 503);
  }
  if (upstreamUrl.protocol !== "wss:") {
    return json({ error: "Live voice gateway must use secure wss:// transport" }, 503);
  }

  const requestedProtocols = (request.headers.get("Sec-WebSocket-Protocol") || "")
    .split(",").map((part) => part.trim()).filter(Boolean);
  const protocol = requestedProtocols.includes("basira-voice-v1") ? "basira-voice-v1" : null;
  if (!protocol) {
    return json({ error: "Basira voice protocol required" }, 400);
  }

  let upstreamResponse;
  try {
    upstreamResponse = await fetch(upstreamUrl, {
      headers: {
        Upgrade: "websocket",
        "Sec-WebSocket-Protocol": protocol,
      },
    });
  } catch (_) {
    return json({ error: "Live voice service unavailable" }, 503);
  }
  const upstream = upstreamResponse.webSocket;
  if (upstreamResponse.status !== 101 || !upstream) {
    return json({ error: "Live voice authentication or upgrade failed" }, 502);
  }

  const pair = new WebSocketPair();
  const client = pair[0];
  const server = pair[1];
  server.accept();
  upstream.accept();
  let authFrameForwarded = false;
  let authAccepted = false;
  server.addEventListener("message", (event) => {
    try {
      if (!authFrameForwarded) {
        if (typeof event.data !== "string") throw new Error("authentication frame must be text");
        const firstFrame = JSON.parse(event.data);
        const token = firstFrame?.accessToken;
        if (firstFrame?.type !== "auth.authenticate" || typeof token !== "string" || token.length < 20 || token.length > 4096) {
          throw new Error("invalid authentication frame");
        }
        authFrameForwarded = true;
      } else if (!authAccepted) {
        throw new Error("authentication required before session data");
      }
      upstream.send(event.data);
    } catch (error) {
      server.close(1008, error.message || "invalid session");
      upstream.close(1008, "invalid client session");
    }
  });
  upstream.addEventListener("message", (event) => {
    try {
      if (typeof event.data === "string") {
        const response = JSON.parse(event.data);
        if (response?.type === "auth.accepted" && authFrameForwarded) authAccepted = true;
        if (response?.type === "auth.rejected") {
          server.close(1008, "authentication rejected");
          upstream.close(1008, "authentication rejected");
          return;
        }
        if (!authAccepted && response?.type !== "auth.accepted") return;
      } else if (!authAccepted) {
        return;
      }
      server.send(event.data);
    } catch (_) {
      server.close(1011, "voice relay failed");
    }
  });
  for (const [source, destination] of [[server, upstream], [upstream, server]]) {
    source.addEventListener("close", (event) => {
      try { destination.close(event.code || 1000, event.reason || "peer closed"); } catch (_) {}
    });
    source.addEventListener("error", () => {
      try { destination.close(1011, "voice relay error"); } catch (_) {}
    });
  }
  return new Response(null, {
    status: 101,
    webSocket: client,
    headers: { "Sec-WebSocket-Protocol": protocol },
  });
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}
