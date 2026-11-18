import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:speech_to_text/speech_to_text.dart';

import '../localization/app_language.dart';
import '../localization/localized_text.dart' as localized;
import '../services/health_data.dart';
import '../widgets/basira_bottom_navigation.dart';

class VoiceCheckInScreen extends StatefulWidget {
  const VoiceCheckInScreen({super.key});

  @override
  State<VoiceCheckInScreen> createState() => _VoiceCheckInScreenState();
}

class _VoiceCheckInScreenState extends State<VoiceCheckInScreen> {
  static const _teal = Color(0xff0e7c7b);
  static const _ink = Color(0xff171b24);

  final _speech = SpeechToText();
  final _transcriptController = TextEditingController();
  final _stopwatch = Stopwatch();
  Timer? _limitTimer;
  bool _consent = false;
  bool _recording = false;
  bool _speechAvailable = false;
  bool _needsManualText = false;
  bool _saving = false;
  bool _hadLongPause = false;
  DateTime? _lastSpeechAt;
  int _durationSeconds = 0;
  VoiceNote? _savedNote;
  String? _error;

  @override
  void dispose() {
    _limitTimer?.cancel();
    if (_recording) unawaited(_speech.cancel());
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!_consent || _recording || _saving) return;
    setState(() {
      _error = null;
      _savedNote = null;
      _needsManualText = false;
      _hadLongPause = false;
      _durationSeconds = 0;
      _transcriptController.clear();
    });

    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _error = 'Speech recognition is unavailable. You can type instead.';
            _needsManualText = true;
            _recording = false;
            _durationSeconds = _stopwatch.elapsed.inSeconds.clamp(0, 30);
          });
          _limitTimer?.cancel();
          _stopwatch.stop();
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }

    if (!_speechAvailable) {
      if (!mounted) return;
      setState(() {
        _needsManualText = true;
        _error = 'Speech recognition is unavailable. You can type instead.';
      });
      return;
    }

    _stopwatch
      ..reset()
      ..start();
    _lastSpeechAt = DateTime.now();
    setState(() => _recording = true);

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final now = DateTime.now();
          final previous = _lastSpeechAt;
          if (previous != null && now.difference(previous).inSeconds >= 3) {
            _hadLongPause = true;
          }
          _lastSpeechAt = now;
          if (result.recognizedWords.isNotEmpty) {
            _transcriptController.value = TextEditingValue(
              text: result.recognizedWords,
              selection: TextSelection.collapsed(
                offset: result.recognizedWords.length,
              ),
            );
          }
          setState(() {});
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          listenMode: ListenMode.dictation,
          localeId: AppLanguage.isArabic ? 'ar-AE' : 'en-US',
        ),
      );
      _limitTimer = Timer(const Duration(seconds: 30), _stopRecording);
    } catch (_) {
      _stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _needsManualText = true;
        _error = 'Speech recognition is unavailable. You can type instead.';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    _limitTimer?.cancel();
    _stopwatch.stop();
    final now = DateTime.now();
    final lastSpeechAt = _lastSpeechAt;
    if (lastSpeechAt != null && now.difference(lastSpeechAt).inSeconds >= 3) {
      _hadLongPause = true;
    }
    try {
      await _speech.stop();
    } catch (_) {
      // A stop failure never writes or retains raw audio.
    }
    if (!mounted) return;
    final hasTranscript = _transcriptController.text.trim().isNotEmpty;
    setState(() {
      _recording = false;
      _durationSeconds = _stopwatch.elapsed.inSeconds.clamp(0, 30);
      _needsManualText = !hasTranscript;
    });
    if (hasTranscript) await _saveVoiceNote();
  }

  Future<void> _saveVoiceNote() async {
    final transcript = _transcriptController.text.trim();
    if (!_consent || transcript.isEmpty || _saving) return;

    final duration = _durationSeconds;
    final wordCount = transcript
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    final rate = wordCount / (duration <= 0 ? 1 : duration);
    final speechRate = rate < 2
        ? 'Slow'
        : rate <= 3.5
            ? 'Normal'
            : 'Fast';
    final normalized = transcript.toLowerCase();
    bool containsWord(String word) => RegExp(
          r'\b' + RegExp.escape(word) + r'\b',
        ).hasMatch(normalized);
    final toneWords = <String>[
      if (containsWord('tired')) 'tired',
      if (containsWord('worried') || containsWord('sad')) 'worried',
      if (containsWord('hopeful') ||
          containsWord('good') ||
          containsWord('better'))
        'hopeful',
      if (containsWord('calm')) 'calm',
    ];
    final hasTired = containsWord('tired');
    final hasHopeful = containsWord('hopeful') ||
        containsWord('good') ||
        containsWord('better');
    final energy = rate > 3.5 && hasHopeful
        ? 'High'
        : rate < 2 && hasTired && !hasHopeful
            ? 'Low'
            : 'Steady';
    final pauses = transcript.contains('...') || _hadLongPause ? 'Many' : 'Few';
    final wellbeingSignal = hasTired && energy == 'Low'
        ? 'NeedsRest'
        : hasHopeful && energy == 'Steady'
            ? 'DoingWell'
            : 'Steady';
    final note = VoiceNote(
      date: DateTime.now(),
      durationSeconds: duration,
      speechRate: speechRate,
      pauses: pauses,
      energy: energy,
      toneWords: toneWords,
      transcript: transcript,
      wellbeingSignal: wellbeingSignal,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await DataService.instance.addVoiceNote(note);
      if (!mounted) return;
      setState(() {
        _savedNote = note;
        _needsManualText = false;
        _error =
            'Recording stopped. No audio file is stored; transcript and tone summary are saved in the encrypted store.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'The voice check-in could not be saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _resultText(VoiceNote note) {
    final tones =
        note.toneWords.isEmpty ? 'neutral' : note.toneWords.join(', ');
    return 'Your tone today: $tones. Speech: ${note.speechRate}, Pauses: ${note.pauses}, Energy: ${note.energy}. Wellbeing Signal: ${note.wellbeingSignal}.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: const BasiraBottomNavigation(selectedIndex: 3),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          title: const _VoiceText(
            'Voice check-in',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Card(
                elevation: 0,
                color: const Color(0xffeef3f2),
                child: SwitchListTile(
                  value: _consent,
                  activeTrackColor: _teal,
                  onChanged: (value) => setState(() => _consent = value),
                  title: const _VoiceText('I agree to a voice check-in'),
                  subtitle: const _VoiceText(
                    'Optional. No audio file is stored. The device speech-recognition service processes speech; transcript and tone summary are saved in this device’s encrypted store.',
                    style: TextStyle(color: Color(0xff58636d)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _VoiceText(
                        'A voice check-in can last up to 30 seconds.',
                        style: TextStyle(color: _ink, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (_recording)
                        FilledButton.icon(
                          onPressed: _stopRecording,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const _VoiceText('Stop and review'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                          ),
                        )
                      else
                        FilledButton.icon(
                          onPressed:
                              _consent && !_saving ? _startRecording : null,
                          icon: const Icon(Icons.mic_none_rounded),
                          label: _VoiceText(
                            _consent
                                ? 'Record up to 30 seconds'
                                : 'Agree to enable recording',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (_recording) ...[
                        const SizedBox(height: 8),
                        const _VoiceText(
                          'Recording in progress. No audio file is created.',
                          style: TextStyle(color: Color(0xff58636d)),
                        ),
                      ],
                      if (_needsManualText && !_recording) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _transcriptController,
                          minLines: 2,
                          maxLines: 5,
                          textAlign: TextAlign.start,
                          decoration: const InputDecoration(
                            label: _VoiceText('Type what you said'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _saving ? null : _saveVoiceNote,
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                          ),
                          child: _VoiceText(
                              _saving ? 'Saving…' : 'Save voice check-in'),
                        ),
                      ],
                      if (_transcriptController.text.isNotEmpty &&
                          !_needsManualText &&
                          !_recording &&
                          _savedNote == null) ...[
                        const SizedBox(height: 12),
                        _VoiceText(
                          _transcriptController.text,
                          style: const TextStyle(color: _ink, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _saving ? null : _saveVoiceNote,
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                          ),
                          child: _VoiceText(
                              _saving ? 'Saving…' : 'Save voice check-in'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_savedNote != null) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: const Color(0xffe6f3f2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VoiceText(
                          _resultText(_savedNote!),
                          style: const TextStyle(color: _ink, height: 1.45),
                        ),
                        const SizedBox(height: 8),
                        _VoiceText(
                          _error ??
                              'Recording stopped. No audio file is stored; transcript and tone summary are saved in the encrypted store.',
                          style: const TextStyle(
                            color: Color(0xff58636d),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_error != null && _savedNote == null) ...[
                const SizedBox(height: 8),
                _VoiceText(_error!, style: const TextStyle(color: _ink)),
              ],
              const SizedBox(height: 12),
              const _VoiceText(
                'Tone is a wellbeing signal, not a medical diagnosis.',
                style: TextStyle(color: Color(0xff58636d), height: 1.4),
              ),
            ],
          ),
        ),
      );
}

class _VoiceText extends StatelessWidget {
  const _VoiceText(this.data, {this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => localized.Text(
        data,
        style: style,
        textAlign: TextAlign.start,
      );
}
