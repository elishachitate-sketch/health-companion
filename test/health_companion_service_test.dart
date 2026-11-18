import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_companion/services/health_companion_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sendMessage includes the canonical selected app language', () async {
    Map<String, dynamic>? sentBody;
    final service = HealthCompanionService(
      workerUrl: 'https://example.test/chat',
      client: MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'reply': 'Hello there.'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(service.close);

    await service.sendMessage('hello', locale: 'ar-SA');

    expect(sentBody?['appLanguage'], 'ar');
    expect(sentBody?['locale'], 'ar-SA');
  });

  test('sendMessage strips pretty-printed metadata from the visible reply',
      () async {
    final service = HealthCompanionService(
      workerUrl: 'https://example.test/chat',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'reply': '''I hear this has been challenging.\n\n{
  "safety_flag": false,
  "suggested_action": "self_care",
  "confidence": "medium"
}''',
              'safetyFlagRaised': false,
              'suggestedAction': 'self_care',
              'confidence': 'medium',
            }),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    addTearDown(service.close);

    final response = await service.sendMessage('I feel worried');

    expect(response.reply, 'I hear this has been challenging.');
  });

  test('sendMessage removes a fenced JSON block after the reply text',
      () async {
    final service = HealthCompanionService(
      workerUrl: 'https://example.test/chat',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'reply': '''I hear you. Let's take this one step at a time.

```json
{
  "saftey_flag": false,
  "suggested_action": "none"
}
```''',
              'safetyFlagRaised': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    addTearDown(service.close);

    final response = await service.sendMessage('I feel worried');

    expect(response.reply, "I hear you. Let's take this one step at a time.");
    expect(response.reply, isNot(contains('```')));
    expect(response.reply, isNot(contains('saftey_flag')));
  });

  test('display sanitizer never returns a metadata-only JSON code block', () {
    final reply = HealthCompanionService.cleanReplyText('''```json
{"saftey_flag":false,"suggested_action":"none"}
```''');

    expect(reply, isEmpty);
    expect(reply, isNot(contains('json')));
  });

  test('display sanitizer keeps only the message before a JSON marker', () {
    final reply = HealthCompanionService.cleanReplyText(
      'I hear you. Let us take one step at a time. JSON: {"tone":"calm"}',
    );

    expect(reply, 'I hear you. Let us take one step at a time.');
  });

  test('sendMessage extracts text when reply is encoded as JSON', () async {
    final service = HealthCompanionService(
      workerUrl: 'https://example.test/chat',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'reply': jsonEncode({
                'reply': 'Let us choose one manageable next step.',
                'safety_flag': false,
              }),
            }),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    addTearDown(service.close);

    final response = await service.sendMessage('What can I do?');

    expect(response.reply, 'Let us choose one manageable next step.');
  });

  test('sendMessage removes Markdown from the visible reply', () async {
    final service = HealthCompanionService(
      workerUrl: 'https://example.test/chat',
      client: MockClient((_) async => http.Response(
            jsonEncode({'reply': '## Hello\n- **Warm** and *short*.'}),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    addTearDown(service.close);

    final response = await service.sendMessage('hello');

    expect(response.reply, 'Hello\nWarm and short.');
  });
}
