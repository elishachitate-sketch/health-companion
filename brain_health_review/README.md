# Brain Health Review workflow engine

A dependency-free Python 3.12 async state machine for the 12-stage review workflow. It is a standalone backend component; the existing mobile app and Worker are Dart/JavaScript and cannot import this Python module directly. Integrate it as a separately deployed service behind an authenticated server-to-server boundary if Python is selected.

## Stage order

1. Consent & Access
2. Safety Triage
3. Clinical Context
4. Data Quality & Accessibility
5. Assessment Protocol
6. Cognitive Change Scoring
7. Care Pathway
8. Specialist Model Liaison
9. Evidence & Documentation
10. Clinician Review (hard pause)
11. Follow-up Coordination
12. Quality & Equity Audit

The engine delegates sequentially and passes defensive snapshots of `CaseContext` between agents. Each immutable stage record has input/output, version, reason, status, sequence, and timestamp. The case object uses a re-entrant thread lock and returns defensive copies. Records, audit events, and outputs may contain sensitive data in memory: deploy with strict access controls and retention protections.

## Safety gates and human approval

- Consent/access must return `{"authorized": true}` exactly; otherwise the workflow holds and later clinical agents are skipped.
- Safety triage must explicitly return `high_risk: false` and `immediate_handoff: false`. Either true triggers a human handoff and skips subsequent clinical stages. A safety-agent failure also fails closed to human handoff.
- Data quality/accessibility must return `{"valid": true}` exactly; otherwise later clinical stages are skipped.
- At stage 10, `run()` returns `waiting_for_clinician`. No follow-up or final output is run/released until an external host submits a `ClinicianDecision` and calls `resume()`. The host must authenticate/authorize the reviewer; `reviewer_id` string validation alone is not authentication.
- The coordinator does not diagnose, create or interpret clinical scores, change agent outputs, or approve its own report. The cognitive-scoring module is an injected agent whose implementation must be independently validated and constrained.
- Stage 12 always runs after completion, a gate hold, handoff, or workflow failure. Audit sink/agent failure prevents successful completion and final-output release.

## Asynchronous audit

Every stage event is sent to an `AuditWriter` through an asynchronous queue while the workflow progresses. An implementation of this interface can forward the versioned event stream to the Quality & Equity Audit service for ongoing checks; the stage-12 agent also receives the final aggregate workflow snapshot to produce a final report. Audit event records include hashes of stage input/output rather than copying content into the external event stream. This is not a guarantee of tamper resistance; production requires a protected, append-only store and instrumentation of all ingress/egress paths. Hidden chain-of-thought is not collected. Log observable versions, outcomes, and concise reproducible reasons only.

The `AuditWriter` is required. Any write failure is recorded and changes the eventual run to `audit_failed`, blocking final output. On a human approval pause, the event writer remains active until `resume()` reaches a terminal state.

## Agent contract

Each stage except clinician review is injected as an object with a `version` string and `async execute(context) -> AgentResult`. `context` is a read-only-by-convention defensive snapshot containing pseudonymous case ID, initial request, prior outputs, and workflow state. Agents should accept only bounded tasks and return structured output plus their version and reason. They must not be allowed to mutate workflow state or choose the next stage.

The engine is orchestration scaffolding, not production-ready clinical software. Before deployment, add authorization, consent enforcement, request signing, timeouts/cancellation policy, persistence/recovery, idempotency, rate limits, privacy/security review, clinical validation, and human-factors review. Use synthetic/de-identified records until all required approvals and vendor safeguards are in place.

## Stage 06: Cognitive Change Scoring

The exact scoring implementation is in `cognitive_change_scoring.py`; `CognitiveChangeScoringAgent` implements the workflow's async agent contract. Register it for `Stage.COGNITIVE_CHANGE_SCORING` in the injected agent map. Input is supplied at `initial_input.cognitive_change_scoring`:

```json
{
	"previous_visit_scores": [10.0, 10.5, 11.0],
	"follow_up_scores": [10.0, 10.0],
	"daily_function_degradation_reported": false,
	"sudden_confusion_reported": false
}
```

The baseline is the mean of exactly three prior visits (Visits 1–3); the follow-up mean uses exactly two scores because the requested standard-error formula uses $n=2$. With fixed synthetic SD $=1.5$, test-retest reliability $r=0.85$, and expected practice gain $=0.3$:

$$
	ext{Adjusted Change}=\bar{X}_{followup}-\bar{X}_{baseline}-0.3
$$

$$
SE=1.5\sqrt{(1-0.85)\left(\frac{1}{3}+\frac{1}{2}\right)},\qquad
z=\frac{\text{Adjusted Change}}{SE}
$$

Classification is exactly `z <= -1.96` → `Qualified Review` and specialist/clinician handoff; `-1.96 < z <= -1.645` → `Consider Repeat` and an early reassessment scheduling action; otherwise → `Routine follow-up` with `numerical_flag_raised: false`. The scheduling interval is deliberately marked clinician-defined because no number of days was specified. A reported sudden-confusion signal returns `Urgent Handoff`; daily-function degradation returns `Prompt Clinician Review`. Both bypass numeric scoring and return `z_score: null`, but only sudden confusion is labeled urgent. These are prototype routing labels, not clinical triage guidance: the routing policy and thresholds require clinician review before use. Flags must be established upstream from a user/care-partner report; this module does not classify raw text or voice. The formula assumes higher scores indicate better performance and is synthetic, not an age-adjustment model or clinically validated assessment.

## Test

Run `python3 -m unittest brain_health_review.test_workflow brain_health_review.test_cognitive_change_scoring -v` from the repository root. Tests use synthetic data and fake agents; they do not establish clinical validity.
