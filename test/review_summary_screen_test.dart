import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:health_companion/models/health_entries.dart';
import 'package:health_companion/screens/review_summary_screen.dart';
import 'package:health_companion/services/health_entry_repository.dart';
import 'package:health_companion/widgets/basira_bottom_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late Box<MoodEntry> moods;
  late Box<DailyFunctionEntry> dailyFunctions;
  late Box<CognitiveEntry> cognitive;
  late Box<LifestyleEntry> lifestyle;
  late Box<ChatToneEntry> chatTones;
  late HealthEntryRepositories repositories;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('summary_test_');
    Hive.init(hiveDirectory.path);
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
    moods = await Hive.openBox<MoodEntry>('summary_moods');
    dailyFunctions =
        await Hive.openBox<DailyFunctionEntry>('summary_daily_functions');
    cognitive = await Hive.openBox<CognitiveEntry>('summary_cognitive');
    lifestyle = await Hive.openBox<LifestyleEntry>('summary_lifestyle');
    chatTones = await Hive.openBox<ChatToneEntry>('summary_chat_tones');
    repositories = HealthEntryRepositories.fromBoxes(
      moods: moods,
      dailyFunctions: dailyFunctions,
      cognitive: cognitive,
      lifestyle: lifestyle,
      chatTones: chatTones,
    );
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('summary uses empty states and preserves app navigation',
      (tester) async {
    await _pumpSummary(tester, const Size(360, 800), repositories);

    expect(find.text('Your health summary'), findsOneWidget);
    expect(find.text('Your data stays on this device. Works offline.'),
        findsOneWidget);
    expect(find.text('No data yet'), findsNWidgets(6));
    expect(find.text('Mood trend'), findsOneWidget);
    expect(find.text('Mood distribution'), findsOneWidget);
    expect(find.byType(BasiraBottomNavigation), findsOneWidget);
  });

  testWidgets('summary cards follow 1, 2, and 3 column breakpoints',
      (tester) async {
    const viewports = [
      (size: Size(360, 800), expectedCardWidth: 328.0),
      (size: Size(768, 1024), expectedCardWidth: 362.0),
      (size: Size(1280, 800), expectedCardWidth: 408.0),
    ];

    for (final viewport in viewports) {
      await _pumpSummary(tester, viewport.size, repositories);
      final card =
          tester.getSize(find.byKey(const ValueKey('summary-card-Mood trend')));
      expect(tester.takeException(), isNull,
          reason: 'Unexpected layout exception at ${viewport.size}');
      expect(
        card.width,
        closeTo(viewport.expectedCardWidth, 1),
        reason: 'Unexpected card width at ${viewport.size}',
      );
    }
  });
}

Future<void> _pumpSummary(
  WidgetTester tester,
  Size size,
  HealthEntryRepositories repositories,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      home: ReviewSummaryScreen(
        repositories: repositories,
        chatEntriesLoader: () async => const [],
        cognitiveEntriesLoader: () async => const [],
      ),
    ),
  );

  // Pump bounded frames instead of pumpAndSettle: indeterminate progress
  // indicators and chart animations may continually schedule additional frames.
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
  fail('Summary loading did not finish within the bounded test pumps.');
}
