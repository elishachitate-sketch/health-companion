"""Synthetic tests for the specified Stage 06 scoring rules."""

from __future__ import annotations

import math
import unittest

from brain_health_review.cognitive_change_scoring import (
    EXPECTED_PRACTICE_GAIN,
    FOLLOW_UP_VISIT_COUNT,
    SYNTHETIC_SD,
    TEST_RETEST_RELIABILITY,
    CognitiveChangeScoringAgent,
    ScoringInputError,
    classify_z_score,
    compute_adjusted_reliable_change,
    standard_error_of_measurement,
)
from brain_health_review.workflow import Stage


class CognitiveChangeScoringTests(unittest.TestCase):
    def test_exact_fixed_standard_error_formula(self) -> None:
        expected = 1.5 * math.sqrt((1 - 0.85) * (1 / 3 + 1 / 2))
        self.assertEqual(SYNTHETIC_SD, 1.5)
        self.assertEqual(TEST_RETEST_RELIABILITY, 0.85)
        self.assertEqual(EXPECTED_PRACTICE_GAIN, 0.3)
        self.assertEqual(FOLLOW_UP_VISIT_COUNT, 2)
        self.assertEqual(standard_error_of_measurement(), expected)

    def test_baseline_uses_mean_of_visits_one_through_three(self) -> None:
        result = compute_adjusted_reliable_change([10, 11, 12], [13, 13])
        self.assertEqual(result["baseline_mean"], 11)
        self.assertEqual(result["follow_up_mean"], 13)
        self.assertAlmostEqual(result["adjusted_change"], 13 - 11 - 0.3)
        self.assertAlmostEqual(result["z_score"], (13 - 11 - 0.3) / standard_error_of_measurement())
        self.assertEqual(result["status"], "Routine follow-up")
        self.assertFalse(result["numerical_flag_raised"])

    def test_qualified_review_threshold_inclusive(self) -> None:
        self.assertEqual(classify_z_score(-1.96)["status"], "Qualified Review")
        self.assertEqual(classify_z_score(-2.2)["route"], "specialist_clinician_handoff")

    def test_consider_repeat_lower_bound_exclusive_and_upper_bound_inclusive(self) -> None:
        self.assertEqual(classify_z_score(math.nextafter(-1.96, math.inf))["status"], "Consider Repeat")
        self.assertEqual(classify_z_score(-1.645)["status"], "Consider Repeat")
        result = classify_z_score(-1.645)
        self.assertTrue(result["reassessment"]["required"])
        self.assertEqual(result["reassessment"]["schedule_action"], "schedule_early_reassessment")
        self.assertEqual(result["reassessment"]["interval"], "early_clinician_defined_interval")

    def test_routine_threshold_strictly_greater_than_minus_1_645(self) -> None:
        result = classify_z_score(math.nextafter(-1.645, math.inf))
        self.assertEqual(result["status"], "Routine follow-up")
        self.assertEqual(result["route"], "routine_follow_up")
        self.assertFalse(result["numerical_flag_raised"])

    def test_daily_function_decline_routes_to_prompt_review(self) -> None:
        result = compute_adjusted_reliable_change(
            [],
            [],
            daily_function_degradation_reported=True,
        )
        self.assertEqual(result["status"], "Prompt Clinician Review")
        self.assertEqual(result["route"], "prompt_clinician_review")
        self.assertEqual(result["urgency"], "prompt")
        self.assertTrue(result["numerical_path_bypassed"])
        self.assertIsNone(result["z_score"])
        self.assertIsNone(result["standard_error"])

    def test_urgent_sudden_confusion_signal_bypasses_scores(self) -> None:
        result = compute_adjusted_reliable_change(
            None,  # type: ignore[arg-type]
            None,  # type: ignore[arg-type]
            sudden_confusion_reported=True,
        )
        self.assertEqual(result["status"], "Urgent Handoff")
        self.assertIsNone(result["z_score"])
        self.assertEqual(result["reported_signals"], ["sudden_confusion_reported"])

    def test_both_reported_signals_use_urgent_route(self) -> None:
        result = compute_adjusted_reliable_change(
            [],
            [],
            daily_function_degradation_reported=True,
            sudden_confusion_reported=True,
        )
        self.assertEqual(result["status"], "Urgent Handoff")
        self.assertEqual(result["urgency"], "urgent")

    def test_requires_exact_sample_counts_and_finite_numeric_values(self) -> None:
        with self.assertRaises(ScoringInputError):
            compute_adjusted_reliable_change([1, 2], [3, 4])
        with self.assertRaises(ScoringInputError):
            compute_adjusted_reliable_change([1, 2, 3], [4])
        with self.assertRaises(ScoringInputError):
            compute_adjusted_reliable_change([1, 2, float("nan")], [4, 5])
        with self.assertRaises(ScoringInputError):
            compute_adjusted_reliable_change([True, 2, 3], [4, 5])

    def test_stage_06_adapter_consumes_workflow_input(self) -> None:
        agent = CognitiveChangeScoringAgent()
        import asyncio

        result = asyncio.run(agent.execute({
            "initial_input": {
                "cognitive_change_scoring": {
                    "previous_visit_scores": [10, 10, 10],
                    "follow_up_scores": [9, 9],
                }
            }
        }))
        self.assertEqual(result.version, agent.version)
        self.assertIn("z_score", result.output)
        self.assertEqual(Stage.COGNITIVE_CHANGE_SCORING.value, "06_cognitive_change_scoring")


if __name__ == "__main__":
    unittest.main()
