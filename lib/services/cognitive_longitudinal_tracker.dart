import '../models/cognitive_session_record.dart';

enum CognitiveComparisonStatus {
  insufficientHistory,
  descriptiveComparison,
}

enum CognitiveScoreDirection {
  increased,
  decreased,
  unchanged,
}

/// Describes change within a person's own repeated task scores.
///
/// This is deliberately not a diagnosis, validated reliable-change index, or
/// automatic referral rule. It only compares records with matching protocol,
/// task form, language, and accessibility metadata.
class CognitiveLongitudinalSummary {
  const CognitiveLongitudinalSummary({
    required this.status,
    required this.taskType,
    required this.baselineSessionCount,
    required this.followUpSessionCount,
    required this.excludedIncompatibleSessionCount,
    required this.contextWarnings,
    this.baselineMean,
    this.followUpMean,
    this.observedChange,
    this.direction,
  });

  final CognitiveComparisonStatus status;
  final CognitiveTaskType taskType;
  final int baselineSessionCount;
  final int followUpSessionCount;
  final int excludedIncompatibleSessionCount;
  final List<String> contextWarnings;
  final double? baselineMean;
  final double? followUpMean;
  final double? observedChange;
  final CognitiveScoreDirection? direction;

  bool get isDescriptiveOnly => true;
}

class CognitiveLongitudinalTracker {
  const CognitiveLongitudinalTracker();

  /// Uses the earliest three completed sessions as a personal baseline and the
  /// latest two as follow-up. At least five comparable completed sessions are
  /// needed. It reports raw descriptive change only; clinical thresholds must
  /// be validated for the instrument and population before being added.
  CognitiveLongitudinalSummary summarize(
    Iterable<CognitiveSessionRecord> records, {
    required CognitiveTaskType taskType,
  }) {
    final taskRecords = records
        .where((record) =>
            record.taskType == taskType &&
            record.completionStatus == CompletionStatus.completed &&
            record.attemptCount > 0)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (taskRecords.isEmpty) {
      return _insufficient(taskType, 0, 0);
    }

    final reference = taskRecords.last;
    final comparable = taskRecords
        .where((record) => _sameProtocol(reference, record))
        .toList(growable: false);
    final excluded = taskRecords.length - comparable.length;
    if (comparable.length < 5) {
      return _insufficient(taskType, excluded, comparable.length);
    }

    final baseline = comparable.take(3).toList(growable: false);
    final followUp = comparable.skip(comparable.length - 2).toList();
    final baselineMean = _mean(baseline);
    final followUpMean = _mean(followUp);
    final change = followUpMean - baselineMean;
    final direction = change > 0
        ? CognitiveScoreDirection.increased
        : change < 0
            ? CognitiveScoreDirection.decreased
            : CognitiveScoreDirection.unchanged;

    return CognitiveLongitudinalSummary(
      status: CognitiveComparisonStatus.descriptiveComparison,
      taskType: taskType,
      baselineSessionCount: baseline.length,
      followUpSessionCount: followUp.length,
      excludedIncompatibleSessionCount: excluded,
      contextWarnings: _contextWarnings([...baseline, ...followUp]),
      baselineMean: baselineMean,
      followUpMean: followUpMean,
      observedChange: change,
      direction: direction,
    );
  }

  CognitiveLongitudinalSummary _insufficient(
    CognitiveTaskType taskType,
    int excluded,
    int available,
  ) =>
      CognitiveLongitudinalSummary(
        status: CognitiveComparisonStatus.insufficientHistory,
        taskType: taskType,
        baselineSessionCount: available < 3 ? available : 3,
        followUpSessionCount:
            available > 3 && available < 5 ? available - 3 : 0,
        excludedIncompatibleSessionCount: excluded,
        contextWarnings: const [],
      );

  bool _sameProtocol(
    CognitiveSessionRecord left,
    CognitiveSessionRecord right,
  ) =>
      left.taskType == right.taskType &&
      left.protocolVersion == right.protocolVersion &&
      left.formId == right.formId &&
      left.languageTag.toLowerCase() == right.languageTag.toLowerCase() &&
      left.accessibilityMode == right.accessibilityMode;

  double _mean(List<CognitiveSessionRecord> records) =>
      records.fold<double>(0, (total, record) => total + record.rawScore) /
      records.length;

  List<String> _contextWarnings(List<CognitiveSessionRecord> records) {
    const trackedFactors = ['mood', 'sleep', 'stress', 'hearing', 'vision'];
    final warnings = <String>[];
    for (final factor in trackedFactors) {
      final values = records
          .map((record) => record.metadata['context_factors'] is Map
              ? (record.metadata['context_factors'] as Map)[factor]
              : null)
          .toSet();
      if (values.length > 1) warnings.add('$factor changed or is incomplete');
    }
    return List.unmodifiable(warnings);
  }
}
