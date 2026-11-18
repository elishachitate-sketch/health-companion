enum CognitiveTaskType {
  nBack,
  stroop,
  spatialGrid,
  memory,
  attention,
  flexibleThinking,
}

enum CognitiveSessionState {
  inactive,
  active,
  paused,
  completed,
  cancelled,
}

enum CompletionStatus {
  completed,
  paused,
  cancelled,
  failed,
}

class CognitiveTaskConfig {
  const CognitiveTaskConfig({
    required this.type,
    required this.maxScore,
    required this.expectedReactionMs,
    required this.maxErrorRate,
  });

  final CognitiveTaskType type;
  final int maxScore;
  final int expectedReactionMs;
  final double maxErrorRate;

  static const Map<CognitiveTaskType, CognitiveTaskConfig> registry = {
    CognitiveTaskType.nBack: CognitiveTaskConfig(
      type: CognitiveTaskType.nBack,
      maxScore: 20,
      expectedReactionMs: 2600,
      maxErrorRate: 0.35,
    ),
    CognitiveTaskType.stroop: CognitiveTaskConfig(
      type: CognitiveTaskType.stroop,
      maxScore: 30,
      expectedReactionMs: 3200,
      maxErrorRate: 0.4,
    ),
    CognitiveTaskType.spatialGrid: CognitiveTaskConfig(
      type: CognitiveTaskType.spatialGrid,
      maxScore: 25,
      expectedReactionMs: 2800,
      maxErrorRate: 0.3,
    ),
  };
}

class CognitiveSessionRecord {
  const CognitiveSessionRecord({
    required this.sessionId,
    required this.timestamp,
    required this.taskType,
    required this.completionStatus,
    required this.rawScore,
    required this.reactionTimeMs,
    required this.errorRate,
    required this.patientId,
    this.metadata = const {},
    this.protocolVersion = 'prototype-v1',
    this.formId = 'default',
    this.languageTag = 'en-US',
    this.accessibilityMode = 'standard',
    this.attemptCount = 0,
  });

  final String sessionId;
  final DateTime timestamp;
  final CognitiveTaskType taskType;
  final CompletionStatus completionStatus;
  final int rawScore;
  final int reactionTimeMs;
  final double errorRate;
  final String patientId;
  final Map<String, dynamic> metadata;
  final String protocolVersion;
  final String formId;
  final String languageTag;
  final String accessibilityMode;
  final int attemptCount;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'task_type': taskType.name,
        'completion_status': completionStatus.name,
        'raw_score': rawScore,
        'reaction_time_ms': reactionTimeMs,
        'error_rate': errorRate,
        'patient_id': patientId,
        'metadata': metadata,
        'protocol_version': protocolVersion,
        'form_id': formId,
        'language_tag': languageTag,
        'accessibility_mode': accessibilityMode,
        'attempt_count': attemptCount,
      };

  factory CognitiveSessionRecord.fromJson(Map<String, dynamic> map) {
    return CognitiveSessionRecord(
      sessionId: map['session_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      taskType: CognitiveTaskType.values.firstWhere(
        (type) => type.name == map['task_type'],
      ),
      completionStatus: CompletionStatus.values.firstWhere(
        (status) => status.name == map['completion_status'],
      ),
      rawScore: map['raw_score'] as int,
      reactionTimeMs: map['reaction_time_ms'] as int,
      errorRate: (map['error_rate'] as num).toDouble(),
      patientId: map['patient_id'] as String,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? const {}),
      protocolVersion: map['protocol_version'] as String? ?? 'prototype-v1',
      formId: map['form_id'] as String? ?? 'default',
      languageTag: map['language_tag'] as String? ?? 'en-US',
      accessibilityMode: map['accessibility_mode'] as String? ?? 'standard',
      attemptCount: map['attempt_count'] as int? ?? 0,
    );
  }
}
