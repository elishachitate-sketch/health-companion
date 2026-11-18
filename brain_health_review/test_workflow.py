"""Tests for Brain Health Review's deterministic async coordinator."""

from __future__ import annotations

import asyncio
import unittest
from typing import Any, Mapping

from brain_health_review.workflow import (
    AgentResult,
    CaseContext,
    ClinicianDecision,
    STAGE_ORDER,
    Stage,
    StageStatus,
    WorkflowEngine,
    WorkflowState,
)


class FakeAgent:
    def __init__(self, stage: Stage, output: Mapping[str, Any] | None = None) -> None:
        self.stage = stage
        self.version = f"{stage.value}-test-v1"
        self.output = dict(output or {})
        self.calls = 0

    async def execute(self, context: Mapping[str, Any]) -> AgentResult:
        self.calls += 1
        await asyncio.sleep(0)
        if self.stage is Stage.CONSENT_ACCESS and not self.output:
            return AgentResult({"authorized": True}, self.version, "Synthetic consent authorized.")
        if self.stage is Stage.SAFETY_TRIAGE and not self.output:
            return AgentResult({"high_risk": False, "immediate_handoff": False}, self.version, "No synthetic immediate handoff flag.")
        if self.stage is Stage.DATA_QUALITY_ACCESSIBILITY and not self.output:
            return AgentResult({"valid": True}, self.version, "Synthetic data checks passed.")
        return AgentResult(self.output or {"status": "synthetic_ok"}, self.version, "Synthetic agent output.")


class MemoryAuditWriter:
    def __init__(self, fail: bool = False) -> None:
        self.events: list[Mapping[str, Any]] = []
        self.fail = fail

    async def write(self, event: Mapping[str, Any]) -> None:
        await asyncio.sleep(0)
        if self.fail:
            raise OSError("synthetic audit unavailable")
        self.events.append(dict(event))


def make_agents(overrides: Mapping[Stage, Mapping[str, Any]] | None = None) -> dict[Stage, FakeAgent]:
    overrides = overrides or {}
    return {
        stage: FakeAgent(stage, overrides.get(stage))
        for stage in STAGE_ORDER
        if stage is not Stage.CLINICIAN_REVIEW
    }


class WorkflowTests(unittest.IsolatedAsyncioTestCase):
    async def test_happy_path_hard_pauses_until_external_approval(self) -> None:
        agents = make_agents({
            Stage.EVIDENCE_DOCUMENTATION: {"draft": "synthetic draft"},
            Stage.FOLLOW_UP_COORDINATION: {"follow_up": "clinician-directed"},
            Stage.QUALITY_EQUITY_AUDIT: {"audit": "synthetic summary"},
        })
        context = CaseContext("case-token-001", {"deidentified": True, "synthetic": True})
        audit = MemoryAuditWriter()
        engine = WorkflowEngine(context, agents, audit)

        paused = await engine.run()
        self.assertEqual(paused.state, WorkflowState.WAITING_FOR_CLINICIAN)
        self.assertEqual(paused.next_stage, Stage.CLINICIAN_REVIEW)
        self.assertEqual(agents[Stage.FOLLOW_UP_COORDINATION].calls, 0)
        with self.assertRaises(PermissionError):
            context.final_output()
        with self.assertRaises(PermissionError):
            await engine.resume()

        engine.submit_clinician_decision(ClinicianDecision(
            approved=True,
            reviewer_id="clinician-42",
            reason="Synthetic review approved.",
            decision_id="review-001",
        ))
        complete = await engine.resume()
        self.assertEqual(complete.state, WorkflowState.COMPLETED)
        self.assertEqual(agents[Stage.FOLLOW_UP_COORDINATION].calls, 1)
        self.assertEqual(agents[Stage.QUALITY_EQUITY_AUDIT].calls, 1)
        final = context.final_output()
        self.assertIn(Stage.EVIDENCE_DOCUMENTATION.value, final)
        self.assertEqual(context.records[-1].stage, Stage.QUALITY_EQUITY_AUDIT)
        self.assertEqual(context.events[-1]["final_stage"], Stage.QUALITY_EQUITY_AUDIT.value)
        self.assertTrue(any(event["event"] == "workflow_finalized" for event in audit.events))

    async def test_high_risk_triggers_handoff_and_skips_clinical_stages(self) -> None:
        agents = make_agents({Stage.SAFETY_TRIAGE: {"high_risk": True, "immediate_handoff": True}})
        context = CaseContext("case-token-002", {"synthetic": True})
        engine = WorkflowEngine(context, agents, MemoryAuditWriter())

        result = await engine.run()
        self.assertEqual(result.state, WorkflowState.HUMAN_HANDOFF_REQUIRED)
        for stage in STAGE_ORDER[2:9]:
            self.assertEqual(agents[stage].calls, 0)
        self.assertEqual(agents[Stage.QUALITY_EQUITY_AUDIT].calls, 1)
        skipped = [record for record in context.records if record.status is StageStatus.SKIPPED]
        self.assertEqual({record.stage for record in skipped}, set(STAGE_ORDER[2:11]))
        with self.assertRaises(PermissionError):
            context.final_output()

    async def test_invalid_consent_holds_and_never_calls_safety_or_clinical_agents(self) -> None:
        agents = make_agents({Stage.CONSENT_ACCESS: {"authorized": False}})
        context = CaseContext("case-token-003", {"synthetic": True})
        result = await WorkflowEngine(context, agents, MemoryAuditWriter()).run()
        self.assertEqual(result.state, WorkflowState.HELD)
        self.assertEqual(agents[Stage.SAFETY_TRIAGE].calls, 0)
        self.assertTrue(all(agents[stage].calls == 0 for stage in STAGE_ORDER[2:9]))
        self.assertEqual(agents[Stage.QUALITY_EQUITY_AUDIT].calls, 1)

    async def test_data_validation_failure_skips_later_clinical_stages(self) -> None:
        agents = make_agents({Stage.DATA_QUALITY_ACCESSIBILITY: {"valid": False}})
        context = CaseContext("case-token-004", {"synthetic": True})
        result = await WorkflowEngine(context, agents, MemoryAuditWriter()).run()
        self.assertEqual(result.state, WorkflowState.HELD)
        self.assertEqual(agents[Stage.ASSESSMENT_PROTOCOL].calls, 0)
        self.assertEqual(agents[Stage.COGNITIVE_CHANGE_SCORING].calls, 0)
        self.assertEqual(agents[Stage.QUALITY_EQUITY_AUDIT].calls, 1)

    async def test_audit_sink_failure_blocks_final_completion(self) -> None:
        agents = make_agents()
        context = CaseContext("case-token-005", {"synthetic": True})
        engine = WorkflowEngine(context, agents, MemoryAuditWriter(fail=True))
        paused = await engine.run()
        self.assertEqual(paused.state, WorkflowState.WAITING_FOR_CLINICIAN)
        engine.submit_clinician_decision(ClinicianDecision(
            approved=True,
            reviewer_id="clinician-42",
            reason="Synthetic review approved.",
            decision_id="review-005",
        ))
        result = await engine.resume()
        self.assertEqual(result.state, WorkflowState.AUDIT_FAILED)
        with self.assertRaises(PermissionError):
            context.final_output()
        self.assertTrue(context.audit_errors)

    async def test_case_context_returns_defensive_copies(self) -> None:
        source = {"synthetic": {"value": 1}}
        context = CaseContext("case-token-006", source)
        source["synthetic"]["value"] = 2
        snapshot = context.agent_input()
        snapshot["initial_input"]["synthetic"]["value"] = 3
        self.assertEqual(context.agent_input()["initial_input"]["synthetic"]["value"], 1)

    async def test_non_human_reviewer_cannot_approve(self) -> None:
        agents = make_agents()
        engine = WorkflowEngine(
            CaseContext("case-token-007", {"synthetic": True}),
            agents,
            MemoryAuditWriter(),
        )
        await engine.run()
        with self.assertRaises(ValueError):
            engine.submit_clinician_decision(ClinicianDecision(
                approved=True,
                reviewer_id="AI",
                reason="not allowed",
                decision_id="review-ai",
            ))


if __name__ == "__main__":
    unittest.main()
