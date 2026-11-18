"""Thread-safe, deterministic async orchestration for a 12-stage review.

This module routes bounded agent tasks; it is not a clinical decision system.
Agent implementations and clinician identity/authorization are injected by the
hosting service. Inputs must be de-identified and consented before this engine
is invoked. The coordinator does not calculate clinical scores or diagnoses.
"""

from __future__ import annotations

import asyncio
import copy
import hashlib
import json
import threading
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Mapping, Protocol

JsonObject = dict[str, Any]


class Stage(str, Enum):
    CONSENT_ACCESS = "01_consent_access"
    SAFETY_TRIAGE = "02_safety_triage"
    CLINICAL_CONTEXT = "03_clinical_context"
    DATA_QUALITY_ACCESSIBILITY = "04_data_quality_accessibility"
    ASSESSMENT_PROTOCOL = "05_assessment_protocol"
    COGNITIVE_CHANGE_SCORING = "06_cognitive_change_scoring"
    CARE_PATHWAY = "07_care_pathway"
    SPECIALIST_MODEL_LIAISON = "08_specialist_model_liaison"
    EVIDENCE_DOCUMENTATION = "09_evidence_documentation"
    CLINICIAN_REVIEW = "10_clinician_review"
    FOLLOW_UP_COORDINATION = "11_follow_up_coordination"
    QUALITY_EQUITY_AUDIT = "12_quality_equity_audit"


STAGE_ORDER: tuple[Stage, ...] = tuple(Stage)
CLINICAL_STAGES_AFTER_GATES = frozenset(STAGE_ORDER[4:9])


class WorkflowState(str, Enum):
    NEW = "new"
    RUNNING = "running"
    WAITING_FOR_CLINICIAN = "waiting_for_clinician"
    COMPLETED = "completed"
    HELD = "held"
    HUMAN_HANDOFF_REQUIRED = "human_handoff_required"
    AUDIT_FAILED = "audit_failed"


class StageStatus(str, Enum):
    STARTED = "started"
    WAITING = "waiting"
    COMPLETED = "completed"
    HELD = "held"
    SKIPPED = "skipped"
    FAILED = "failed"


@dataclass(frozen=True, slots=True)
class StageRecord:
    """Immutable workflow event with the required explicit stage metadata."""

    sequence: int
    stage: Stage
    status: StageStatus
    input: Mapping[str, Any]
    output: Mapping[str, Any]
    version: str
    reason: str
    occurred_at: str


@dataclass(frozen=True, slots=True)
class AgentResult:
    """Structured result from one bounded agent; the coordinator never interprets scores."""

    output: Mapping[str, Any]
    version: str
    reason: str = "Agent task completed."


@dataclass(frozen=True, slots=True)
class ClinicianDecision:
    """Decision asserted by the authenticated host after a human review."""

    approved: bool
    reviewer_id: str
    reason: str
    decision_id: str


@dataclass(frozen=True, slots=True)
class WorkflowRunResult:
    case_id: str
    state: WorkflowState
    next_stage: Stage | None
    message: str


class WorkflowAgent(Protocol):
    version: str

    async def execute(self, context: Mapping[str, Any]) -> AgentResult:
        """Perform only the bounded task for the mapped stage."""


class AuditWriter(Protocol):
    async def write(self, event: Mapping[str, Any]) -> None:
        """Persist an event to a protected audit sink."""


@dataclass
class CaseContext:
    """Thread-safe, in-memory case state shared with sequential agents.

    The engine stores stage inputs and outputs for orchestration. Production
    callers must supply de-identified/minimized data and protect this object
    from unauthorized access; thread safety is not access control or encryption.
    """

    case_id: str
    initial_input: Mapping[str, Any]
    _lock: threading.RLock = field(default_factory=threading.RLock, init=False, repr=False)
    _state: WorkflowState = field(default=WorkflowState.NEW, init=False, repr=False)
    _outputs: dict[Stage, JsonObject] = field(default_factory=dict, init=False, repr=False)
    _records: list[StageRecord] = field(default_factory=list, init=False, repr=False)
    _events: list[JsonObject] = field(default_factory=list, init=False, repr=False)
    _approval: JsonObject | None = field(default=None, init=False, repr=False)
    _audit_errors: list[str] = field(default_factory=list, init=False, repr=False)

    def __post_init__(self) -> None:
        if not self.case_id or len(self.case_id) > 128:
            raise ValueError("case_id must be a non-empty pseudonymous identifier.")
        if not isinstance(self.initial_input, Mapping):
            raise TypeError("initial_input must be a mapping.")
        self.initial_input = copy.deepcopy(dict(self.initial_input))

    @property
    def state(self) -> WorkflowState:
        with self._lock:
            return self._state

    @property
    def records(self) -> tuple[StageRecord, ...]:
        with self._lock:
            return tuple(copy.deepcopy(self._records))

    @property
    def events(self) -> tuple[JsonObject, ...]:
        with self._lock:
            return tuple(copy.deepcopy(self._events))

    @property
    def audit_errors(self) -> tuple[str, ...]:
        with self._lock:
            return tuple(self._audit_errors)

    def agent_input(self) -> JsonObject:
        """Return a defensive snapshot for the next sequential agent."""
        with self._lock:
            return {
                "case_id": self.case_id,
                "initial_input": copy.deepcopy(dict(self.initial_input)),
                "stage_outputs": {
                    stage.value: copy.deepcopy(output)
                    for stage, output in self._outputs.items()
                },
                "workflow_state": self._state.value,
            }

    def output_for(self, stage: Stage) -> JsonObject | None:
        with self._lock:
            output = self._outputs.get(stage)
            return copy.deepcopy(output) if output is not None else None

    def final_output(self) -> JsonObject:
        """Release final agent outputs only after approval and all stages pass."""
        with self._lock:
            if self._state is not WorkflowState.COMPLETED or not (
                self._approval and self._approval.get("approved") is True
            ):
                raise PermissionError("Final outputs are unavailable before clinician approval and workflow completion.")
            return {
                stage.value: copy.deepcopy(self._outputs[stage])
                for stage in (
                    Stage.EVIDENCE_DOCUMENTATION,
                    Stage.FOLLOW_UP_COORDINATION,
                    Stage.QUALITY_EQUITY_AUDIT,
                )
                if stage in self._outputs
            }

    def snapshot(self) -> JsonObject:
        """Return a defensive internal snapshot; callers still enforce authorization."""
        with self._lock:
            return {
                "case_id": self.case_id,
                "state": self._state.value,
                "initial_input": copy.deepcopy(dict(self.initial_input)),
                "stage_outputs": {
                    stage.value: copy.deepcopy(output)
                    for stage, output in self._outputs.items()
                },
                "records": copy.deepcopy(self._records),
                "approval": copy.deepcopy(self._approval),
                "audit_errors": list(self._audit_errors),
            }

    def _set_state(self, state: WorkflowState) -> None:
        with self._lock:
            self._state = state

    def _set_output(self, stage: Stage, output: Mapping[str, Any]) -> None:
        with self._lock:
            self._outputs[stage] = copy.deepcopy(dict(output))

    def _set_approval(self, approval: JsonObject) -> None:
        with self._lock:
            self._approval = copy.deepcopy(approval)

    def _add_audit_error(self, message: str) -> None:
        with self._lock:
            self._audit_errors.append(message)

    def _record(
        self,
        stage: Stage,
        status: StageStatus,
        *,
        input_data: Mapping[str, Any],
        output_data: Mapping[str, Any] | None = None,
        version: str,
        reason: str,
    ) -> StageRecord:
        with self._lock:
            record = StageRecord(
                sequence=len(self._records) + 1,
                stage=stage,
                status=status,
                input=copy.deepcopy(dict(input_data)),
                output=copy.deepcopy(dict(output_data or {})),
                version=version,
                reason=reason,
                occurred_at=datetime.now(timezone.utc).isoformat(),
            )
            self._records.append(record)
            self._events.append(_audit_event(self.case_id, record))
            return copy.deepcopy(record)

    def _record_event(self, event: Mapping[str, Any]) -> JsonObject:
        with self._lock:
            record = copy.deepcopy(dict(event))
            self._events.append(record)
            return copy.deepcopy(record)


class WorkflowEngine:
    """Strict-order async state machine with a hard clinician approval pause."""

    def __init__(
        self,
        context: CaseContext,
        agents: Mapping[Stage, WorkflowAgent],
        audit_writer: AuditWriter,
    ) -> None:
        required_agents = set(STAGE_ORDER) - {Stage.CLINICIAN_REVIEW}
        missing = required_agents - set(agents)
        if missing:
            labels = ", ".join(sorted(stage.value for stage in missing))
            raise ValueError(f"Missing required workflow agents: {labels}")
        if any(not callable(getattr(agent, "execute", None)) for agent in agents.values()):
            raise TypeError("Each workflow agent must define async execute(context).")
        if not callable(getattr(audit_writer, "write", None)):
            raise TypeError("audit_writer must define async write(event).")

        self.context = context
        self._agents = dict(agents)
        self._audit_writer = audit_writer
        self._next_index = 0
        self._blocked_reason: str | None = None
        self._handoff_required = False
        self._decision_submitted = False
        self._run_lock = asyncio.Lock()
        self._audit_queue: asyncio.Queue[JsonObject | None] = asyncio.Queue()
        self._audit_task: asyncio.Task[None] | None = None
        self._audit_closed = False

    async def run(self) -> WorkflowRunResult:
        """Run from the beginning until a hard pause or terminal state."""
        async with self._run_lock:
            if self.context.state is not WorkflowState.NEW:
                if self.context.state is WorkflowState.WAITING_FOR_CLINICIAN:
                    return self._result("Awaiting an external clinician decision.")
                if self._is_terminal(self.context.state):
                    return self._result("Workflow is already terminal.")
                raise RuntimeError("Workflow is already running or cannot be restarted.")
            self._start_audit_worker()
            self.context._set_state(WorkflowState.RUNNING)
            return await self._drive()

    async def resume(self) -> WorkflowRunResult:
        """Resume only after an explicit clinician decision has been recorded."""
        async with self._run_lock:
            if self.context.state is not WorkflowState.WAITING_FOR_CLINICIAN:
                raise RuntimeError("Workflow is not paused at clinician review.")
            if not self._decision_submitted:
                raise PermissionError("A clinician decision is required before resuming.")
            self._start_audit_worker()
            if self.context.state is WorkflowState.WAITING_FOR_CLINICIAN:
                decision = self.context.snapshot()["approval"]
                # The review record was created at the hard pause; advance past
                # that gate exactly once after the external decision arrives.
                if STAGE_ORDER[self._next_index] is not Stage.CLINICIAN_REVIEW:
                    raise RuntimeError("Workflow cursor is not at clinician review.")
                self._next_index += 1
                if decision["approved"] is True:
                    self.context._set_state(WorkflowState.RUNNING)
                else:
                    self._blocked_reason = "Clinician review did not approve the draft."
                    self.context._set_state(WorkflowState.HELD)
            return await self._drive()

    def submit_clinician_decision(self, decision: ClinicianDecision) -> None:
        """Record an externally authenticated decision; identity validation is host-owned."""
        if self.context.state is not WorkflowState.WAITING_FOR_CLINICIAN:
            raise RuntimeError("No clinician review decision is currently expected.")
        if self._decision_submitted:
            raise RuntimeError("A clinician decision has already been submitted.")
        if not isinstance(decision, ClinicianDecision):
            raise TypeError("decision must be a ClinicianDecision.")
        if not decision.reviewer_id.strip() or decision.reviewer_id.strip().lower() in {"agent", "system", "ai"}:
            raise ValueError("reviewer_id must identify an external human reviewer.")
        if not decision.decision_id.strip() or not decision.reason.strip():
            raise ValueError("A decision_id and review reason are required.")
        self._decision_submitted = True
        normalized = {
            "approved": decision.approved,
            "reviewer_id": decision.reviewer_id,
            "decision_id": decision.decision_id,
            "reason": decision.reason,
        }
        self.context._set_approval(normalized)
        self.context._record(
            Stage.CLINICIAN_REVIEW,
            StageStatus.COMPLETED if decision.approved else StageStatus.HELD,
            input_data={"reviewed_stage": Stage.EVIDENCE_DOCUMENTATION.value},
            output_data={"approved": decision.approved, "decision_id": decision.decision_id},
            version="human-review-v1",
            reason="External clinician approved the draft." if decision.approved else "External clinician withheld approval.",
        )
        self._enqueue_latest_event()

    async def _drive(self) -> WorkflowRunResult:
        try:
            while self._next_index < len(STAGE_ORDER):
                stage = STAGE_ORDER[self._next_index]

                if stage is Stage.CLINICIAN_REVIEW:
                    if self._blocked_reason:
                        self._record_stage(
                            stage,
                            StageStatus.SKIPPED,
                            input_data={"blocked_by": self._blocked_reason},
                            output_data={},
                            version="human-review-v1",
                            reason="Clinician approval cannot authorize a case blocked by an upstream safety or validation gate.",
                        )
                        self._next_index += 1
                        continue
                    self._record_stage(
                        stage,
                        StageStatus.WAITING,
                        input_data={"draft_available": Stage.EVIDENCE_DOCUMENTATION in self.context._outputs},
                        output_data={"awaiting": "external_clinician"},
                        version="human-review-v1",
                        reason="Hard pause: clinician approval is required before follow-up or final outputs.",
                    )
                    self.context._set_state(WorkflowState.WAITING_FOR_CLINICIAN)
                    return self._result("Workflow paused for clinician approval; no final outputs are released.")

                if self._blocked_reason and stage is not Stage.QUALITY_EQUITY_AUDIT:
                    self._record_stage(
                        stage,
                        StageStatus.SKIPPED,
                        input_data={"blocked_by": self._blocked_reason},
                        output_data={},
                        version="coordinator-v1",
                        reason="Skipped by the deterministic safety/data gate; no clinical delegation occurred.",
                    )
                    self._next_index += 1
                    continue

                if stage is Stage.QUALITY_EQUITY_AUDIT:
                    await self._run_quality_audit()
                    self._next_index += 1
                    break

                await self._run_agent_stage(stage)
                self._next_index += 1

                if self.context.state in {WorkflowState.HELD, WorkflowState.HUMAN_HANDOFF_REQUIRED}:
                    self._blocked_reason = self._blocked_reason or "An upstream gate did not pass."

            if self.context.state is WorkflowState.RUNNING:
                self.context._set_state(WorkflowState.COMPLETED)
            await self._finalize_audit()
            if self.context.audit_errors:
                self.context._set_state(WorkflowState.AUDIT_FAILED)
            return self._result(self._terminal_message())
        except asyncio.CancelledError:
            self.context._set_state(WorkflowState.HELD)
            self.context._record_event({
                "case_id": self.context.case_id,
                "event": "workflow_cancelled",
                "reason": "Execution was cancelled; final outputs remain unavailable.",
                "occurred_at": _now(),
            })
            await self._finalize_audit()
            raise
        except Exception as error:
            self.context._set_state(WorkflowState.HELD)
            self.context._record_event({
                "case_id": self.context.case_id,
                "event": "workflow_engine_failure",
                "error_type": type(error).__name__,
                "reason": "Unhandled orchestration failure; final outputs remain unavailable.",
                "occurred_at": _now(),
            })
            await self._ensure_quality_audit_after_failure()
            await self._finalize_audit()
            return self._result("Workflow held because the orchestration engine failed safely.")

    async def _run_agent_stage(self, stage: Stage) -> None:
        agent = self._agents[stage]
        stage_input = self.context.agent_input()
        version = str(getattr(agent, "version", "unversioned"))
        self._record_stage(
            stage,
            StageStatus.STARTED,
            input_data=stage_input,
            output_data={},
            version=version,
            reason="Delegating bounded task in required workflow order.",
        )
        try:
            result = await agent.execute(stage_input)
            if not isinstance(result, AgentResult) or not isinstance(result.output, Mapping):
                raise TypeError("Agent must return AgentResult with a mapping output.")
        except Exception as error:
            handoff = stage is Stage.SAFETY_TRIAGE
            self._blocked_reason = f"{stage.value} failed closed ({type(error).__name__})."
            self._handoff_required = self._handoff_required or handoff
            self.context._set_state(
                WorkflowState.HUMAN_HANDOFF_REQUIRED if self._handoff_required else WorkflowState.HELD
            )
            self._record_stage(
                stage,
                StageStatus.FAILED,
                input_data=stage_input,
                output_data={"error_type": type(error).__name__},
                version=version,
                reason="Agent failure closed the workflow; no downstream clinical stages may run.",
            )
            return

        self.context._set_output(stage, result.output)
        self._record_stage(
            stage,
            StageStatus.COMPLETED,
            input_data=stage_input,
            output_data=result.output,
            version=result.version,
            reason=result.reason,
        )

        if stage is Stage.CONSENT_ACCESS and result.output.get("authorized") is not True:
            self._block(WorkflowState.HELD, "Consent/access gate did not explicitly authorize this workflow.")
        elif stage is Stage.SAFETY_TRIAGE and (
            result.output.get("high_risk") is True or result.output.get("immediate_handoff") is True
        ):
            self._block(WorkflowState.HUMAN_HANDOFF_REQUIRED, "Safety agent raised an immediate human handoff flag.")
            self._handoff_required = True
        elif stage is Stage.DATA_QUALITY_ACCESSIBILITY and result.output.get("valid") is not True:
            self._block(WorkflowState.HELD, "Data quality/accessibility gate did not explicitly pass validation.")

    async def _run_quality_audit(self) -> None:
        stage = Stage.QUALITY_EQUITY_AUDIT
        agent = self._agents[stage]
        stage_input = self.context.agent_input()
        version = str(getattr(agent, "version", "unversioned"))
        self._record_stage(
            stage,
            StageStatus.STARTED,
            input_data=stage_input,
            output_data={},
            version=version,
            reason="Run the final quality/equity review over available workflow metadata, including held/skipped stages.",
        )
        try:
            result = await agent.execute(stage_input)
            if not isinstance(result, AgentResult) or not isinstance(result.output, Mapping):
                raise TypeError("Audit agent must return AgentResult with a mapping output.")
            self.context._set_output(stage, result.output)
            self._record_stage(
                stage,
                StageStatus.COMPLETED,
                input_data=stage_input,
                output_data=result.output,
                version=result.version,
                reason=result.reason,
            )
        except Exception as error:
            self.context._set_state(WorkflowState.AUDIT_FAILED)
            self.context._record_stage(
                stage,
                StageStatus.FAILED,
                input_data=stage_input,
                output_data={"error_type": type(error).__name__},
                version=version,
                reason="Quality/equity audit failed; completion and final-output release are blocked.",
            )

    async def _ensure_quality_audit_after_failure(self) -> None:
        if Stage.QUALITY_EQUITY_AUDIT in self._agents and not any(
            record.stage is Stage.QUALITY_EQUITY_AUDIT for record in self.context.records
        ):
            await self._run_quality_audit()
            self._next_index = len(STAGE_ORDER)

    def _block(self, state: WorkflowState, reason: str) -> None:
        self._blocked_reason = reason
        self.context._set_state(state)

    def _record_stage(
        self,
        stage: Stage,
        status: StageStatus,
        *,
        input_data: Mapping[str, Any],
        output_data: Mapping[str, Any],
        version: str,
        reason: str,
    ) -> None:
        self.context._record(
            stage,
            status,
            input_data=input_data,
            output_data=output_data,
            version=version,
            reason=reason,
        )
        self._enqueue_latest_event()

    def _enqueue_latest_event(self) -> None:
        event = self.context.events[-1]
        self._audit_queue.put_nowait(event)

    def _start_audit_worker(self) -> None:
        if self._audit_task is None:
            self._audit_closed = False
            self._audit_task = asyncio.create_task(self._audit_loop(), name=f"audit:{self.context.case_id}")

    async def _audit_loop(self) -> None:
        while True:
            event = await self._audit_queue.get()
            try:
                if event is None:
                    return
                await self._audit_writer.write(event)
            except Exception as error:
                self.context._add_audit_error(type(error).__name__)
            finally:
                self._audit_queue.task_done()

    async def _finalize_audit(self) -> None:
        if self._audit_task is None or self._audit_closed:
            return
        self.context._record_event({
            "case_id": self.context.case_id,
            "event": "workflow_finalized",
            "state": self.context.state.value,
            "final_stage": Stage.QUALITY_EQUITY_AUDIT.value,
            "occurred_at": _now(),
        })
        self._audit_queue.put_nowait(self.context.events[-1])
        await self._audit_queue.join()
        self._audit_queue.put_nowait(None)
        await self._audit_task
        self._audit_task = None
        self._audit_closed = True

    def _result(self, message: str) -> WorkflowRunResult:
        state = self.context.state
        next_stage = STAGE_ORDER[self._next_index] if self._next_index < len(STAGE_ORDER) else None
        return WorkflowRunResult(self.context.case_id, state, next_stage, message)

    def _terminal_message(self) -> str:
        return {
            WorkflowState.COMPLETED: "All required stages completed after clinician approval.",
            WorkflowState.HELD: "Workflow held; final outputs are unavailable.",
            WorkflowState.HUMAN_HANDOFF_REQUIRED: "Immediate human handoff required; downstream clinical stages were skipped.",
            WorkflowState.AUDIT_FAILED: "Audit failure blocked workflow completion and final-output release.",
        }.get(self.context.state, "Workflow stopped safely.")

    @staticmethod
    def _is_terminal(state: WorkflowState) -> bool:
        return state in {
            WorkflowState.COMPLETED,
            WorkflowState.HELD,
            WorkflowState.HUMAN_HANDOFF_REQUIRED,
            WorkflowState.AUDIT_FAILED,
        }


def _audit_event(case_id: str, record: StageRecord) -> JsonObject:
    """Emit provenance and content hashes, not raw clinical text or hidden reasoning."""
    return {
        "case_id": case_id,
        "event": "stage_record",
        "sequence": record.sequence,
        "stage": record.stage.value,
        "status": record.status.value,
        "version": record.version,
        "reason": record.reason,
        "input_digest": _digest(record.input),
        "output_digest": _digest(record.output),
        "occurred_at": record.occurred_at,
    }


def _digest(value: Mapping[str, Any]) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), default=repr).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
