import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_companion/screens/health_chat_screen.dart';
import 'package:health_companion/services/voice_companion_service.dart';

void main() {
  test('voice locales use Dubai Arabic and US English', () {
    expect(VoiceCompanionService.localeForLanguage('ar'), 'ar-AE');
    expect(VoiceCompanionService.localeForLanguage('ar-SA'), 'ar-AE');
    expect(VoiceCompanionService.localeForLanguage('en'), 'en-US');
  });

  testWidgets('voice processing requires explicit consent', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HealthChatScreen()));
    await tester.pumpAndSettle();

    expect(find.text('A brief check-in'), findsOneWidget);
    expect(
        find.text('Allow microphone and speech transcription'), findsNothing);
    await tester.tap(find.text('A brief check-in'));
    await tester.pumpAndSettle();
    expect(
        find.text('Allow microphone and speech transcription'), findsOneWidget);
    expect(find.text('Include speech timing observations'), findsOneWidget);
  });

  testWidgets('consent language loader is accepted by the chat integration',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: HealthChatScreen(
        consentLanguageLoader: () async => 'ar',
        accessTokenProvider: () async => 'test-only-token',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Basira AI'), findsOneWidget);
  });
}
