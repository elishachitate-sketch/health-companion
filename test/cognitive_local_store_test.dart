import 'package:flutter_test/flutter_test.dart';
import 'package:health_companion/models/cognitive_session_record.dart';
import 'package:health_companion/services/cognitive_local_store.dart';

void main() {
  late CognitiveLocalStore store;

  setUp(() {
    store = CognitiveLocalStore.inMemory();
  });

  CognitiveSessionRecord record({
    required String sessionId,
    required DateTime timestamp,
    String patientId = 'local-practice-profile',
  }) =>
      CognitiveSessionRecord(
        sessionId: sessionId,
        timestamp: timestamp,
        taskType: CognitiveTaskType.memory,
        completionStatus: CompletionStatus.completed,
        rawScore: 0,
        reactionTimeMs: 0,
        errorRate: 0,
        patientId: patientId,
      );

  test('temporary store saves, filters and orders observations', () async {
    final now = DateTime.utc(2026, 11, 10);
    await store.saveRecord(record(
      sessionId: 'later',
      timestamp: now.add(const Duration(hours: 1)),
    ));
    await store.saveRecord(record(
      sessionId: 'earlier',
      timestamp: now,
    ));

    final records = await store.getRecordsSince(now);
    expect(store.isEphemeral, isTrue);
    expect(records.map((entry) => entry.sessionId), ['earlier', 'later']);
    expect(
        (await store.getRecordsSince(now.add(const Duration(minutes: 1))))
            .map((entry) => entry.sessionId),
        ['later']);
  });

  test('temporary store supports sync marking and profile deletion', () async {
    final now = DateTime.utc(2026, 11, 10);
    await store.saveRecord(record(sessionId: 'one', timestamp: now));
    await store.saveRecord(record(
      sessionId: 'other',
      timestamp: now,
      patientId: 'another-profile',
    ));

    await store.markSynced('one');
    expect((await store.getPendingSync()).map((entry) => entry.sessionId),
        ['other']);

    await store.deleteRecordsForPatient('local-practice-profile');
    expect(
        (await store.getRecordsSince(DateTime.utc(2020)))
            .map((entry) => entry.sessionId),
        ['other']);
  });
}
