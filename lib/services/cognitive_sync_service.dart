import '../models/cognitive_session_record.dart';
import 'cognitive_local_store.dart';
import 'clinical_log_api_client.dart';

class CognitiveSyncService {
  CognitiveSyncService({
    required this.localStore,
    required this.apiClient,
  });

  final CognitiveLocalStore localStore;
  final ClinicalLogApiClient apiClient;

  Future<void> saveAndQueue(CognitiveSessionRecord record) async {
    try {
      await localStore.saveRecord(record);
    } catch (error) {
      throw Exception('Failed to save cognitive record locally: $error');
    }
  }

  Future<void> syncPendingRecords() async {
    try {
      final pending = await localStore.getPendingSync();
      if (pending.isEmpty) {
        return;
      }

      await apiClient.syncRecords(pending);

      for (final record in pending) {
        await localStore.markSynced(record.sessionId);
      }
    } catch (error) {
      throw Exception('Failed to sync cognitive logs: $error');
    }
  }
}
