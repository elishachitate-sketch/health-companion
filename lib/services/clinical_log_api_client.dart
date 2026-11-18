import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cognitive_session_record.dart';

class ClinicalLogApiClient {
  ClinicalLogApiClient({
    required String baseUrl,
    required this.authTokenProvider,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final Future<String> Function() authTokenProvider;
  final http.Client _httpClient;

  Uri get endpoint => Uri.parse('$_baseUrl/api/v1/clinical/logs');

  Future<void> syncRecords(List<CognitiveSessionRecord> records) async {
    if (records.isEmpty) {
      return;
    }

    final token = await authTokenProvider();

    final payload = {
      'records': records.map((record) {
        return {
          'session_id': record.sessionId,
          'timestamp': record.timestamp.toUtc().toIso8601String(),
          'task_type': record.taskType.name,
          'completion_status': record.completionStatus.name,
          'raw_score': record.rawScore,
          'reaction_time_ms': record.reactionTimeMs,
          'error_rate': record.errorRate,
          'patient_id': record.patientId,
          'protocol_version': record.protocolVersion,
          'form_id': record.formId,
          'language_tag': record.languageTag,
          'accessibility_mode': record.accessibilityMode,
          'attempt_count': record.attemptCount,
          'metadata': record.metadata,
        };
      }).toList(),
    };

    final response = await _httpClient
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'X-App-Version': '1.0.0',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    if (response.statusCode == 401) {
      throw Exception('Unauthorized access to clinical logs.');
    }

    if (response.statusCode >= 500) {
      throw Exception('Clinical log server error. Retry later.');
    }

    throw Exception(
      'Failed to sync cognitive logs: ${response.statusCode} ${response.body}',
    );
  }
}
