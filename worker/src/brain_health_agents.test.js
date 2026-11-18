import test from "node:test";
import assert from "node:assert/strict";
import {
  runClinicalContextAgent,
  runEvidenceDocumentationAgent,
  runQualityEquityAudit,
} from "./brain_health_agents.js";

const env = { GROQ_API_KEY: "test-key", GROQ_MODEL: "synthetic-test-model" };
const auditEvents = [];
const audit = async (event) => auditEvents.push(event);

function mockFetch(content) {
  return async (_url, request) => {
    const body = JSON.parse(request.body);
    assert.equal(body.response_format.type, "json_object");
    return new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify(content) } }] }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };
}

test("clinical context returns seven source-linked categories", async () => {
  const categories = ["physical", "metabolic", "sleep", "mental_wellbeing", "lifestyle", "family_history", "genomic"];
  const output = {
    schemaVersion: "clinical-context-v1",
    subjectToken: "synthetic-token-123",
    factors: categories.map((category) => ({
      category,
      status: category === "physical" ? "reported" : "not_reported",
      summary: category === "physical" ? "Reports occasional headaches." : "",
      evidence: category === "physical" ? [{ sourceId: "chat-1", observedAt: null }] : [],
    })),
  };
  const result = await runClinicalContextAgent({
    requestId: "trace-context-1",
    deidentified: true,
    subjectToken: "synthetic-token-123",
    sources: [{ sourceId: "chat-1", sourceType: "text_chat", content: "Synthetic: occasional headaches." }],
  }, { env, audit, fetchImpl: mockFetch(output) });
  assert.equal(result.factors.length, 7);
  assert.equal(result.factors[0].evidence[0].sourceId, "chat-1");
  assert.ok(auditEvents.some((event) => event.eventType === "output_accepted"));
});

test("evidence draft requires hedging, three distinct pathways, and disclaimer", async () => {
  const output = {
    schemaVersion: "evidence-documentation-v1",
    draftOnly: true,
    disclaimer: "These findings do not constitute a definitive medical diagnosis and require clinician review.",
    sections: [{ heading: "Summary", content: "Results are consistent with the supplied finding.", evidenceRefs: ["f-1"] }],
    carePathways: [
      { domain: "nutrition", option: "Discuss balanced meals.", rationale: "This may be worth discussing based on the finding.", evidenceRefs: ["f-1"] },
      { domain: "auditory_health", option: "Discuss hearing concerns.", rationale: "This could be relevant based on the finding.", evidenceRefs: ["f-1"] },
      { domain: "sleep_optimization", option: "Discuss sleep routines.", rationale: "This may be relevant based on the finding.", evidenceRefs: ["f-1"] },
    ],
    uncertainties: ["The supplied finding is limited."],
  };
  const result = await runEvidenceDocumentationAgent({
    requestId: "trace-evidence-1",
    deidentified: true,
    findings: [{ findingId: "f-1", summary: "Synthetic reviewed analytical finding." }],
  }, { env, audit, fetchImpl: mockFetch(output) });
  assert.equal(result.draftOnly, true);
  assert.equal(new Set(result.carePathways.map((item) => item.domain)).size, 3);
});

test("evidence draft rejects unsupported references", async () => {
  const output = {
    schemaVersion: "evidence-documentation-v1",
    draftOnly: true,
    disclaimer: "These findings do not constitute a definitive medical diagnosis and require clinician review.",
    sections: [{ heading: "Summary", content: "Results are consistent with the supplied finding.", evidenceRefs: ["unknown"] }],
    carePathways: [
      { domain: "nutrition", option: "Discuss meals.", rationale: "This may be worth discussing.", evidenceRefs: ["f-1"] },
      { domain: "auditory_health", option: "Discuss hearing.", rationale: "This could be relevant.", evidenceRefs: ["f-1"] },
      { domain: "sleep_optimization", option: "Discuss sleep.", rationale: "This may be relevant.", evidenceRefs: ["f-1"] },
    ],
    uncertainties: [],
  };
  await assert.rejects(runEvidenceDocumentationAgent({
    deidentified: true,
    findings: [{ findingId: "f-1", summary: "Synthetic finding." }],
  }, { env, audit, fetchImpl: mockFetch(output) }), /hedging language or valid evidence references/);
});

test("equity audit suppresses small cells and flags elevated false-referral gaps", async () => {
  const rows = [];
  for (let i = 0; i < 30; i += 1) {
    rows.push({
      language: i < 15 ? "en" : "sw",
      ageBand: "65-74",
      educationBand: i < 15 ? "secondary" : "tertiary",
      referenceLabel: "negative",
      predictedReferral: i < 15 ? i < 1 : i < 25,
      completed: true,
    });
  }
  rows.push({ language: "other", ageBand: "75-84", educationBand: "primary", referenceLabel: "negative", predictedReferral: false, completed: false });
  const result = await runQualityEquityAudit({
    requestId: "trace-audit-1",
    versions: {
      modelVersion: "model-v1",
      promptVersion: "prompt-v1",
      datasetVersion: "synthetic-v1",
      evaluationWindow: "2026-Q1",
    },
    rows,
  }, { audit, minimumCellSize: 10, gapThreshold: 0.1 });
  assert.equal(result.slices.language.falseReferralRateGap, 0.6);
  assert.equal(result.slices.language.flags.length, 1);
  assert.equal(result.slices.language.groups.find((group) => group.value === "other").count, null);
  assert.equal(result.requiresHumanReview, true);
  assert.ok(auditEvents.some((event) => event.eventType === "aggregate_output_emitted"));
});
