import 'dart:convert';

import 'package:http/http.dart' as http;

import 'visit_routing_metadata.dart';

class HealthCompanionService {
  static const deployedWorkerUrl =
      'https://kuda-lumi-health-companion.elishachitate.workers.dev';
  static const requestTimeout = Duration(seconds: 60);

  HealthCompanionService({http.Client? client, String? workerUrl})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        workerUrl = workerUrl ??
            const String.fromEnvironment(
              'HEALTH_COMPANION_WORKER_URL',
              defaultValue: deployedWorkerUrl,
            );

  final http.Client _client;
  final String workerUrl;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<HealthCompanionResponse> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
    WellbeingContext? wellbeing,
    WellbeingConsent consent = const WellbeingConsent(),
    String locale = 'en-US',
    String? accessToken,
    String? wellbeingSummary,
  }) async {
    final text = message.trim();
    if (text.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    final payload = {
      'message': text,
      'history': history,
      if (wellbeing != null) 'wellbeing': wellbeing.toJson(),
      if (wellbeingSummary != null && wellbeingSummary.trim().isNotEmpty)
        'wellbeing_summary': wellbeingSummary.trim(),
      'consent': consent.toJson(),
      'locale': _normalizeLocale(locale),
      'appLanguage': _normalizeLocale(locale) == 'ar-SA' ? 'ar' : 'en',
      'visitRouting':
          VisitRoutingMetadata.fromText(text, source: 'typed_text').toJson(),
      'session_record': {
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'mood': wellbeing?.mood ?? 'unknown',
        'sleep': wellbeing?.sleep ?? 'unknown',
        'energy': wellbeing?.energy ?? 'unknown',
        'focus': wellbeing?.focus ?? 'unknown',
      },
    };

    final result = await _client
        .post(
          Uri.parse(workerUrl),
          headers: {
            'Content-Type': 'application/json',
            if (accessToken != null && accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(requestTimeout);
    if (result.statusCode >= 400) {
      throw Exception(
        'Health companion request failed: ${result.statusCode} ${result.body}',
      );
    }
    final decoded = jsonDecode(result.body);
    if (decoded is! Map) {
      throw const FormatException('The AI returned an invalid response.');
    }
    final data = Map<String, dynamic>.from(decoded);
    final reply = cleanReplyText(data['reply'] ?? data['message'] ?? '');
    if (reply.isEmpty) {
      throw const FormatException(
          'Basira returned no readable text. Please try again.');
    }

    return HealthCompanionResponse(
      reply: reply,
      safetyFlagRaised: data['safetyFlagRaised'] == true,
      suggestedAction: (data['suggestedAction'] ?? 'none').toString(),
      confidence: (data['confidence'] ?? 'low').toString(),
    );
  }

  static String _normalizeLocale(String locale) =>
      locale.toLowerCase().startsWith('ar') ? 'ar-SA' : 'en-US';

  /// Extracts conversational text and removes structured model metadata.
  /// This is also used for streamed replies as a final display-boundary guard.
  static String cleanReplyText(Object value) {
    var text = value is String ? value.trim() : jsonEncode(value).trim();
    for (var attempt = 0; attempt < 4; attempt++) {
      final unfenced = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
      final jsonMarker =
          RegExp(r'\bJSON\s*:', caseSensitive: false).firstMatch(unfenced);
      if (jsonMarker != null) {
        text = unfenced.substring(0, jsonMarker.start).trim();
        break;
      }
      try {
        final decoded = jsonDecode(unfenced);
        if (decoded is Map) {
          final nested = decoded['reply'] ??
              decoded['message'] ??
              decoded['content'] ??
              decoded['response'];
          if (nested != null) {
            text = nested.toString().trim();
            continue;
          }
        }
      } on FormatException {
        // The reply is ordinary prose, or contains a trailing metadata object.
      }

      final trailingObject = _findTrailingMetadata(unfenced);
      if (trailingObject != null) {
        text = unfenced
            .substring(0, trailingObject.$1)
            .replaceFirst(
              RegExp(r'\s*```(?:json)?\s*$', caseSensitive: false),
              '',
            )
            .trim();
        continue;
      }
      text = _removeFencedJson(unfenced);
      break;
    }
    return _stripMarkdown(_removeFencedJson(text)).trim();
  }

  static String _stripMarkdown(String text) => text
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]*\)'),
        (match) => match[1] ?? '',
      )
      .replaceAll(RegExp(r'^[ \t]{0,3}#{1,6}[ \t]+', multiLine: true), '')
      .replaceAll(RegExp(r'^[ \t]*[-*+][ \t]+', multiLine: true), '')
      .replaceAll(RegExp(r'^[ \t]*\d+[.)][ \t]+', multiLine: true), '')
      .replaceAllMapped(
        RegExp(r'\*\*(.*?)\*\*|__(.*?)__'),
        (match) => match[1] ?? match[2] ?? '',
      )
      .replaceAllMapped(
        RegExp(r'(?<!\w)\*([^*\n]+)\*(?!\w)'),
        (match) => match[1] ?? '',
      )
      .replaceAllMapped(
        RegExp(r'(?<!\w)_([^_\n]+)_(?!\w)'),
        (match) => match[1] ?? '',
      );

  static String _removeFencedJson(String text) => text
      .replaceAll(
        RegExp(r'```\s*json\s*[\s\S]*?```', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'```json\s*[\s\S]*$', caseSensitive: false), '')
      .trim();

  static (int, Map<String, dynamic>)? _findTrailingMetadata(String text) {
    final end = text.lastIndexOf('}');
    if (end < 0 || text.substring(end + 1).trim().isNotEmpty) return null;

    for (var start = text.lastIndexOf('{', end); start >= 0; start--) {
      try {
        final value = jsonDecode(text.substring(start, end + 1));
        if (value is Map<String, dynamic> &&
            (value.containsKey('safety_flag') ||
                value.containsKey('saftey_flag') ||
                value.containsKey('suggested_action') ||
                value.containsKey('confidence'))) {
          return (start, value);
        }
      } on FormatException {
        continue;
      }
    }
    return null;
  }
}

class WellbeingContext {
  const WellbeingContext({
    this.memory = 'stable',
    this.focus = 'stable',
    this.dailyTasks = 'normal',
    this.mood = 'okay',
    this.stress = 'moderate',
    this.sleep = 'fair',
    this.energy = 'low',
    this.supportNeed = 'self_help',
  });

  final String memory;
  final String focus;
  final String dailyTasks;
  final String mood;
  final String stress;
  final String sleep;
  final String energy;
  final String supportNeed;

  Map<String, String> toJson() => {
        'memory': memory,
        'focus': focus,
        'dailyTasks': dailyTasks,
        'mood': mood,
        'stress': stress,
        'sleep': sleep,
        'energy': energy,
        'supportNeed': supportNeed,
      };
}

class WellbeingConsent {
  const WellbeingConsent({
    this.crisisEscalation = true,
    this.shareForCare = false,
  });

  final bool crisisEscalation;
  final bool shareForCare;

  Map<String, bool> toJson() => {
        'crisisEscalation': crisisEscalation,
        'shareForCare': shareForCare,
      };
}

class HealthCompanionResponse {
  const HealthCompanionResponse({
    required this.reply,
    required this.safetyFlagRaised,
    required this.suggestedAction,
    required this.confidence,
  });

  final String reply;
  final bool safetyFlagRaised;
  final String suggestedAction;
  final String confidence;
}
