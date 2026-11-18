import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_language.dart';
import '../models/cognitive_session_record.dart';
import 'cognitive_local_store.dart';
import 'cognitive_longitudinal_tracker.dart';

/// Practice result categories recorded locally in the encrypted cognitive store.
enum CognitiveTask { memory, attention, flexibleThinking }

enum ChatTone { worried, tired, hopeful, calm, neutral }

class ChatEntry {
  const ChatEntry({
    required this.date,
    required this.message,
    required this.tone,
    this.role = 'user',
  });

  final DateTime date;
  final String message;
  final ChatTone tone;
  final String role;
}

class VoiceNote {
  const VoiceNote({
    required this.date,
    required this.durationSeconds,
    required this.speechRate,
    required this.pauses,
    required this.energy,
    required this.toneWords,
    required this.transcript,
    required this.wellbeingSignal,
  });

  final DateTime date;
  final int durationSeconds;
  final String speechRate;
  final String pauses;
  final String energy;
  final List<String> toneWords;
  final String transcript;
  final String wellbeingSignal;
}

class MoodEntry {
  const MoodEntry({required this.date, required this.score, this.note = ''});

  final DateTime date;
  final int score;
  final String note;
}

class SleepEntry {
  const SleepEntry({
    required this.date,
    required this.hours,
    required this.quality,
  });

  final DateTime date;
  final double hours;
  final String quality;
}

class WalkEntry {
  const WalkEntry({required this.date, required this.steps});

  final DateTime date;
  final int steps;
}

class PreventionPlanEntry {
  const PreventionPlanEntry({required this.date, required this.actions});

  final DateTime date;
  final List<String> actions;
}

class FunctionalEntry {
  const FunctionalEntry({required this.date, required this.supportLevel});

  final DateTime date;
  final int supportLevel;
}

class CognitiveTaskResult {
  const CognitiveTaskResult({
    required this.date,
    required this.task,
    required this.score,
    required this.timeSeconds,
  });

  final DateTime date;
  final CognitiveTask task;
  final int score;
  final int timeSeconds;

  factory CognitiveTaskResult.fromRecord(CognitiveSessionRecord record) {
    final task = switch (record.taskType) {
      CognitiveTaskType.memory ||
      CognitiveTaskType.nBack =>
        CognitiveTask.memory,
      CognitiveTaskType.attention => CognitiveTask.attention,
      CognitiveTaskType.flexibleThinking ||
      CognitiveTaskType.stroop ||
      CognitiveTaskType.spatialGrid =>
        CognitiveTask.flexibleThinking,
    };
    return CognitiveTaskResult(
      date: record.timestamp,
      task: task,
      score: record.rawScore,
      timeSeconds: record.reactionTimeMs ~/ 1000,
    );
  }
}

class ReviewDataSnapshot {
  const ReviewDataSnapshot({
    required this.sleepEntries,
    required this.walkEntries,
    required this.moodEntries,
    required this.cognitiveEntries,
    required this.chatEntries,
    required this.voiceNotes,
    required this.functionalEntries,
    required this.preventionPlans,
    required this.cognitiveChanges,
  });

  final List<SleepEntry> sleepEntries;
  final List<WalkEntry> walkEntries;
  final List<MoodEntry> moodEntries;
  final List<CognitiveTaskResult> cognitiveEntries;
  final List<ChatEntry> chatEntries;
  final List<VoiceNote> voiceNotes;
  final List<FunctionalEntry> functionalEntries;
  final List<PreventionPlanEntry> preventionPlans;
  final List<CognitiveLongitudinalSummary> cognitiveChanges;
}

class DataService {
  DataService._();

  static final DataService instance = DataService._();
  CognitiveLocalStore? _store;
  Database? _database;
  Future<CognitiveLocalStore>? _storeOpening;

  bool get isUsingTemporaryStorage => _store?.isEphemeral ?? false;

  Future<({String languageTag, String accessibilityMode})>
      _currentRecordingContext() async {
    final preferences = await SharedPreferences.getInstance();
    String preferenceState(String key) {
      final value = preferences.getBool(key);
      if (value == null) return 'unspecified';
      return value ? 'selected' : 'not_selected';
    }

    final languageTag =
        AppLanguage.locale.value.languageCode == 'ar' ? 'ar' : 'en-US';
    return (
      languageTag: languageTag,
      accessibilityMode: 'preferences_only;'
          'hearing=${preferenceState('comfort_hearing_support')};'
          'vision=${preferenceState('comfort_vision_support')};'
          'companion=${preferenceState('comfort_continue_with_someone')}',
    );
  }

  ChatTone detectChatTone(String message) {
    final normalized = message.toLowerCase();
    const tiredWords = ['tired', 'exhausted'];
    const worriedWords = [
      'worried',
      'sad',
      'stressed',
      'forgot',
      'confused',
      'scared',
    ];
    const hopefulWords = ['good', 'better', 'hopeful', 'thank'];
    const calmWords = ['calm', 'happy', 'okay'];

    bool containsAny(List<String> words) => words.any((word) =>
        RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(normalized));

    if (containsAny(tiredWords)) return ChatTone.tired;
    if (containsAny(worriedWords)) return ChatTone.worried;
    if (containsAny(hopefulWords)) return ChatTone.hopeful;
    if (containsAny(calmWords)) return ChatTone.calm;
    return ChatTone.neutral;
  }

  Future<void> saveChatEntry(ChatEntry entry) async {
    final recordingContext = await _currentRecordingContext();
    final record = CognitiveSessionRecord(
      sessionId: 'chat_${entry.date.microsecondsSinceEpoch}',
      timestamp: entry.date.toUtc(),
      taskType: CognitiveTaskType.memory,
      completionStatus: CompletionStatus.completed,
      rawScore: 0,
      reactionTimeMs: 0,
      errorRate: 0,
      patientId: 'local-practice-profile',
      protocolVersion: 'chat-tone-v1',
      formId: 'chat',
      languageTag: recordingContext.languageTag,
      accessibilityMode: recordingContext.accessibilityMode,
      attemptCount: 0,
      metadata: {
        'source': 'chat_entry',
        'accessibility_context_note':
            'Saved preferences only; accommodation use is not verified.',
        'message': entry.message,
        'tone': entry.tone.name,
        'role': entry.role,
      },
    );
    await (await _getStore()).saveRecord(record);
  }

  Future<List<ChatEntry>> getChatEntriesSince(DateTime since) async {
    final records = await (await _getStore()).getRecordsSince(since);
    return records
        .where((record) => record.metadata['source'] == 'chat_entry')
        .map((record) => ChatEntry(
              date: record.timestamp,
              message: record.metadata['message'] as String? ?? '',
              tone: ChatTone.values.firstWhere(
                (tone) => tone.name == record.metadata['tone'],
                orElse: () => ChatTone.neutral,
              ),
              role: record.metadata['role'] as String? ?? 'user',
            ))
        .toList(growable: false);
  }

  Future<List<ChatEntry>> getChatEntriesLast7Days() => getChatEntriesSince(
      DateTime.now().toUtc().subtract(const Duration(days: 7)));

  Future<ChatEntry?> getLatestChatEntry() async {
    final entries = await getChatEntriesSince(
      DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
    );
    entries.sort((left, right) => right.date.compareTo(left.date));
    return entries.isEmpty ? null : entries.first;
  }

  Future<void> addVoiceNote(VoiceNote note) async {
    final recordingContext = await _currentRecordingContext();
    final record = CognitiveSessionRecord(
      sessionId: 'voice_${note.date.microsecondsSinceEpoch}',
      timestamp: note.date.toUtc(),
      taskType: CognitiveTaskType.memory,
      completionStatus: CompletionStatus.completed,
      rawScore: 0,
      reactionTimeMs: note.durationSeconds * 1000,
      errorRate: 0,
      patientId: 'local-practice-profile',
      protocolVersion: 'voice-checkin-v1',
      formId: 'voice-checkin',
      languageTag: recordingContext.languageTag,
      accessibilityMode: recordingContext.accessibilityMode,
      attemptCount: 0,
      metadata: {
        'source': 'voice_note',
        'accessibility_context_note':
            'Saved preferences only; accommodation use is not verified.',
        'duration_seconds': note.durationSeconds,
        'speech_rate': note.speechRate,
        'pauses': note.pauses,
        'energy': note.energy,
        'tone_words': note.toneWords,
        'transcript': note.transcript,
        'wellbeing_signal': note.wellbeingSignal,
      },
    );
    await (await _getStore()).saveRecord(record);
  }

  Future<VoiceNote?> getLatestVoiceNote() async {
    final records = await (await _getStore()).getRecordsSince(
      DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
    );
    final voiceRecords = records
        .where((record) => record.metadata['source'] == 'voice_note')
        .toList()
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
    if (voiceRecords.isEmpty) return null;
    final latest = voiceRecords.first;
    return VoiceNote(
      date: latest.timestamp,
      durationSeconds: latest.metadata['duration_seconds'] as int? ??
          latest.reactionTimeMs ~/ 1000,
      speechRate: latest.metadata['speech_rate'] as String? ?? 'Normal',
      pauses: latest.metadata['pauses'] as String? ?? 'Few',
      energy: latest.metadata['energy'] as String? ?? 'Steady',
      toneWords: (latest.metadata['tone_words'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      transcript: latest.metadata['transcript'] as String? ?? '',
      wellbeingSignal:
          latest.metadata['wellbeing_signal'] as String? ?? 'Steady',
    );
  }

  Future<void> addMoodEntry(MoodEntry entry) => _saveWellbeingEntry(
        source: 'mood_entry',
        date: entry.date,
        formId: 'mood',
        metadata: {
          'score': entry.score.clamp(1, 5),
          'note': entry.note,
        },
      );

  Future<MoodEntry?> getLatestMoodEntry() async {
    final record = await _latestRecordFor('mood_entry');
    if (record == null) return null;
    return MoodEntry(
      date: record.timestamp,
      score: record.metadata['score'] as int? ?? 0,
      note: record.metadata['note'] as String? ?? '',
    );
  }

  Future<void> addSleepEntry(SleepEntry entry) => _saveWellbeingEntry(
        source: 'sleep_entry',
        date: entry.date,
        formId: 'sleep',
        metadata: {
          'hours': entry.hours,
          'quality': entry.quality,
        },
      );

  Future<SleepEntry?> getLatestSleepEntry() async {
    final record = await _latestRecordFor('sleep_entry');
    if (record == null) return null;
    return SleepEntry(
      date: record.timestamp,
      hours: (record.metadata['hours'] as num?)?.toDouble() ?? 0,
      quality: record.metadata['quality'] as String? ?? '',
    );
  }

  Future<void> addWalkEntry(WalkEntry entry) => _saveWellbeingEntry(
        source: 'walk_entry',
        date: entry.date,
        formId: 'walking',
        metadata: {'steps': entry.steps < 0 ? 0 : entry.steps},
      );

  Future<WalkEntry?> getLatestWalkEntry() async {
    final record = await _latestRecordFor('walk_entry');
    if (record == null) return null;
    return WalkEntry(
      date: record.timestamp,
      steps: record.metadata['steps'] as int? ?? 0,
    );
  }

  Future<void> savePreventionPlan(PreventionPlanEntry entry) =>
      _saveWellbeingEntry(
        source: 'prevention_plan',
        date: entry.date,
        formId: 'user_selected_actions',
        metadata: {'actions': entry.actions},
      );

  Future<PreventionPlanEntry?> getLatestPreventionPlan() async {
    final record = await _latestRecordFor('prevention_plan');
    if (record == null) return null;
    return PreventionPlanEntry(
      date: record.timestamp,
      actions: (record.metadata['actions'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  Future<void> addFunctionalEntry(FunctionalEntry entry) => _saveWellbeingEntry(
        source: 'functional_entry',
        date: entry.date,
        formId: 'daily_function_support',
        metadata: {'support_level': entry.supportLevel.clamp(1, 3)},
      );

  Future<CognitiveTaskResult?> getLatestCognitiveTaskResult() async {
    final results = await getLast30Days();
    if (results.isEmpty) return null;
    results.sort((left, right) => right.date.compareTo(left.date));
    return results.first;
  }

  Future<void> _saveWellbeingEntry({
    required String source,
    required DateTime date,
    required String formId,
    required Map<String, dynamic> metadata,
  }) async {
    final recordingContext = await _currentRecordingContext();
    final record = CognitiveSessionRecord(
      sessionId: '${source}_${date.microsecondsSinceEpoch}',
      timestamp: date.toUtc(),
      taskType: CognitiveTaskType.memory,
      completionStatus: CompletionStatus.completed,
      rawScore: 0,
      reactionTimeMs: 0,
      errorRate: 0,
      patientId: 'local-practice-profile',
      protocolVersion: 'wellbeing-log-v1',
      formId: formId,
      languageTag: recordingContext.languageTag,
      accessibilityMode: recordingContext.accessibilityMode,
      attemptCount: 0,
      metadata: {
        'source': source,
        'accessibility_context_note':
            'Saved preferences only; accommodation use is not verified.',
        ...metadata,
      },
    );
    await (await _getStore()).saveRecord(record);
  }

  Future<CognitiveSessionRecord?> _latestRecordFor(String source) async {
    final records = await (await _getStore()).getRecordsSince(
      DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
    );
    final matching = records
        .where((record) => record.metadata['source'] == source)
        .toList()
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
    return matching.isEmpty ? null : matching.first;
  }

  Future<CognitiveLocalStore> _getStore() async {
    final existing = _store;
    if (existing != null) return existing;
    final opening = _storeOpening ??= _openStore();
    try {
      return await opening;
    } finally {
      if (identical(_storeOpening, opening)) _storeOpening = null;
    }
  }

  Future<CognitiveLocalStore> _openStore() async {
    final store = await CognitiveLocalStore.open();
    _database = store.database;
    return _store = store;
  }

  Future<void> saveCognitiveTaskResult(CognitiveTaskResult result) async {
    final recordingContext = await _currentRecordingContext();
    final taskType = switch (result.task) {
      CognitiveTask.memory => CognitiveTaskType.memory,
      CognitiveTask.attention => CognitiveTaskType.attention,
      CognitiveTask.flexibleThinking => CognitiveTaskType.flexibleThinking,
    };
    final score = result.score.clamp(0, 100);
    final record = CognitiveSessionRecord(
      sessionId: 'practice_${result.date.microsecondsSinceEpoch}',
      timestamp: result.date.toUtc(),
      taskType: taskType,
      completionStatus: CompletionStatus.completed,
      rawScore: score,
      reactionTimeMs: result.timeSeconds * 1000,
      errorRate: 1 - score / 100,
      patientId: 'local-practice-profile',
      protocolVersion: 'practice-v1',
      formId: result.task.name,
      languageTag: recordingContext.languageTag,
      accessibilityMode: recordingContext.accessibilityMode,
      attemptCount: 1,
      metadata: {
        'source': 'multicognitive_practice',
        'accessibility_context_note':
            'Saved preferences only; accommodation use is not verified.',
        'time_seconds': result.timeSeconds,
      },
    );
    await (await _getStore()).saveRecord(record);
  }

  Future<List<CognitiveTaskResult>> getLast30Days() async {
    final records = await (await _getStore()).getRecordsSince(
      DateTime.now().toUtc().subtract(const Duration(days: 30)),
    );
    return records
        .where((record) =>
            record.completionStatus == CompletionStatus.completed &&
            record.metadata['source'] == 'multicognitive_practice')
        .map(CognitiveTaskResult.fromRecord)
        .toList(growable: false);
  }

  Future<ReviewDataSnapshot> getReviewSnapshot({
    Duration window = const Duration(days: 365),
  }) async {
    final records = await (await _getStore()).getRecordsSince(
      DateTime.now().toUtc().subtract(window),
    );
    final sleep = <SleepEntry>[];
    final walking = <WalkEntry>[];
    final moods = <MoodEntry>[];
    final cognitive = <CognitiveTaskResult>[];
    final chats = <ChatEntry>[];
    final voices = <VoiceNote>[];
    final functions = <FunctionalEntry>[];
    final plans = <PreventionPlanEntry>[];

    for (final record in records) {
      switch (record.metadata['source']) {
        case 'sleep_entry':
          sleep.add(SleepEntry(
            date: record.timestamp,
            hours: (record.metadata['hours'] as num?)?.toDouble() ?? 0,
            quality: record.metadata['quality'] as String? ?? '',
          ));
        case 'walk_entry':
          walking.add(WalkEntry(
            date: record.timestamp,
            steps: record.metadata['steps'] as int? ?? 0,
          ));
        case 'mood_entry':
          moods.add(MoodEntry(
            date: record.timestamp,
            score: record.metadata['score'] as int? ?? 0,
            note: record.metadata['note'] as String? ?? '',
          ));
        case 'multicognitive_practice':
          if (record.completionStatus == CompletionStatus.completed) {
            cognitive.add(CognitiveTaskResult.fromRecord(record));
          }
        case 'chat_entry':
          chats.add(ChatEntry(
            date: record.timestamp,
            message: record.metadata['message'] as String? ?? '',
            tone: ChatTone.values.firstWhere(
              (tone) => tone.name == record.metadata['tone'],
              orElse: () => ChatTone.neutral,
            ),
            role: record.metadata['role'] as String? ?? 'user',
          ));
        case 'voice_note':
          voices.add(VoiceNote(
            date: record.timestamp,
            durationSeconds: record.metadata['duration_seconds'] as int? ??
                record.reactionTimeMs ~/ 1000,
            speechRate: record.metadata['speech_rate'] as String? ?? 'Normal',
            pauses: record.metadata['pauses'] as String? ?? 'Few',
            energy: record.metadata['energy'] as String? ?? 'Steady',
            toneWords: (record.metadata['tone_words'] as List? ?? const [])
                .whereType<String>()
                .toList(growable: false),
            transcript: record.metadata['transcript'] as String? ?? '',
            wellbeingSignal:
                record.metadata['wellbeing_signal'] as String? ?? 'Steady',
          ));
        case 'functional_entry':
          functions.add(FunctionalEntry(
            date: record.timestamp,
            supportLevel: record.metadata['support_level'] as int? ?? 1,
          ));
        case 'prevention_plan':
          plans.add(PreventionPlanEntry(
            date: record.timestamp,
            actions: (record.metadata['actions'] as List? ?? const [])
                .whereType<String>()
                .toList(growable: false),
          ));
      }
    }

    int byDate<T>(T left, T right, DateTime Function(T) dateOf) =>
        dateOf(left).compareTo(dateOf(right));
    sleep.sort((left, right) => byDate(left, right, (entry) => entry.date));
    walking.sort((left, right) => byDate(left, right, (entry) => entry.date));
    moods.sort((left, right) => byDate(left, right, (entry) => entry.date));
    cognitive.sort((left, right) => byDate(left, right, (entry) => entry.date));
    chats.sort((left, right) => byDate(left, right, (entry) => entry.date));
    voices.sort((left, right) => byDate(left, right, (entry) => entry.date));
    functions.sort((left, right) => byDate(left, right, (entry) => entry.date));
    plans.sort((left, right) => byDate(left, right, (entry) => entry.date));

    final changeTracker = const CognitiveLongitudinalTracker();
    final cognitiveChanges = [
      for (final taskType in [
        CognitiveTaskType.memory,
        CognitiveTaskType.attention,
        CognitiveTaskType.flexibleThinking,
      ])
        changeTracker.summarize(
          records,
          taskType: taskType,
        ),
    ];

    return ReviewDataSnapshot(
      sleepEntries: List.unmodifiable(sleep),
      walkEntries: List.unmodifiable(walking),
      moodEntries: List.unmodifiable(moods),
      cognitiveEntries: List.unmodifiable(cognitive),
      chatEntries: List.unmodifiable(chats),
      voiceNotes: List.unmodifiable(voices),
      functionalEntries: List.unmodifiable(functions),
      preventionPlans: List.unmodifiable(plans),
      cognitiveChanges: List.unmodifiable(cognitiveChanges),
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _store = null;
    _storeOpening = null;
  }

  Future<void> deleteLocalProfileData() async {
    await (await _getStore()).deleteRecordsForPatient('local-practice-profile');
  }
}
