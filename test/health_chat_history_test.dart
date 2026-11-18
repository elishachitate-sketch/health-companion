import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_companion/services/health_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = DataService.instance;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('local chat history retains user and assistant messages with roles',
      () async {
    final now = DateTime.now().toUtc();
    await data.deleteLocalProfileData();

    await data.saveChatEntry(ChatEntry(
      date: now,
      message: 'I feel worried.',
      tone: ChatTone.worried,
    ));
    await data.saveChatEntry(ChatEntry(
      date: now.add(const Duration(milliseconds: 1)),
      message: 'I hear you. Let us take one step at a time.',
      tone: ChatTone.neutral,
      role: 'assistant',
    ));

    final history = await data.getChatEntriesSince(
      now.subtract(const Duration(seconds: 1)),
    );
    expect(history.map((entry) => entry.role), ['user', 'assistant']);
    expect(history.map((entry) => entry.message), [
      'I feel worried.',
      'I hear you. Let us take one step at a time.',
    ]);
    expect(history.map((entry) => entry.tone), [
      ChatTone.worried,
      ChatTone.neutral,
    ]);

    await data.deleteLocalProfileData();
  });
}
