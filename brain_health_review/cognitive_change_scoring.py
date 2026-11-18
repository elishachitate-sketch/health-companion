"""Stage 06: longitudinal adjusted reliable-change scoring.

This is a deterministic implementation of the specified synthetic formula,
not a clinically validated measure. Lower follow-up scores are treated as
worse change (i.e. the scale is assumed to have higher scores = better).
Reported safety signals bypass numeric scoring entirely.
"""

from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from typing import Any

from .workflow import AgentResult

SYNTHETIC_SD = 1.5
TEST_RETEST_RELIABILITY = 0.85
EXPECTED_PRACTICE_GAIN = 0.3
BASELINE_VISIT_COUNT = 3
FOLLOW_UP_VISIT_COUNT = 2
QUALIFIED_REVIEW_THRESHOLD = -1.96
CONSIDER_REPEAT_THRESHOLD = -1.645
AGENT_VERSION = "cognitive-change-scoring-v1"


class ScoringInputError(ValueError):
    """Raised when input cannot be scored under the fixed formula contract."""


def standard_error_of_measurement() -> float:
    """Return SE = SD * sqrt((1-r) * (1/3 + 1/2)) using fixed parameters."""
    return SYNTHETIC_SD * math.sqrt(
        (1 - TEST_RETEST_RELIABILITY)
        * (1 / BASELINE_VISIT_COUNT + 1 / FOLLOW_UP_VISIT_COUNT)
    )


def reported_signal_result(
    *,
    daily_function_degradation_reported: bool = False,
    sudden_confusion_reported: bool = False,
) -> dict[str, Any] | None:
    """Route reported safety signals before numerical validation or scoring.

    The booleans must come from an upstream report/triage process. This helper
    does not perform language classification or infer symptoms from raw text.
    Sudden confusion takes the urgent route. Reported daily-function decline
    requests prompt clinician review without automatically labeling it an
    emergency. The routing policy requires clinical approval before use.
    """
    if not isinstance(daily_function_degradation_reported, bool):
        raise TypeError("daily_function_degradation_reported must be a bool.")
    if not isinstance(sudden_confusion_reported, bool):
        raise TypeError("sudden_confusion_reported must be a bool.")
    if not (daily_function_degradation_reported or sudden_confusion_reported):
        return None
    signals = []
    if daily_function_degradation_reported:
        signals.append("daily_function_degradation_reported")
    if sudden_confusion_reported:
        signals.append("sudden_confusion_reported")
    sudden_confusion = sudden_confusion_reported
    return {
        "status": "Urgent Handoff" if sudden_confusion else "Prompt Clinician Review",
        "route": (
            "immediate_specialist_clinician_handoff"
            if sudden_confusion
            else "prompt_clinician_review"
        ),
        "urgency": "urgent" if sudden_confusion else "prompt",
        "reported_signals": signals,
        "numerical_path_bypassed": True,
        "numerical_flag_raised": None,
        "baseline_mean": None,
        "follow_up_mean": None,
        "adjusted_change": None,
        "standard_error": None,
        "z_score": None,
        "reassessment": None,
        "reason": (
            "Sudden confusion was reported; numerical scoring was bypassed and urgent human assessment is required."
            if sudden_confusion
            else "Daily-function decline was reported; numerical scoring was bypassed and prompt clinician review is recommended."
        ),
    }


def classify_z_score(z_score: float) -> dict[str, Any]:
    """Apply the exact inclusive/exclusive z-score thresholds."""
    if isinstance(z_score, bool) or not isinstance(z_score, (int, float)) or not math.isfinite(float(z_score)):
        raise ValueError("z_score must be a finite number.")
    z_value = float(z_score)
    if z_value <= QUALIFIED_REVIEW_THRESHOLD:
        return {
            "status": "Qualified Review",
            "route": "specialist_clinician_handoff",
            "numerical_flag_raised": True,
            "reassessment": None,
            "reason": "Adjusted reliable change met or exceeded the qualified-review threshold.",
        }
    if z_value <= CONSIDER_REPEAT_THRESHOLD:
        return {
            "status": "Consider Repeat",
            "route": "early_reassessment",
            "numerical_flag_raised": True,
            "reassessment": {
                "required": True,
                "interval": "early_clinician_defined_interval",
                "schedule_action": "schedule_early_reassessment",
            },
            "reason": "Adjusted reliable change met the consider-repeat threshold; schedule an early reassessment.",
        }
    return {
        "status": "Routine follow-up",
        "route": "routine_follow_up",
        "numerical_flag_raised": False,
        "reassessment": None,
        "reason": "Adjusted reliable change did not cross a review threshold.",
    }


def compute_adjusted_reliable_change(
    previous_visit_scores: Sequence[float],
    follow_up_scores: Sequence[float],
    *,
    daily_function_degradation_reported: bool = False,
    sudden_confusion_reported: bool = False,
) -> dict[str, Any]:
    """Compute the specified adjusted RCI and deterministic downstream status.

    Exactly three baseline observations (Visits 1-3) and two follow-up
    observations are required because the fixed SE formula uses n=3 and n=2.
    If either reported signal flag is true, the result bypasses numeric scoring,
    even when score arrays are missing or invalid.
    """
    reported_signal = reported_signal_result(
        daily_function_degradation_reported=daily_function_degradation_reported,
        sudden_confusion_reported=sudden_confusion_reported,
    )
    if reported_signal is not None:
        return reported_signal

    baseline = _validated_scores(previous_visit_scores, BASELINE_VISIT_COUNT, "previous_visit_scores")
    follow_up = _validated_scores(follow_up_scores, FOLLOW_UP_VISIT_COUNT, "follow_up_scores")
    baseline_mean = math.fsum(baseline) / BASELINE_VISIT_COUNT
    follow_up_mean = math.fsum(follow_up) / FOLLOW_UP_VISIT_COUNT

    # Formula 1: Adjusted Change = Follow-up Mean - Baseline Mean - Practice Gain
    adjusted_change = follow_up_mean - baseline_mean - EXPECTED_PRACTICE_GAIN
    # Formula 2: SE = SD * sqrt((1-r) * (1/3 + 1/2))
    standard_error = standard_error_of_measurement()
    # Formula 3: z = Adjusted Change / SE
    z_score = adjusted_change / standard_error
    classification = classify_z_score(z_score)

    return {
        **classification,
        "reported_signals": [],
        "numerical_path_bypassed": False,
        "baseline_mean": baseline_mean,
        "follow_up_mean": follow_up_mean,
        "adjusted_change": adjusted_change,
        "standard_error": standard_error,
        "z_score": z_score,
        "parameters": {
            "synthetic_sd": SYNTHETIC_SD,
            "test_retest_reliability": TEST_RETEST_RELIABILITY,
            "expected_practice_gain": EXPECTED_PRACTICE_GAIN,
            "baseline_visits": BASELINE_VISIT_COUNT,
            "follow_up_visits": FOLLOW_UP_VISIT_COUNT,
        },
        "clinical_notice": "This synthetic calculation is not a diagnosis and requires clinician interpretation.",
    }


def _validated_scores(values: Sequence[float], expected_count: int, field_name: str) -> tuple[float, ...]:
    if isinstance(values, (str, bytes)) or not isinstance(values, Sequence):
        raise ScoringInputError(f"{field_name} must be a sequence of {expected_count} numeric scores.")
    if len(values) != expected_count:
        raise ScoringInputError(f"{field_name} must contain exactly {expected_count} scores.")
    validated: list[float] = []
    for index, value in enumerate(values):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ScoringInputError(f"{field_name}[{index}] must be a real numeric score.")
        numeric = float(value)
        if not math.isfinite(numeric):
            raise ScoringInputError(f"{field_name}[{index}] must be finite.")
        validated.append(numeric)
    return tuple(validated)


class CognitiveChangeScoringAgent:
    """Adapter for Stage 06 in ``WorkflowEngine``.

    Expected context shape: ``initial_input.cognitive_change_scoring`` with
    ``previous_visit_scores`` (3 values), ``follow_up_scores`` (2 values), and
    optional boolean report flags. A true report flag bypasses score validation.
    """

    version = AGENT_VERSION

    async def execute(self, context: Mapping[str, Any]) -> AgentResult:
        initial_input = context.get("initial_input")
        if not isinstance(initial_input, Mapping):
            raise ScoringInputError("Workflow context is missing initial_input.")
        payload = initial_input.get("cognitive_change_scoring")
        if not isinstance(payload, Mapping):
            raise ScoringInputError("initial_input.cognitive_change_scoring must be an object.")

        output = compute_adjusted_reliable_change(
            payload.get("previous_visit_scores", ()),
            payload.get("follow_up_scores", ()),
            daily_function_degradation_reported=payload.get("daily_function_degradation_reported", False),
            sudden_confusion_reported=payload.get("sudden_confusion_reported", False),
        )
        return AgentResult(
            output=output,
            version=self.version,
            reason=output["reason"],
        )
