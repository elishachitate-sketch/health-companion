import 'package:flutter_test/flutter_test.dart';
import 'package:health_companion/models/cognitive_session_record.dart';
import 'package:health_companion/services/cognitive_longitudinal_tracker.dart';

void main() {
  const tracker = CognitiveLongitudinalTracker();

  group('CognitiveLongitudinalTracker', () {
    test('reports descriptive within-person change after 3+2 sessions', () {
      final records = [
        _record(0, 10, metadata: {
          'context_factors': {'sleep': 'fair'}
        }),
        _record(1, 11, metadata: {
          'context_factors': {'sleep': 'fair'}
        }),
        _record(2, 9, metadata: {
          'context_factors': {'sleep': 'fair'}
        }),
        _record(3, 8, metadata: {
          'context_factors': {'sleep': 'poor'}
        }),
        _record(4, 7, metadata: {
          'context_factors': {'sleep': 'poor'}
        }),
      ];

      final summary = tracker.summarize(
        records,
        taskType: CognitiveTaskType.nBack,
      );

      expect(summary.status, CognitiveComparisonStatus.descriptiveComparison);
      expect(summary.baselineSessionCount, 3);
      expect(summary.followUpSessionCount, 2);
      expect(summary.baselineMean, 10);
      expect(summary.followUpMean, 7.5);
      expect(summary.observedChange, -2.5);
      expect(summary.direction, CognitiveScoreDirection.decreased);
      expect(summary.isDescriptiveOnly, isTrue);
      expect(
          summary.contextWarnings, contains('sleep changed or is incomplete'));
    });

    test('does not compare sessions across protocol changes', () {
      final records = [
        _record(0, 10),
        _record(1, 11),
        _record(2, 9),
        _record(3, 8),
        _record(4, 7, protocolVersion: 'prototype-v2'),
      ];

      final summary = tracker.summarize(
        records,
        taskType: CognitiveTaskType.nBack,
      );

      expect(summary.status, CognitiveComparisonStatus.insufficientHistory);
      expect(summary.observedChange, isNull);
      expect(summary.excludedIncompatibleSessionCount, 4);
    });

    test('requires enough completed sessions with recorded attempts', () {
      final summary = tracker.summarize(
        [_record(0, 10), _record(1, 11), _record(2, 9)],
        taskType: CognitiveTaskType.nBack,
      );

      expect(summary.status, CognitiveComparisonStatus.insufficientHistory);
      expect(summary.baselineSessionCount, 3);
      expect(summary.followUpSessionCount, 0);
      expect(summary.observedChange, isNull);
    });
  });
}

CognitiveSessionRecord _record(
  int visit,
  int score, {
  String protocolVersion = 'prototype-v1',
  Map<String, dynamic> metadata = const {},
  CompletionStatus status = CompletionStatus.completed,
  int attemptCount = 10,
}) =>
    CognitiveSessionRecord(
      sessionId: 'session-$visit',
      timestamp: DateTime.utc(2026, 1, visit + 1),
      taskType: CognitiveTaskType.nBack,
      completionStatus: status,
      rawScore: score,
      reactionTimeMs: 1200,
      errorRate: 0.1,
      patientId: 'pseudonymous-patient',
      protocolVersion: protocolVersion,
      formId: 'default',
      languageTag: 'en-US',
      accessibilityMode: 'standard',
      attemptCount: attemptCount,
      metadata: metadata,
    );
