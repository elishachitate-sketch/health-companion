import test from "node:test";
import assert from "node:assert/strict";
import {
  buildLanguageInstruction,
  detectReplyLanguage,
  parseResponse,
} from "./index.js";

test("parseResponse removes pretty-printed trailing safety JSON", () => {
  const parsed = parseResponse(`I hear that this has been difficult.\n\n{
  "safety_flag": false,
  "suggested_action": "self_care",
  "confidence": "medium"
}`);

  assert.equal(parsed.reply, "I hear that this has been difficult.");
  assert.deepEqual(parsed.metadata, {
    safety_flag: false,
    suggested_action: "self_care",
    confidence: "medium",
  });
});

test("parseResponse recognizes the user's saftey_flag spelling", () => {
  const parsed = parseResponse(`Helpful reply.\n{
  "saftey_flag": false,
  "suggested_action": "none"
}`);

  assert.equal(parsed.reply, "Helpful reply.");
  assert.equal(parsed.metadata.saftey_flag, false);
});

test("parseResponse removes fenced metadata without leaving the json opener", () => {
  const parsed = parseResponse(`I hear you. Let's take this one step at a time.

\`\`\`json
{
  "saftey_flag": false,
  "suggested_action": "none"
}
\`\`\``);

  assert.equal(parsed.reply, "I hear you. Let's take this one step at a time.");
  assert.equal(parsed.reply.includes("```json"), false);
  assert.equal(parsed.reply.includes("saftey_flag"), false);
});

test("parseResponse extracts a reply from a complete JSON response", () => {
  const parsed = parseResponse(`\`\`\`json
{
  "reply": "Try taking one small step today.",
  "safety_flag": false
}
\`\`\``);

  assert.equal(parsed.reply, "Try taking one small step today.");
  assert.equal(parsed.metadata.safety_flag, false);
});

test("parseResponse leaves ordinary prose unchanged", () => {
  const parsed = parseResponse("I can help you think through that.");
  assert.equal(parsed.reply, "I can help you think through that.");
  assert.deepEqual(parsed.metadata, {});
});

test("latest message language overrides selected app language", () => {
  assert.equal(detectReplyLanguage("hello", "ar"), "en");
  assert.equal(detectReplyLanguage("مرحبا", "en"), "ar");
  assert.equal(detectReplyLanguage("123?!", "ar"), "ar");
});

test("Arabic setting prompt allows English only when the user types English", () => {
  const prompt = buildLanguageInstruction("ar", "hello");
  assert.match(prompt, /User's selected app language is: Arabic/);
  assert.match(prompt, /You MUST reply ONLY in Arabic/);
  assert.match(prompt, /Never reply in English unless user types in English/);
  assert.match(prompt, /latest message is in English/);
  assert.match(prompt, /reply ONLY in English for this turn/);
});

test("parseResponse removes markdown from visible prose", () => {
  const parsed = parseResponse("## Hello\n\n- **Warm** and *short*.");
  assert.equal(parsed.reply, "Hello\n\nWarm and short.");
});
