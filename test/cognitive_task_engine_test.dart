import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_companion/models/cognitive_session_record.dart';
import 'package:health_companion/services/cognitive_task_engine.dart';

void main() {
  group('CognitiveTaskSession', () {
    test('starts a randomized task and creates a valid record', () {
      final session = CognitiveTaskSession(
        patientId: 'patient-123',
        random: Random(42),
        languageTag: 'ar-AE',
        accessibilityMode: 'large_text',
      );

      final task = session.startNewSession();

      expect(
        CognitiveTaskType.values.contains(task),
        isTrue,
      );
      expect(session.state, CognitiveSessionState.active);

      session.registerAttempt(
        scoreDelta: 4,
        latencyMs: 900,
        hadError: false,
      );
      session.registerAttempt(
        scoreDelta: 3,
        latencyMs: 1100,
        hadError: true,
      );

      final record = session.complete();

      expect(record.taskType, task);
      expect(record.completionStatus, CompletionStatus.completed);
      expect(record.rawScore, 7);
      expect(record.reactionTimeMs, 1000);
      expect(record.errorRate, closeTo(0.5, 0.0001));
      expect(record.attemptCount, 2);
      expect(record.languageTag, 'ar-AE');
      expect(record.accessibilityMode, 'large_text');

      final json = record.toJson();
      expect(
          json.keys,
          containsAll([
            'session_id',
            'timestamp',
            'task_type',
            'completion_status',
            'raw_score',
            'reaction_time_ms',
            'error_rate',
            'protocol_version',
            'form_id',
            'language_tag',
            'accessibility_mode',
            'attempt_count',
          ]));
      expect(json, isNot(contains('cognitive_load_index')));

      final restored = CognitiveSessionRecord.fromJson(json);
      expect(restored.languageTag, 'ar-AE');
      expect(restored.accessibilityMode, 'large_text');
      expect(restored.attemptCount, 2);
    });

    test('rejects invalid attempt values and scores beyond task maximum', () {
      final session = CognitiveTaskSession(
        patientId: 'patient-123',
        random: Random(42),
      );
      final task = session.startNewSession();
      final maxScore = CognitiveTaskConfig.registry[task]!.maxScore;

      expect(
        () => session.registerAttempt(
          scoreDelta: maxScore + 1,
          latencyMs: 100,
          hadError: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => session.registerAttempt(
          scoreDelta: 0,
          latencyMs: -1,
          hadError: false,
        ),
        throwsArgumentError,
      );
    });
  });
}
