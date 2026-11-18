import 'dart:math';

import '../models/cognitive_session_record.dart';

class CognitiveTaskSession {
  CognitiveTaskSession({
    required this.patientId,
    Random? random,
    this.languageTag = 'en-US',
    this.accessibilityMode = 'standard',
    this.protocolVersion = 'prototype-v1',
  }) : _random = random ?? Random();

  final String patientId;
  final String languageTag;
  final String accessibilityMode;
  final String protocolVersion;
  final Random _random;

  CognitiveTaskType? currentTaskType;
  CognitiveSessionState state = CognitiveSessionState.inactive;
  DateTime? startedAt;
  DateTime? completedAt;

  int score = 0;
  int reactionTimeMs = 0;
  int errorCount = 0;
  int attemptCount = 0;

  CognitiveTaskType startNewSession() {
    const tasks = CognitiveTaskType.values;
    currentTaskType = tasks[_random.nextInt(tasks.length)];
    state = CognitiveSessionState.active;
    startedAt = DateTime.now();
    completedAt = null;

    score = 0;
    reactionTimeMs = 0;
    errorCount = 0;
    attemptCount = 0;

    return currentTaskType!;
  }

  void pause() {
    if (state == CognitiveSessionState.active) {
      state = CognitiveSessionState.paused;
    }
  }

  void resume() {
    if (state == CognitiveSessionState.paused) {
      state = CognitiveSessionState.active;
    }
  }

  void registerAttempt({
    required int scoreDelta,
    required int latencyMs,
    required bool hadError,
  }) {
    if (state != CognitiveSessionState.active) return;
    if (scoreDelta < 0 || latencyMs < 0) {
      throw ArgumentError('Score and reaction time must not be negative.');
    }
    final config = CognitiveTaskConfig.registry[currentTaskType!]!;
    if (score + scoreDelta > config.maxScore) {
      throw ArgumentError('Score cannot exceed the task maximum.');
    }

    score += scoreDelta;
    reactionTimeMs += latencyMs;
    attemptCount += 1;
    if (hadError) {
      errorCount += 1;
    }
  }

  CognitiveSessionRecord complete() {
    if (currentTaskType == null) {
      throw StateError('No active cognitive task session started.');
    }

    final effectiveReaction =
        attemptCount == 0 ? 0 : (reactionTimeMs / attemptCount).round();
    final errorRate = attemptCount == 0 ? 0.0 : errorCount / attemptCount;

    final record = CognitiveSessionRecord(
      sessionId: 'cog_${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now().toUtc(),
      taskType: currentTaskType!,
      completionStatus: CompletionStatus.completed,
      rawScore: score,
      reactionTimeMs: effectiveReaction,
      errorRate: errorRate,
      patientId: patientId,
      protocolVersion: protocolVersion,
      formId: 'default',
      languageTag: languageTag,
      accessibilityMode: accessibilityMode,
      attemptCount: attemptCount,
      metadata: {
        'started_at': startedAt?.toUtc().toIso8601String(),
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    state = CognitiveSessionState.completed;
    completedAt = DateTime.now();
    return record;
  }

  CognitiveSessionRecord cancel() {
    if (currentTaskType == null) {
      throw StateError('No active cognitive task session started.');
    }

    final effectiveReaction =
        attemptCount == 0 ? 0 : (reactionTimeMs / attemptCount).round();
    final errorRate = attemptCount == 0 ? 0.0 : errorCount / attemptCount;

    final record = CognitiveSessionRecord(
      sessionId: 'cog_${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now().toUtc(),
      taskType: currentTaskType!,
      completionStatus: CompletionStatus.cancelled,
      rawScore: score,
      reactionTimeMs: effectiveReaction,
      errorRate: errorRate,
      patientId: patientId,
      protocolVersion: protocolVersion,
      formId: 'default',
      languageTag: languageTag,
      accessibilityMode: accessibilityMode,
      attemptCount: attemptCount,
      metadata: {
        'started_at': startedAt?.toUtc().toIso8601String(),
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    state = CognitiveSessionState.cancelled;
    completedAt = DateTime.now();
    return record;
  }
}
