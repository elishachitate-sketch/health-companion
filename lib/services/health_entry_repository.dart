import 'dart:convert';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/health_entries.dart';

typedef HealthEntryDistribution = Map<String, int>;

class HealthEntryRepository<T extends TimestampedHealthEntry> {
  HealthEntryRepository(this._box);

  final Box<T> _box;

  Future<void> addEntry(T entry) async {
    await _box.put(entry.id, entry);
  }

  List<T> getAllSortedNewestFirst() => _sortNewestFirst(_box.values);

  List<T> getLast7Days({DateTime? now}) {
    final current = now ?? DateTime.now();
    final cutoff = current.subtract(const Duration(days: 7));
    return _sortNewestFirst(
      _box.values.where((entry) =>
          !entry.timestamp.isBefore(cutoff) &&
          !entry.timestamp.isAfter(current)),
    );
  }

  HealthEntryDistribution getDistribution({
    Iterable<T>? entries,
    DateTime? now,
  }) {
    final source = entries ?? getLast7Days(now: now);
    final result = <String, int>{};
    for (final entry in source) {
      result.update(
        entry.distributionKey,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return Map.unmodifiable(result);
  }

  List<T> _sortNewestFirst(Iterable<T> entries) => entries.toList()
    ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
}

class HealthEntryRepositories {
  factory HealthEntryRepositories.fromBoxes({
    required Box<MoodEntry> moods,
    required Box<DailyFunctionEntry> dailyFunctions,
    required Box<CognitiveEntry> cognitive,
    required Box<LifestyleEntry> lifestyle,
    required Box<ChatToneEntry> chatTones,
  }) =>
      HealthEntryRepositories._(
        moods: HealthEntryRepository(moods),
        dailyFunctions: HealthEntryRepository(dailyFunctions),
        cognitive: HealthEntryRepository(cognitive),
        lifestyle: HealthEntryRepository(lifestyle),
        chatTones: HealthEntryRepository(chatTones),
      );

  HealthEntryRepositories._({
    required this.moods,
    required this.dailyFunctions,
    required this.cognitive,
    required this.lifestyle,
    required this.chatTones,
  });

  static const String moodBoxName = 'health_mood_entries';
  static const String dailyFunctionBoxName = 'health_daily_function_entries';
  static const String cognitiveBoxName = 'health_cognitive_entries';
  static const String lifestyleBoxName = 'health_lifestyle_entries';
  static const String chatToneBoxName = 'health_chat_tone_entries';

  static HealthEntryRepositories? _instance;

  final HealthEntryRepository<MoodEntry> moods;
  final HealthEntryRepository<DailyFunctionEntry> dailyFunctions;
  final HealthEntryRepository<CognitiveEntry> cognitive;
  final HealthEntryRepository<LifestyleEntry> lifestyle;
  final HealthEntryRepository<ChatToneEntry> chatTones;

  static HealthEntryRepositories get instance =>
      _instance ??
      (throw StateError('Call HealthEntryRepositories.initialize() first.'));

  static Future<HealthEntryRepositories> initialize() async {
    await Hive.initFlutter();
    final cipher = await _openCipher();
    if (!Hive.isAdapterRegistered(30)) Hive.registerAdapter(MoodEntryAdapter());
    if (!Hive.isAdapterRegistered(31)) {
      Hive.registerAdapter(DailyFunctionEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(32)) {
      Hive.registerAdapter(CognitiveEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(33)) {
      Hive.registerAdapter(LifestyleEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(34)) {
      Hive.registerAdapter(ChatToneEntryAdapter());
    }

    final boxes = await Future.wait([
      Hive.openBox<MoodEntry>(moodBoxName, encryptionCipher: cipher),
      Hive.openBox<DailyFunctionEntry>(dailyFunctionBoxName,
          encryptionCipher: cipher),
      Hive.openBox<CognitiveEntry>(cognitiveBoxName, encryptionCipher: cipher),
      Hive.openBox<LifestyleEntry>(lifestyleBoxName, encryptionCipher: cipher),
      Hive.openBox<ChatToneEntry>(chatToneBoxName, encryptionCipher: cipher),
    ]);

    return _instance = HealthEntryRepositories._(
      moods: HealthEntryRepository(boxes[0] as Box<MoodEntry>),
      dailyFunctions:
          HealthEntryRepository(boxes[1] as Box<DailyFunctionEntry>),
      cognitive: HealthEntryRepository(boxes[2] as Box<CognitiveEntry>),
      lifestyle: HealthEntryRepository(boxes[3] as Box<LifestyleEntry>),
      chatTones: HealthEntryRepository(boxes[4] as Box<ChatToneEntry>),
    );
  }

  static Future<HiveAesCipher> _openCipher() async {
    const secureStorage = FlutterSecureStorage();
    const storageKey = 'health_entry_hive_encryption_key_v1';

    try {
      final encodedKey = await secureStorage.read(key: storageKey);
      final key = encodedKey == null
          ? List<int>.generate(32, (_) => Random.secure().nextInt(256))
          : base64Url.decode(base64Url.normalize(encodedKey));
      if (key.length != 32) {
        throw StateError('The local health-data encryption key is invalid.');
      }
      if (encodedKey == null) {
        await secureStorage.write(
          key: storageKey,
          value: base64Url.encode(key),
        );
      }
      return HiveAesCipher(key);
    } on Exception {
      final fallbackKey =
          List<int>.generate(32, (_) => Random.secure().nextInt(256));
      return HiveAesCipher(fallbackKey);
    }
  }

  static Future<void> close() async {
    _instance = null;
    await Hive.close();
  }
}
