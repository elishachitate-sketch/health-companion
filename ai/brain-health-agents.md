# Brain Health sub-agent prompts and execution contracts

These server-side agents are **prototype support components**, not medical devices or autonomous clinical decision-makers. Use synthetic or properly de-identified data only until privacy, security, clinical validation, regulatory, and governance reviews authorize a deployment. Do not send PHI to a model provider unless an approved legal and technical arrangement explicitly permits it.

## Agents and integration

Functional implementations live in `worker/src/brain_health_agents.js`. Exported prompt strings and version IDs are centralized there. Call the agents only from authenticated, authorized server-side orchestration; do not expose model credentials or audit writes to the mobile app. The module provides:

- `runClinicalContextAgent(input, options)` — normalizes supplied longitudinal context into seven baseline factor categories. It extracts, but does not calculate clinical risk or diagnose.
- `runEvidenceDocumentationAgent(input, options)` — generates a hedged, evidence-linked draft with at least three distinct pathways. Output remains draft-only and must pass validation before a human can review it.
- `runQualityEquityAudit(input, options)` — computes deterministic descriptive subgroup measures on appropriately governed evaluation data. It does not use an LLM to calculate metrics or infer demographic attributes.

Both LLM execution functions require `options.audit(event)`, a protected append-only audit writer. The callback should store only governed event metadata and must itself be access-controlled, tamper-evident, retained according to an approved policy, and monitored for failure. The implementation intentionally does **not** capture hidden chain-of-thought or persist raw clinical text in audit events. Log prompt/model/schema versions, trace IDs, safe input/output summaries, validation outcomes, and concise reproducible rationale summaries instead. Do not claim that every possible ingress or egress is intercepted until all service routes, queues, logs, caches, telemetry, and provider paths are instrumented and verified.

## Clinical Context Agent

### Input contract

```json
{
  "requestId": "opaque-trace-id",
  "deidentified": true,
  "subjectToken": "pseudonymous-token",
  "sources": [
    {
      "sourceId": "source-001",
      "sourceType": "text_chat|voice_transcript|ehr|lifestyle|wearable|family_history|genomic",
      "observedAt": "2026-01-15 or null",
      "content": "de-identified synthetic source text"
    }
  ]
}
```

Provide a stable pseudonymous token, never direct identifiers. The implementation validates input shape and size, then the prompt returns exactly one item for each of physical, metabolic, sleep, mental wellbeing, lifestyle, family history, and genomic context. Each observation cites source IDs; absence and conflict are explicit. Source text is untrusted content, not instructions. Provenance and uncertainty are preserved; dates/units are not invented. Genomic summaries are not interpreted.

### Output contract

`clinical-context-v1` contains `subjectToken` and seven `factors`. Each factor has `category`, `status`, `summary`, and `evidence` with `sourceId` and `observedAt`. `status` is `reported`, `documented`, `device_derived`, `not_reported`, or `conflicting`. Output is rejected if the schema, source references, or categories are invalid.

## Evidence & Documentation Agent

### Input contract

```json
{
  "requestId": "opaque-trace-id",
  "deidentified": true,
  "findings": [
    {"findingId": "finding-001", "summary": "Synthetic reviewed finding", "sourceType": "analysis"}
  ]
}
```

Supply only analytical results that have already been reviewed for validity and are necessary for the draft. Every claim must cite a finding ID. Do not include unsupported diagnostic labels or sensitive identifiers.

### Output contract

`evidence-documentation-v1` contains `draftOnly: true`, a mandatory non-diagnosis/clinician-review disclaimer, readable `sections`, `carePathways`, and `uncertainties`. Each section and pathway rationale must include explicit hedging. At least three distinct care pathway domains are required (for example nutrition, auditory health, and sleep optimization); pathways are options for discussion, not treatment or claims of prevention. Unsupported references, missing hedging, or an absent disclaimer reject the response.

## Quality & Equity Audit Agent

This audit is deterministic and does not request, store, or reproduce LLM hidden reasoning. The requirement to “intercept every” internal reasoning step is intentionally not implemented: hidden chain-of-thought is not an appropriate audit artifact. Instead, capture input/output event metadata, model/prompt/ruleset/schema versions, data-set version, evaluation window, validation decisions, and concise reproducible rationale summaries. Instrument and verify every service ingress/egress path separately before making coverage claims.

### Input contract

```json
{
  "requestId": "opaque-trace-id",
  "versions": {
    "modelVersion": "provider-model-id",
    "promptVersion": "prompt-id",
    "datasetVersion": "governed-eval-set-id",
    "evaluationWindow": "2026-Q1"
  },
  "rows": [
    {
      "language": "en",
      "ageBand": "65-74",
      "educationBand": "secondary",
      "referenceLabel": "positive|negative",
      "predictedReferral": false,
      "completed": true
    }
  ]
}
```

Only use lawfully and ethically collected, consented/authorized, validated evaluation data with an independent reference label and documented cohort definition. Do not infer language, age, or education. Categories must be coarsened and reviewed to avoid re-identification.

### Metrics and safeguards

The report contains descriptive completion rate, referral rate, false-referral rate (predicted referral among reference-negative records), sensitivity (predicted referral among reference-positive records), and cross-group false-referral-rate gap for Language, Age, and Education slices. Small groups and small metric denominators are suppressed (default minimum 20). A gap above the configured threshold is a **review signal**, not proof of bias or unfairness. Interpret metrics with confidence intervals, missingness, calibration, clinical consequences, data quality, intersectional analysis, and independent domain review before decisions. No demographic slice may automatically change individual care. Do not infer demographic traits, create sensitive profiles, or use these aggregate flags to deny services.

Audit events intentionally omit raw records and chain-of-thought. A production audit store should be append-only/tamper-evident and enforce least privilege, retention/deletion policy, monitoring, and access review. If the required audit callback is unavailable, the LLM agents fail closed.

## Execution example (server only)

```js
import {
  runClinicalContextAgent,
  runEvidenceDocumentationAgent,
  runQualityEquityAudit,
} from "./brain_health_agents.js";

// `audit` must be a protected append-only writer. `env.GROQ_API_KEY` is a server secret.
const context = await runClinicalContextAgent(deidentifiedInput, { env, audit });
const draft = await runEvidenceDocumentationAgent(reviewedFindings, { env, audit });
const equityReport = await runQualityEquityAudit(evaluationDataset, { audit });
// Route `draft` and any report only to an authorized human review surface.
```

Do not wire these calls to an unauthenticated public endpoint. The current Worker chat endpoint has no authentication and permissive CORS; it is not an appropriate route for real clinical records. Add authenticated authorization, purpose-scoped consent enforcement, rate limiting, data minimization, secrets management, and reviewed logging before integration.
