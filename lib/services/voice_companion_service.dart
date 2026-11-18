import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceCompanionService {
  VoiceCompanionService._();

  static final instance = VoiceCompanionService._();
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  bool _ready = false;
  bool _speechPermissionAvailable = true;
  bool _ttsReady = false;
  String _localeId = 'en-US';
  String _speechLocaleId = 'en-US';

  static String localeForLanguage(String language) =>
      language.toLowerCase().startsWith('ar') ? 'ar-AE' : 'en-US';

  Future<bool> initialize({void Function(String)? onError}) async {
    try {
      _ready = await _speech.initialize(
        onError: (error) => onError?.call(error.errorMsg),
      );
      _speechPermissionAvailable = _ready;
      if (_ready) await configureLanguage(_localeId);
    } catch (error) {
      onError?.call(error.toString());
      _ready = false;
    }
    return _ready;
  }

  Future<void> configureLanguage(String locale) async {
    final normalized = localeForLanguage(locale);
    _localeId = normalized;
    _speechLocaleId = normalized;
    if (_ready) {
      final locales = await _speech.locales();
      final match = locales.where((available) {
        final availableCode =
            available.localeId.replaceAll('_', '-').toLowerCase();
        return availableCode == normalized.toLowerCase();
      }).firstOrNull;
      if (match != null) {
        _speechLocaleId = match.localeId;
      }
    }
    try {
      await _tts.setLanguage(normalized);
      await _tts.setSpeechRate(0.46);
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    } catch (_) {
      // TTS availability must not prevent microphone recording or STT.
      _ttsReady = false;
    }
  }

  Future<void> listen(
      {required void Function(SpeechRecognitionResult) onResult,
      String localeId = ''}) {
    if (!_ready || !_speechPermissionAvailable) return Future.value();
    final requestedLocale =
        localeId.isEmpty ? _speechLocaleId : localeForLanguage(localeId);
    return _speech.listen(
      onResult: onResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        localeId: requestedLocale,
      ),
    );
  }

  Future<void> stopSpeakingForInterruption() async {
    await stopSpeaking();
  }

  Future<void> stopListening() => _speech.stop();

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_ttsReady) {
      await configureLanguage(_localeId);
    }
    if (!_ttsReady) throw StateError('Speech output is unavailable.');
    await _tts.speak(text.trim());
  }

  bool get isListening => _speech.isListening;
  bool get isVoiceOutputEnabled => true;

  Future<void> stopSpeaking() => _tts.stop();
}
