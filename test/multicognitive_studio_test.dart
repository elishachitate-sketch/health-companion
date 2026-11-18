import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_companion/screens/multicognitive_studio_screen.dart';

void main() {
  testWidgets('piano practice reveals and accepts a note sequence',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(const MaterialApp(home: MulticognitiveStudioScreen()));

    await tester.tap(find.text('See').first);
    await tester.pumpAndSettle();
    expect(find.text('Do   ·   Mi   ·   Sol   ·   Mi'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    for (final key in [0, 1, 2, 1]) {
      await tester.tap(find.byKey(ValueKey('piano-key-$key')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Sequence complete. You followed the note order.'),
        findsOneWidget);
  });

  testWidgets('activity picker switches to visual attention task',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(const MaterialApp(home: MulticognitiveStudioScreen()));

    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    expect(find.text('Visual attention'), findsOneWidget);
    expect(find.textContaining('Find the circle among the shapes.'),
        findsOneWidget);
    expect(find.text('See'), findsOneWidget);
  });

  testWidgets('rule switching exposes selectable shape and color rules',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(const MaterialApp(home: MulticognitiveStudioScreen()));

    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();
    expect(find.text('Rule switching'), findsOneWidget);
    await tester.tap(find.text('Sort by shape'));
    await tester.pumpAndSettle();
    expect(find.text('Current rule: Shape'), findsOneWidget);
  });

  testWidgets('everyday recall supports See then Remember', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(const MaterialApp(home: MulticognitiveStudioScreen()));

    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See'));
    await tester.pumpAndSettle();
    expect(find.text('Lemon     ·     Key     ·     Garden'), findsOneWidget);
    await tester.tap(find.text('Remember'));
    await tester.pumpAndSettle();
    expect(find.text('What words do you remember?'), findsOneWidget);
    expect(find.byKey(const ValueKey('recallInput')), findsOneWidget);
  });

  testWidgets('studio states practice scores are descriptive, not diagnostic',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(const MaterialApp(home: MulticognitiveStudioScreen()));

    expect(find.text('PRACTICE ACTIVITIES · NOT A DIAGNOSTIC ASSESSMENT'),
        findsOneWidget);
    expect(find.textContaining('Practice scores are saved locally'),
        findsOneWidget);
    expect(find.textContaining('not used to estimate risk'), findsOneWidget);
  });
}
