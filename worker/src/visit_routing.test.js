import test from "node:test";
import assert from "node:assert/strict";
import { classifyVisitMessage } from "./visit_routing.js";

test("sudden confusion routes to urgent handoff", () => {
  const result = classifyVisitMessage("My mother suddenly became confused today.");
  assert.equal(result.urgentHandoff, true);
  assert.equal(result.route, "urgent_handoff");
  assert.ok(result.flags.includes("sudden_confusion"));
});

test("hearing and daily function concerns route to clinician review", () => {
  const hearing = classifyVisitMessage("I have trouble hearing.");
  const daily = classifyVisitMessage("I am struggling with everyday tasks and need more help.");
  assert.equal(hearing.route, "clinician_review");
  assert.ok(hearing.flags.includes("hearing_concern"));
  assert.equal(daily.route, "clinician_review");
  assert.ok(daily.flags.includes("daily_function_difficulty"));
});

test("unrelated text does not create routing flags", () => {
  const result = classifyVisitMessage("I slept well last night.");
  assert.deepEqual(result.flags, []);
  assert.equal(result.route, "none");
});

test("Arabic sudden confusion is routed urgently", () => {
  const result = classifyVisitMessage("حدث ارتباك مفاجئ اليوم");
  assert.equal(result.urgentHandoff, true);
  assert.equal(result.route, "urgent_handoff");
});

test("Arabic hearing and daily function concerns request review", () => {
  const hearing = classifyVisitMessage("أعاني من ضعف السمع");
  const daily = classifyVisitMessage("أحتاج مساعدة أكثر في الأعمال اليومية");
  assert.equal(hearing.route, "clinician_review");
  assert.equal(daily.route, "clinician_review");
});
