import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:health_companion/models/health_entries.dart';
import 'package:health_companion/services/health_entry_repository.dart';

void main() {
  late Box<MoodEntry> moodBox;
  late HealthEntryRepository<MoodEntry> moods;
  late Box<DailyFunctionEntry> functionBox;
  late HealthEntryRepository<DailyFunctionEntry> functions;
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('basira_hive_test_');
    Hive.init(hiveDirectory.path);
    if (!Hive.isAdapterRegistered(30)) Hive.registerAdapter(MoodEntryAdapter());
    if (!Hive.isAdapterRegistered(31)) {
      Hive.registerAdapter(DailyFunctionEntryAdapter());
    }
    moodBox = await Hive.openBox<MoodEntry>('test_moods');
    functionBox = await Hive.openBox<DailyFunctionEntry>('test_functions');
    await moodBox.clear();
    await functionBox.clear();
    moods = HealthEntryRepository(moodBox);
    functions = HealthEntryRepository(functionBox);
  });

  tearDown(() async {
    await moodBox.close();
    await functionBox.close();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('persists DateTime and formats local timestamp as requested', () async {
    final timestamp = DateTime(2026, 11, 10, 9, 5);
    await moods.addEntry(MoodEntry(
      id: 'mood-1',
      mood: 'happy',
      timestamp: timestamp,
      note: 'Feeling well',
    ));

    final restored = moodBox.get('mood-1')!;
    expect(restored.timestamp, timestamp);
    expect(
        formatHealthEntryTimestamp(restored.timestamp), '10/11/2026, 09:05 AM');
  });

  test('returns records newest first and filters to the last seven days',
      () async {
    final now = DateTime(2026, 11, 10, 12);
    for (final (id, mood, timestamp) in [
      ('old', 'tired', now.subtract(const Duration(days: 8))),
      ('newer', 'neutral', now.subtract(const Duration(hours: 2))),
      ('newest', 'happy', now),
    ]) {
      await moods.addEntry(MoodEntry(id: id, mood: mood, timestamp: timestamp));
    }

    expect(moods.getAllSortedNewestFirst().map((entry) => entry.id),
        ['newest', 'newer', 'old']);
    expect(moods.getLast7Days(now: now).map((entry) => entry.id),
        ['newest', 'newer']);
  });

  test('returns category distributions for the selected records', () async {
    final now = DateTime(2026, 11, 10);
    await functions.addEntry(DailyFunctionEntry(
      id: 'eat-1',
      category: 'eating',
      value: 3,
      timestamp: now,
    ));
    await functions.addEntry(DailyFunctionEntry(
      id: 'eat-2',
      category: 'eating',
      value: 4,
      timestamp: now,
    ));
    await functions.addEntry(DailyFunctionEntry(
      id: 'walk-1',
      category: 'walking',
      value: 2,
      timestamp: now,
    ));

    expect(functions.getDistribution(now: now), {'eating': 2, 'walking': 1});
  });

  test('rejects invalid domain values', () {
    expect(
      () => MoodEntry(id: 'bad-mood', mood: 'sad', timestamp: DateTime.now()),
      throwsArgumentError,
    );
    expect(
      () => DailyFunctionEntry(
        id: 'bad-value',
        category: 'walking',
        value: 6,
        timestamp: DateTime.now(),
      ),
      throwsRangeError,
    );
    expect(
      () => CognitiveEntry(
        id: 'bad-score',
        score: 101,
        totalQuestions: 5,
        timestamp: DateTime.now(),
      ),
      throwsRangeError,
    );
  });
}
