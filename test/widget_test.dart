import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_companion/localization/app_language.dart';
import 'package:health_companion/main.dart';
import 'package:health_companion/screens/health_chat_screen.dart';
import 'package:health_companion/screens/multicognitive_studio_screen.dart';
import 'package:health_companion/widgets/basira_bottom_navigation.dart';

void main() {
  testWidgets('app loads with the brain health landing screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BasiraApp());

    expect(find.text('basira'), findsOneWidget);
    expect(
        find.text('A clearer picture.\nA healthier tomorrow.'), findsOneWidget);
    expect(find.text('Mood logger'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-checkin-Walking')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-checkin-Food')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-checkin-Sleep')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-checkin-Social')), findsOneWidget);
    expect(find.text('Walking logger'), findsOneWidget);
    expect(find.text('Shona'), findsNothing);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).supportedLocales,
      const [Locale('en'), Locale('ar')],
    );
  });

  testWidgets('clinician walkthrough stays a clearly synthetic demo',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BasiraApp(clinicianMode: true));
    await tester.pumpAndSettle();

    expect(find.text('Synthetic demo · not signed in'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('128'), findsNothing);
    expect(find.textContaining('Adjusted change'), findsNothing);
    await tester.tap(find.text('Browse fictional scenarios'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic scenario list'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Proposed visit workflow · 12 stages · not executed'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Proposed visit workflow · 12 stages · not executed'),
        findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Simulate review action'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate review action'));
    await tester.pumpAndSettle();
    expect(find.text('Record a demo-only action?'), findsOneWidget);
    await tester.tap(find.text('Record demo action'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'Demo action recorded locally · no real review or care action occurred.'),
        findsOneWidget);
    expect(find.text('Clinician review recorded'), findsNothing);
  });

  testWidgets('practice studio is reachable from the overview', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BasiraApp());

    await tester.tap(find.text('Overview').last);
    await tester.pumpAndSettle();
    expect(
        find.text('Explore synthetic clinician review demo'), findsOneWidget);
    await tester.tap(find.text('Try a practice activity'));
    await tester.pumpAndSettle();

    expect(
        find.text('PRACTICE COACHING · MULTICOGNITIVE STUDIO'), findsOneWidget);
    expect(find.text('Practice at your pace.'), findsOneWidget);
    expect(find.byType(BasiraBottomNavigation).hitTestable(), findsOneWidget);
  });

  testWidgets('bottom navigation opens Studio, direct Chat, and Profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BasiraApp());
    await tester.pumpAndSettle();

    expect(find.text('Studio'), findsOneWidget);
    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();
    expect(find.byType(MulticognitiveStudioScreen), findsOneWidget);
    expect(find.text('Practice at your pace.'), findsOneWidget);

    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    expect(find.byType(HealthChatScreen), findsOneWidget);
    expect(find.text('Basira AI'), findsOneWidget);
    expect(find.text('Open Basira AI chat'), findsNothing);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('PROFILE · CONTEXT'), findsOneWidget);
  });

  testWidgets('health summary home tile opens saved summary', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BasiraApp());
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(const ValueKey('home-topic-Health Summary')));
    await tester.tap(find.byKey(const ValueKey('home-topic-Health Summary')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Your health summary'), findsOneWidget);
  });

  testWidgets('brain exercises home tile opens practice with one nav bar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BasiraApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(
        find.byKey(const ValueKey('home-topic-Brain Exercises')));
    await tester.tap(find.byKey(const ValueKey('home-topic-Brain Exercises')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(MulticognitiveStudioScreen), findsOneWidget);
    expect(find.text('Practice at your pace.'), findsOneWidget);
    expect(find.byType(BasiraBottomNavigation).hitTestable(), findsOneWidget);
  });

  testWidgets('sleep home tile opens the useful Plan screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BasiraApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('home-topic-Sleep')));
    await tester.tap(find.byKey(const ValueKey('home-topic-Sleep')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('MY PLAN · CHECK-INS'), findsOneWidget);
    expect(find.text('Sleep logger'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Daily function check-in'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Daily function check-in'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mood check-in'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('View mood trend & distribution'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mood check-in'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Food & eating'), findsOneWidget);
    expect(find.text('View mood trend & distribution'), findsOneWidget);
  });

  testWidgets('language and comfort controls save the selected preferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => AppLanguage.setLanguage('en'));
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const BasiraApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('العربية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('appLanguage'), 'ar');
    expect(preferences.getString('consent_profile_language'), 'ar');
    expect(preferences.getBool('comfort_vision_support'), isFalse);
    expect(find.text('صورة أوضح.\nوغد أكثر صحة.'), findsOneWidget);
    expect(
        find.text('A clearer picture.\nA healthier tomorrow.'), findsNothing);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale?.languageCode,
      'ar',
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.rtl,
      ),
      findsWidgets,
    );

    await AppLanguage.setLanguage('en');
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.ltr,
      ),
      findsWidgets,
    );

    await AppLanguage.setLanguage('ar');
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: HealthChatScreen()));
    await tester.pumpAndSettle();
    expect(find.text('متابعة قصيرة'), findsOneWidget);
    expect(find.text('اكتب رسالة'), findsOneWidget);
  });
}
