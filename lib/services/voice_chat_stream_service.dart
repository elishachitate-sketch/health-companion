import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_stream_player/audio_stream_player.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'visit_routing_metadata.dart';

/// Events emitted by the authenticated server-side audio/agent gateway.
sealed class VoiceChatEvent {
  const VoiceChatEvent();
}

class VoiceTranscriptEvent extends VoiceChatEvent {
  const VoiceTranscriptEvent(this.text, {required this.isFinal});
  final String text;
  final bool isFinal;
}

class VoiceReplyTextEvent extends VoiceChatEvent {
  const VoiceReplyTextEvent(this.text);
  final String text;
}

class VoiceReplyAudioEvent extends VoiceChatEvent {
  const VoiceReplyAudioEvent(
    this.bytes, {
    this.contentType = 'audio/pcm;format=s16le;rate=24000;channels=1',
  });
  final Uint8List bytes;
  final String contentType;
}

class VoiceTurnCompletedEvent extends VoiceChatEvent {
  const VoiceTurnCompletedEvent({this.audioPlayed = false});
  final bool audioPlayed;
}

class VoiceAssistantInterruptedEvent extends VoiceChatEvent {
  const VoiceAssistantInterruptedEvent();
}

class VoiceSpeechObservationEvent extends VoiceChatEvent {
  const VoiceSpeechObservationEvent(this.observations);
  final Map<String, Object?> observations;
}

class VoiceChatErrorEvent extends VoiceChatEvent {
  const VoiceChatErrorEvent(this.message);
  final String message;
}

/// Streams microphone chunks and text through a first-party authenticated
/// gateway; provider credentials never belong in the mobile application.
///
/// Wire the server to the Visit Coordination Agent. Audio transport uses 16 kHz
/// mono PCM16 chunks and an explicit end-of-turn message. The backend should
/// provide transcripts and any speech-pattern measurements only with consent,
/// purpose limits, and validated policy. This client does not infer a diagnosis.
class VoiceChatStreamService {
  VoiceChatStreamService({
    required this.gatewayUri,
    required this.accessTokenProvider,
    required this.consentGranted,
    AudioRecorder? recorder,
    Duration connectTimeout = const Duration(seconds: 8),
  })  : _recorder = recorder ?? AudioRecorder(),
        _connectTimeout = connectTimeout;

  final Uri gatewayUri;
  final Future<String> Function() accessTokenProvider;
  final bool Function() consentGranted;
  final AudioRecorder _recorder;
  final Duration _connectTimeout;
  final StreamController<VoiceChatEvent> _events =
      StreamController<VoiceChatEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<dynamic>? _socketSubscription;
  AudioStreamPlayer? _audioPlayer;
  Completer<void>? _authCompleter;
  String _locale = 'en-US';
  bool _closed = false;
  bool _capturing = false;
  bool _assistantSpeaking = false;
  bool _assistantAudioReceived = false;
  bool _suppressAssistantAudio = false;
  int _sequence = 0;

  Stream<VoiceChatEvent> get events => _events.stream;
  bool get isCapturing => _capturing;
  bool get isAssistantSpeaking => _assistantSpeaking;

  /// Requests microphone access through the operating system if needed.
  Future<bool> requestMicrophonePermission() => _recorder.hasPermission();

  /// Load locale from the Consent & Access profile response; do not infer it
  /// from ethnicity, name, or accent.
  Future<void> setProfileLanguage(String languageCode) async {
    final language = languageCode.toLowerCase();
    if (!language.startsWith('en') && !language.startsWith('ar')) {
      throw ArgumentError.value(languageCode, 'languageCode',
          'Only Arabic and English are supported.');
    }
    _locale = language.startsWith('ar') ? 'ar-AE' : 'en-US';
    if (_channel != null) {
      await _sendJson({
        'type': 'session.update',
        'locale': _locale,
        'appLanguage': _appLanguage,
        'languagePolicy': _languagePolicy,
      });
    }
  }

  String get _appLanguage => _locale.startsWith('ar') ? 'ar' : 'en';

  String get _languagePolicy =>
      'The selected app language is ${_appLanguage == 'ar' ? 'Arabic' : 'English'}. Detect the language of each latest user utterance and reply only in that language; if it is unclear, use the selected app language. Transcribe speech in the language spoken; never translate Arabic speech into English. Never mix languages in one reply. For Arabic, use Gulf-friendly Modern Standard Arabic suitable for Dubai, not Egyptian dialect. Use plain text only, with no Markdown, and reply warmly in 2–3 short sentences.';

  String _languageInstructionFor(String message) {
    final arabicCount = RegExp(r'[\u0600-\u06ff]').allMatches(message).length;
    final latinCount = RegExp(r'[A-Za-z]').allMatches(message).length;
    final replyLanguage = arabicCount > 0 && arabicCount >= latinCount
        ? 'Arabic'
        : latinCount > 0
            ? 'English'
            : _appLanguage == 'ar'
                ? 'Arabic'
                : 'English';
    final selected = _appLanguage == 'ar' ? 'Arabic' : 'English';
    final alternate = selected == 'Arabic' ? 'English' : 'Arabic';
    return 'User\'s selected app language is: $selected. You MUST reply ONLY in $selected. Never reply in $alternate unless user types in $alternate. The latest user message is in $replyLanguage; reply ONLY in $replyLanguage for this turn. Never mix languages in one reply.';
  }

  Future<void> connect({required String caseId}) async {
    _ensureOpen();
    if (_channel != null) return;
    if (!consentGranted()) {
      throw StateError('Explicit voice processing consent is required.');
    }
    if (gatewayUri.scheme != 'wss') {
      throw ArgumentError.value(gatewayUri, 'gatewayUri',
          'Voice gateway must use secure wss:// transport.');
    }
    final token = await accessTokenProvider();
    if (token.trim().isEmpty)
      throw StateError('An authenticated access token is required.');
    final channel = WebSocketChannel.connect(
      gatewayUri,
      protocols: ['basira-voice-v1'],
    );
    _channel = channel;
    try {
      await channel.ready.timeout(_connectTimeout);
    } catch (_) {
      _channel = null;
      await channel.sink.close();
      rethrow;
    }
    _socketSubscription = channel.stream.listen(
      _handleServerMessage,
      onError: (Object error, StackTrace stack) {
        _events.add(VoiceChatErrorEvent('Voice connection was interrupted.'));
      },
      onDone: () {
        _assistantSpeaking = false;
        _capturing = false;
      },
      cancelOnError: false,
    );
    _authCompleter = Completer<void>();
    await _sendJson({
      'type': 'auth.authenticate',
      'accessToken': token,
      'audience': 'basira-voice-gateway',
    });
    try {
      await _authCompleter!.future.timeout(_connectTimeout);
    } catch (_) {
      await channel.sink.close(1008, 'authentication failed');
      _channel = null;
      rethrow;
    } finally {
      _authCompleter = null;
    }
    await _sendJson({
      'type': 'session.start',
      'schemaVersion': 'basira-voice-session-v1',
      'caseId': caseId,
      'locale': _locale,
      'appLanguage': _appLanguage,
      'languagePolicy': _languagePolicy,
      'audio': {'encoding': 'pcm_s16le', 'sampleRateHz': 16000, 'channels': 1},
      'modalities': ['text', 'audio'],
      'turnDetection': 'server_vad',
      'privacy': {'rawAudioRetention': false, 'transcriptionConsent': true},
    });
  }

  Future<void> sendText(
    String text, {
    required String caseId,
    List<Map<String, String>> history = const [],
  }) async {
    _ensureReady();
    if (!consentGranted())
      throw StateError('Explicit processing consent is required.');
    final message = text.trim();
    if (message.isEmpty) throw ArgumentError('Message cannot be empty.');
    final routeMetadata =
        VisitRoutingMetadata.fromText(message, source: 'typed_text');
    _suppressAssistantAudio = routeMetadata.urgentHandoff;
    final previousHistory = history.length > 0 &&
            history.last['role'] == 'user' &&
            history.last['content'] == message
        ? history.take(history.length - 1).toList()
        : history;
    await _sendJson({
      'type': 'conversation.item.create',
      'item': {
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': message}
        ],
      },
      'history': previousHistory.length <= 12
          ? previousHistory
          : previousHistory.sublist(previousHistory.length - 12),
      'caseId': caseId,
      'locale': _locale,
      'appLanguage': _appLanguage,
      'languageInstruction': _languageInstructionFor(message),
      'visitRouting': routeMetadata.toJson(),
    });
    await _sendJson({
      'type': 'response.create',
      'modalities': routeMetadata.urgentHandoff ? ['text'] : ['text', 'audio'],
    });
  }

  Future<void> startMicrophone({
    required String caseId,
    bool includeSpeechObservations = false,
  }) async {
    _ensureReady();
    if (!consentGranted())
      throw StateError(
          'Explicit microphone and processing consent is required.');
    if (_capturing) return;
    await interruptAssistant();
    _suppressAssistantAudio = false;
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission)
      throw StateError('Microphone permission was not granted.');
    _sequence = 0;
    _assistantAudioReceived = false;
    await _sendJson({
      'type': 'input_audio_buffer.begin',
      'caseId': caseId,
      'locale': _locale,
      'appLanguage': _appLanguage,
      'languagePolicy': _languagePolicy,
      'audio': {'encoding': 'pcm_s16le', 'sampleRateHz': 16000, 'channels': 1},
      'transcription': {'enabled': true, 'locale': _locale},
      'transcriptionPolicy':
          'Transcribe in the language spoken. Do not translate Arabic speech into English.',
      'speechObservations': includeSpeechObservations
          ? {
              'hesitationTiming': true,
              'pauseTiming': true,
              'speechRate': true,
              'retainRawAudio': false,
            }
          : {'enabled': false, 'retainRawAudio': false},
    });
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      streamBufferSize: 4096,
    ));
    _capturing = true;
    _audioSubscription = stream.listen(
      (chunk) {
        if (_channel == null || !_capturing || chunk.isEmpty) return;
        _channel!.sink.add(Uint8List.fromList(chunk));
        _sequence++;
      },
      onError: (Object error, StackTrace stack) {
        _events.add(VoiceChatErrorEvent('Microphone capture failed.'));
        unawaited(stopMicrophone());
      },
    );
  }

  Future<void> stopMicrophone({
    bool submitTurn = true,
    bool discard = false,
  }) async {
    if (!_capturing) return;
    _capturing = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _recorder.stop();
    if (discard) {
      await interruptAssistant();
      await _sendJson({'type': 'input_audio_buffer.clear'});
      return;
    }
    await _sendJson({
      'type': 'input_audio_buffer.commit',
      'chunkCount': _sequence,
      'finalTurn': true,
    });
    _suppressAssistantAudio = false;
    if (submitTurn) await submitCommittedAudioTurn();
  }

  Future<void> submitCommittedAudioTurn() async {
    _ensureReady();
    if (!consentGranted()) {
      throw StateError('Explicit processing consent is required.');
    }
    await _sendJson({
      'type': 'response.create',
      'modalities': ['text', 'audio'],
    });
  }

  /// Barge-in handler: cancel outgoing audio, stop local playback, and let
  /// microphone capture begin immediately.
  Future<void> interruptAssistant() async {
    if (_assistantSpeaking) {
      await _sendJson(
          {'type': 'response.cancel', 'reason': 'user_interruption'});
      await _sendJson({'type': 'output_audio_buffer.clear'});
    }
    _assistantSpeaking = false;
    _assistantAudioReceived = false;
    _suppressAssistantAudio = true;
    await _audioPlayer?.stop();
  }

  Future<void> markAssistantSpeaking(bool value) async {
    _assistantSpeaking = value;
    if (value) {
      await _sendJson({'type': 'output_audio_buffer.started'});
    }
  }

  Future<void> _handleServerMessage(dynamic raw) async {
    if (raw is! String) return;
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      message = Map<String, dynamic>.from(decoded);
    } on FormatException {
      return;
    }
    switch (message['type']) {
      case 'input_audio_transcription.delta':
        _events.add(VoiceTranscriptEvent((message['delta'] ?? '').toString(),
            isFinal: false));
      case 'input_audio_transcription.completed':
        final text = (message['transcript'] ?? '').toString();
        _events.add(VoiceTranscriptEvent(text, isFinal: true));
        if (text.isNotEmpty) {
          final route =
              VisitRoutingMetadata.fromText(text, source: 'voice_transcript');
          _suppressAssistantAudio = route.urgentHandoff;
          await _sendJson({
            'type': 'visit.routing_hint',
            'metadata': route.toJson(),
          });
        }
      case 'input_audio_buffer.speech_started':
        // Server VAD is the primary barge-in detector while microphone audio
        // continues streaming during assistant playback.
        await interruptAssistant();
        _events.add(const VoiceAssistantInterruptedEvent());
      case 'speech.observations':
        final value = message['observations'];
        if (value is Map) {
          _events.add(VoiceSpeechObservationEvent(
            Map<String, Object?>.from(value),
          ));
        }
      case 'response.audio.delta':
        _assistantSpeaking = true;
        final encoded = message['delta'];
        if (encoded is String && !_suppressAssistantAudio) {
          final bytes = base64Decode(encoded);
          _assistantAudioReceived = true;
          await _feedAudio(bytes);
          _events.add(VoiceReplyAudioEvent(bytes));
        }
      case 'response.audio.done':
        await _audioPlayer?.endOfStream();
      case 'response.done':
        _assistantSpeaking = false;
        _events
            .add(VoiceTurnCompletedEvent(audioPlayed: _assistantAudioReceived));
        _assistantAudioReceived = false;
        _suppressAssistantAudio = false;
      case 'response.text.delta':
      case 'response.output_text.delta':
        _events.add(VoiceReplyTextEvent((message['delta'] ?? '').toString()));
      case 'error':
        _assistantSpeaking = false;
        final error = VoiceChatErrorEvent(
          (message['message'] ?? 'Voice service error').toString(),
        );
        _events.add(error);
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.completeError(StateError(error.message));
        }
      case 'auth.accepted':
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.complete();
        }
      case 'auth.rejected':
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.completeError(
            StateError(
              (message['message'] ?? 'Authentication rejected').toString(),
            ),
          );
        }
    }
  }

  Future<void> _feedAudio(Uint8List bytes) async {
    _audioPlayer ??= await AudioStreamPlayer.create(
      sampleRate: 24000,
      channels: 1,
      format: PcmFormat.s16le,
    );
    await _audioPlayer!.feed(bytes);
    if (_audioPlayer!.state != PlayerState.playing) {
      await _audioPlayer!.play();
    }
  }

  Future<void> _sendJson(Map<String, Object?> value) async {
    _ensureOpen();
    final channel = _channel;
    if (channel == null) throw StateError('Voice session is not connected.');
    channel.sink.add(jsonEncode(value));
  }

  void _ensureReady() {
    _ensureOpen();
    if (_channel == null)
      throw StateError('Connect to the authenticated voice gateway first.');
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Voice chat service is closed.');
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _capturing = false;
    await _audioSubscription?.cancel();
    await _socketSubscription?.cancel();
    await _recorder.dispose();
    await _audioPlayer?.dispose();
    await _channel?.sink.close();
    _channel = null;
    await _events.close();
  }
}
