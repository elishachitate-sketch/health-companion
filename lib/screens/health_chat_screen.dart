import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_language.dart';
import '../localization/localized_text.dart';
import '../localization/translations.dart';
import '../services/health_companion_service.dart';
import '../services/health_data.dart';
import '../services/voice_chat_stream_service.dart';
import '../services/voice_companion_service.dart';
import '../services/visit_routing_metadata.dart';

class HealthChatScreen extends StatefulWidget {
  const HealthChatScreen({
    super.key,
    this.caseId = 'mobile-session',
    this.consentLanguageLoader,
    this.accessTokenProvider,
  });

  final String caseId;
  final Future<String> Function()? consentLanguageLoader;
  final Future<String> Function()? accessTokenProvider;

  @override
  State<HealthChatScreen> createState() => _HealthChatScreenState();
}

class _HealthChatScreenState extends State<HealthChatScreen> {
  final _controller = TextEditingController();
  final _chatScrollController = ScrollController();
  final _service = HealthCompanionService();
  final _voice = VoiceCompanionService.instance;
  final _dataService = DataService.instance;
  final _messages = <_ChatLine>[];
  final _history = <Map<String, dynamic>>[];
  List<ChatEntry> _recentChatEntries = const [];
  bool _sending = false;
  bool _checkInExpanded = false;
  bool _voiceReady = false;
  bool _listening = false;
  bool _shareForCare = false;
  bool _voiceProcessingConsent = false;
  bool _speechObservationConsent = false;
  bool _speaking = false;
  bool _routeSuddenConfusion = false;
  bool _routeHearingConcern = false;
  bool _routeDailyFunction = false;
  String _locale = 'en-US';
  String get _localeLanguageCode =>
      _locale.toLowerCase().startsWith('ar') ? 'ar' : 'en';
  String _liveTranscript = '';
  String _speechObservationStatus = '';
  String? _voiceError;
  String? _storageNotice;
  VoiceChatStreamService? _streamService;
  StreamSubscription<VoiceChatEvent>? _streamSubscription;
  final StringBuffer _streamedReply = StringBuffer();
  bool _streamConnected = false;
  bool _pendingVoiceInput = false;
  bool _voiceTurnReady = false;
  bool _streamAudioTurnReady = false;
  static const _voiceGatewayUrl =
      String.fromEnvironment('BASIRA_VOICE_GATEWAY_URL');

  String _memory = 'Stable';
  String _focus = 'Stable';
  String _dailyTasks = 'Normal';
  String _mood = 'Okay';
  String _stress = 'Moderate';
  String _sleep = 'Fair';
  String _energy = 'Low';
  String _supportNeed = 'Self-guided';

  @override
  void initState() {
    super.initState();
    AppLanguage.locale.addListener(_onAppLanguageChanged);
    _createVoiceStreamService();
    _loadConsentProfile();
    _loadHistory();
  }

  void _onAppLanguageChanged() {
    final locale = VoiceCompanionService.localeForLanguage(
      AppLanguage.locale.value.languageCode,
    );
    if (_locale == locale) return;
    setState(() => _locale = locale);
    unawaited(_voice.configureLanguage(locale));
    unawaited(_streamService?.setProfileLanguage(locale));
  }

  void _createVoiceStreamService() {
    if (_voiceGatewayUrl.isEmpty || _streamService != null) return;
    _streamService = VoiceChatStreamService(
      gatewayUri: Uri.parse(_voiceGatewayUrl),
      accessTokenProvider: _loadVoiceAccessToken,
      consentGranted: () => _voiceProcessingConsent,
    );
    _streamSubscription = _streamService!.events.listen(_handleVoiceEvent);
    unawaited(_streamService!.setProfileLanguage(_locale));
  }

  Future<String> _loadVoiceAccessToken() async {
    if (widget.accessTokenProvider != null) {
      return widget.accessTokenProvider!();
    }
    if (Firebase.apps.isEmpty) {
      throw StateError('Authenticated voice access is not configured.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before starting live voice.');
    return await user.getIdToken() ?? '';
  }

  Future<void> _loadConsentProfile() async {
    try {
      final savedLanguage = await _loadSavedConsentLanguage();
      final language = savedLanguage ??
          (widget.consentLanguageLoader != null
              ? await widget.consentLanguageLoader!()
              : 'en');
      final locale = VoiceCompanionService.localeForLanguage(language);
      if (!mounted) return;
      setState(() => _locale = locale);
      AppLanguage.locale.value = Locale(_localeLanguageCode);
      await _streamService?.setProfileLanguage(locale);
      await _voice.configureLanguage(locale);
    } catch (error) {
      if (mounted) {
        setState(() => _voiceError = 'Speech language setup failed.');
      }
    }
  }

  Future<String?> _loadSavedConsentLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('appLanguage') ??
        prefs.getString('consent_profile_language');
  }

  List<Map<String, String>> _historyForApi() {
    return _history.map((entry) {
      final role = (entry['role'] ?? 'user').toString();
      final content = (entry['content'] ?? '').toString();
      final timestamp =
          (entry['timestamp'] ?? DateTime.now().toUtc().toIso8601String())
              .toString();
      return {'role': role, 'content': content, 'timestamp': timestamp};
    }).toList();
  }

  Future<void> _loadHistory() async {
    try {
      final restored = await _dataService.getChatEntriesLast7Days();
      if (!mounted) return;
      setState(() {
        _recentChatEntries = restored;
        _storageNotice = _dataService.isUsingTemporaryStorage
            ? 'History is kept only until this app session ends on this platform.'
            : null;
        _messages.addAll(restored.map((entry) => _ChatLine(
              entry.message,
              entry.role != 'assistant',
              createdAt: entry.date,
              metadata: {'tone': entry.tone.name, 'role': entry.role},
            )));
        for (final entry in restored) {
          _history.add({
            'role': entry.role,
            'content': entry.message,
            'timestamp': entry.date.toUtc().toIso8601String(),
          });
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _storageNotice =
            'Local history is unavailable; this will not prevent chat from connecting.');
      }
    }
  }

  String _buildWellbeingSummary() {
    return [
      'Mood: $_mood',
      'Sleep: $_sleep',
      'Energy: $_energy',
      'Focus: $_focus',
      'Stress: $_stress',
      'Daily tasks: $_dailyTasks',
      'Support: $_supportNeed',
    ].join(' • ');
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date • $time';
  }

  String _formatMessageTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatMessageDate(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = value.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}'
        .toUpperCase();
  }

  bool _isNewMessageDate(int index) {
    if (index == 0) return true;
    final current = _messages[index].createdAt.toLocal();
    final previous = _messages[index - 1].createdAt.toLocal();
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  @override
  void dispose() {
    AppLanguage.locale.removeListener(_onAppLanguageChanged);
    _controller.dispose();
    _chatScrollController.dispose();
    _service.close();
    unawaited(_streamSubscription?.cancel());
    unawaited(_streamService?.close());
    super.dispose();
  }

  void _scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleVoiceEvent(VoiceChatEvent event) {
    if (!mounted) return;
    switch (event) {
      case VoiceTranscriptEvent(:final text, :final isFinal):
        if (!isFinal) {
          _liveTranscript += text;
          setState(() {
            _controller.value = TextEditingValue(
              text: _liveTranscript,
              selection:
                  TextSelection.collapsed(offset: _liveTranscript.length),
            );
          });
        } else if (text.trim().isNotEmpty) {
          _liveTranscript = '';
          setState(() {
            _controller.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
            _pendingVoiceInput = true;
          });
        }
        break;
      case VoiceReplyTextEvent(:final text):
        _streamedReply.write(text);
        break;
      case VoiceReplyAudioEvent():
        setState(() => _speaking = true);
        break;
      case VoiceTurnCompletedEvent(:final audioPlayed):
        final reply = HealthCompanionService.cleanReplyText(
          _streamedReply.toString(),
        );
        _streamedReply.clear();
        if (reply.isNotEmpty) {
          final replyDate = DateTime.now();
          setState(() {
            _messages.add(_ChatLine(
              reply,
              false,
              createdAt: replyDate,
              metadata: {
                'context_type': 'assistant_reply',
                'mood': _mood,
                'sleep': _sleep,
              },
            ));
            _history.add({
              'role': 'assistant',
              'content': reply,
              'timestamp': replyDate.toUtc().toIso8601String(),
              'metadata': {
                'context_type': 'assistant_reply',
                'mood': _mood,
                'sleep': _sleep,
              },
            });
            _speaking = !audioPlayed;
          });
          _scrollToLatestMessage();
          unawaited(_saveAssistantReply(reply, replyDate));
        }
        break;
      case VoiceAssistantInterruptedEvent():
        setState(() => _speaking = false);
        unawaited(_voice.stopSpeakingForInterruption());
        break;
      case VoiceSpeechObservationEvent(:final observations):
        if (_speechObservationConsent) {
          final hesitation = observations['hesitationCount'];
          final pause = observations['pauseCount'];
          setState(() => _speechObservationStatus =
              (hesitation is num || pause is num)
                  ? 'Speech timing observations received for clinician context.'
                  : 'Speech timing observations received.');
        }
        break;
      case VoiceChatErrorEvent(:final message):
        setState(() {
          _listening = false;
          _speaking = false;
          _voiceError = message;
        });
        break;
    }
  }

  Future<void> _send() async {
    if (_sending) return;

    final typedMessage = _controller.text.trim();
    final stream = _streamService;
    final submitAudioTurn = _streamAudioTurnReady && stream != null;
    if (typedMessage.isEmpty && !submitAudioTurn) return;
    final userMessage =
        typedMessage.isNotEmpty ? typedMessage : 'Voice message';
    final messageDate = DateTime.now();
    final tone = _dataService.detectChatTone(userMessage);
    final routeMetadata = VisitRoutingMetadata.fromText(
      userMessage,
      source: _pendingVoiceInput ? 'voice_transcript' : 'typed_text',
    );
    _pendingVoiceInput = false;

    final wellbeing = WellbeingContext(
      memory: _memory.toLowerCase(),
      focus: _focus.toLowerCase(),
      dailyTasks: _dailyTasks.toLowerCase(),
      mood: _mood.toLowerCase(),
      stress: _stress.toLowerCase(),
      sleep: _sleep.toLowerCase(),
      energy: _energy.toLowerCase(),
      supportNeed: _supportNeed.toLowerCase().replaceAll(' ', '_'),
    );

    setState(() {
      _messages.add(_ChatLine(
        userMessage,
        true,
        createdAt: messageDate,
        metadata: {
          'context_type': 'user_message',
          'tone': tone.name,
          'mood': _mood,
          'sleep': _sleep,
          'energy': _energy,
          'focus': _focus,
          'daily_tasks': _dailyTasks,
        },
      ));
      _history.add({
        'role': 'user',
        'content': userMessage,
        'timestamp': messageDate.toUtc().toIso8601String(),
        'metadata': {
          'context_type': 'user_message',
          'tone': tone.name,
          'mood': _mood,
          'sleep': _sleep,
          'energy': _energy,
          'focus': _focus,
          'daily_tasks': _dailyTasks,
        },
      });
      _routeSuddenConfusion |= routeMetadata.suddenConfusion;
      _routeHearingConcern |= routeMetadata.hearingConcern;
      _routeDailyFunction |= routeMetadata.dailyFunctionDifficulty;
      _controller.clear();
      _sending = true;
      _voiceTurnReady = false;
      _streamAudioTurnReady = false;
    });
    _scrollToLatestMessage();

    try {
      try {
        await _dataService.saveChatEntry(
          ChatEntry(date: messageDate, message: userMessage, tone: tone),
        );
      } catch (_) {
        if (mounted) {
          setState(() => _storageNotice =
              'This message could not be saved locally, but chat will still try to connect.');
        }
      }

      if (stream != null && _voiceProcessingConsent) {
        await stream.setProfileLanguage(_locale);
        if (!_streamConnected) {
          await stream.connect(caseId: widget.caseId);
          _streamConnected = true;
        }
        if (submitAudioTurn) {
          await stream.submitCommittedAudioTurn();
        } else {
          await stream.sendText(
            userMessage,
            caseId: widget.caseId,
            history: _historyForApi(),
          );
        }
        return;
      }

      final response = await _service.sendMessage(
        userMessage,
        history: _historyForApi(),
        wellbeing: wellbeing,
        consent: WellbeingConsent(shareForCare: _shareForCare),
        locale: _locale,
        wellbeingSummary: _buildWellbeingSummary(),
      );

      if (!mounted) return;
      final replyDate = DateTime.now();
      setState(() {
        _messages.add(_ChatLine(
          response.reply,
          false,
          createdAt: replyDate,
          metadata: {
            'context_type': 'assistant_reply',
            'mood': _mood,
            'sleep': _sleep,
            'energy': _energy,
            'focus': _focus,
          },
        ));
        _history.add({
          'role': 'assistant',
          'content': response.reply,
          'timestamp': replyDate.toUtc().toIso8601String(),
          'metadata': {
            'context_type': 'assistant_reply',
            'mood': _mood,
            'sleep': _sleep,
            'energy': _energy,
            'focus': _focus,
          },
        });
      });
      _scrollToLatestMessage();
      await _saveAssistantReply(response.reply, replyDate);
      if (routeMetadata.urgentHandoff) {
        await _voice.stopSpeakingForInterruption();
      } else if (_voiceReady && _voice.isVoiceOutputEnabled) {
        if (mounted) setState(() => _speaking = true);
        await _voice.speak(response.reply);
        if (mounted) setState(() => _speaking = false);
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatLine(
            'Basira is taking longer than expected to respond. Your message is saved on this device; please try again shortly.',
            false,
            createdAt: DateTime.now(),
            metadata: {'context_type': 'timeout'},
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _messages.add(
          _ChatLine(
            'I could not reach Basira right now. Please check your connection and try again.\n\n$message',
            false,
            createdAt: DateTime.now(),
            metadata: {'context_type': 'error'},
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveAssistantReply(String reply, DateTime date) async {
    try {
      await _dataService.saveChatEntry(ChatEntry(
        date: date,
        message: reply,
        tone: ChatTone.neutral,
        role: 'assistant',
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _storageNotice =
            'Basira replied, but this reply could not be saved to local history.');
      }
    }
  }

  Future<void> _toggleVoice() async {
    _createVoiceStreamService();
    final stream = _streamService;

    if (_listening) {
      if (stream != null) {
        await stream.stopMicrophone(submitTurn: false);
      } else {
        await _voice.stopListening();
      }
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceTurnReady =
              stream != null || _controller.text.trim().isNotEmpty;
          _streamAudioTurnReady = stream != null;
        });
      }
      return;
    }

    bool microphoneAllowed;
    try {
      if (stream != null) {
        microphoneAllowed = await stream.requestMicrophonePermission();
      } else {
        if (!_voiceReady) {
          _voiceReady = await _voice.initialize(onError: (message) {
            if (mounted) setState(() => _voiceError = message);
          });
        }
        microphoneAllowed = _voiceReady;
      }
    } catch (_) {
      microphoneAllowed = false;
    }
    if (!mounted) return;
    if (!microphoneAllowed) {
      setState(() => _voiceError =
          'Microphone access was not granted. You can enable it in your device settings.');
      return;
    }
    if (!_voiceProcessingConsent) {
      setState(() => _voiceError =
          'Microphone access is granted. Enable voice processing in Privacy and safety to start recording.');
      return;
    }

    if (stream != null) {
      try {
        if (_speaking) {
          await _voice.stopSpeakingForInterruption();
          await stream.interruptAssistant();
        }
        if (!_streamConnected) {
          await stream.setProfileLanguage(_locale);
          await stream.connect(caseId: widget.caseId);
          _streamConnected = true;
        }
        await stream.startMicrophone(
          caseId: widget.caseId,
          includeSpeechObservations: _speechObservationConsent,
        );
        if (mounted) {
          setState(() {
            _controller.clear();
            _liveTranscript = '';
            _pendingVoiceInput = true;
            _voiceTurnReady = false;
            _streamAudioTurnReady = false;
            _listening = true;
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() => _voiceError =
              'Live voice is unavailable. Check sign-in, permission and network settings.');
        }
      }
      return;
    }

    if (!_voiceReady) return;
    if (_speaking) {
      await _voice.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
    }
    setState(() {
      _controller.clear();
      _pendingVoiceInput = true;
      _voiceTurnReady = false;
      _listening = true;
    });
    try {
      await _voice.listen(
        onResult: (result) {
          if (!mounted) return;
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          if (result.finalResult) {
            setState(() {
              _listening = false;
              _voiceTurnReady = _controller.text.trim().isNotEmpty;
            });
          }
        },
        localeId: _locale,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceError = 'Could not start recording. Check microphone access.';
        });
      }
    }
  }

  Future<void> _setVoiceProcessingConsent(bool allowed) async {
    setState(() {
      _voiceProcessingConsent = allowed;
      if (!allowed) _speechObservationConsent = false;
    });
    if (allowed) {
      _createVoiceStreamService();
      await _streamService?.setProfileLanguage(_locale);
      return;
    }

    final service = _streamService;
    if (service == null) return;
    if (service.isCapturing) {
      await service.stopMicrophone(submitTurn: false, discard: true);
    } else {
      await service.interruptAssistant();
    }
    await _streamSubscription?.cancel();
    await service.close();
    if (!mounted) return;
    setState(() {
      _streamService = null;
      _streamSubscription = null;
      _streamConnected = false;
      _listening = false;
      _speaking = false;
    });
  }

  Widget _routingBanner() {
    if (!_routeSuddenConfusion &&
        !_routeHearingConcern &&
        !_routeDailyFunction) {
      return const SizedBox.shrink();
    }

    final urgent = _routeSuddenConfusion;
    final flags = [
      if (_routeSuddenConfusion) 'sudden confusion',
      if (_routeHearingConcern) 'hearing concern',
      if (_routeDailyFunction) 'daily-task difficulty',
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xffffe8e4) : const Color(0xfff1eee6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            urgent ? Icons.priority_high_rounded : Icons.route_outlined,
            color: const Color(0xff343a38),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              urgent
                  ? 'Your report mentions sudden confusion. Please contact local emergency services or a trusted person now. This conversation is not monitored for emergencies.'
                  : 'We can include ${flags.join(', ')} in a clinician review request. This is not a diagnosis.',
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatHistorySummary() {
    final count =
        _recentChatEntries.where((entry) => entry.role != 'assistant').length;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      elevation: 0,
      color: const Color(0xff008f83),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          count == 0
              ? 'Your last 7 days in chat:'
              : 'Your last 7 days in chat: $count messages',
          style: const TextStyle(
            color: Colors.white,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildWellbeingPanel() => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff008f83),
            brightness: Brightness.dark,
            surface: const Color(0xff008f83),
          ),
        ),
        child: Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          color: const Color(0xff008f83),
          child: ExpansionTile(
            initiallyExpanded: _checkInExpanded,
            onExpansionChanged: (expanded) =>
                setState(() => _checkInExpanded = expanded),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(Icons.favorite_outline, color: Colors.white),
            title: const Text('A brief check-in',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Optional · chat works without it.',
                style: TextStyle(color: Color(0xffd0e4e1))),
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'These self-reported answers are conversation context only—not a screening test or diagnosis.',
                  style: TextStyle(height: 1.35, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              _buildChoiceRow('Memory', ['Worse', 'Stable', 'Better'], _memory,
                  (value) => setState(() => _memory = value)),
              _buildChoiceRow('Focus', ['Worse', 'Stable', 'Better'], _focus,
                  (value) => setState(() => _focus = value)),
              _buildChoiceRow(
                'Daily tasks',
                ['Harder', 'Normal', 'Easier'],
                _dailyTasks,
                (value) => setState(() => _dailyTasks = value),
              ),
              _buildChoiceRow('Mood', ['Low', 'Okay', 'Better'], _mood,
                  (value) => setState(() => _mood = value)),
              _buildChoiceRow('Stress', ['Low', 'Moderate', 'High'], _stress,
                  (value) => setState(() => _stress = value)),
              _buildChoiceRow('Sleep', ['Poor', 'Fair', 'Good'], _sleep,
                  (value) => setState(() => _sleep = value)),
              _buildChoiceRow('Energy', ['Low', 'Okay', 'High'], _energy,
                  (value) => setState(() => _energy = value)),
              _buildChoiceRow(
                'Support I need',
                [
                  'Self-guided',
                  'Community',
                  'Primary care',
                  'Neurology review'
                ],
                _supportNeed,
                (value) => setState(() => _supportNeed = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _shareForCare,
                onChanged: (value) => setState(() => _shareForCare = value),
                title:
                    const Text('Share my health context for care coordination'),
                subtitle: const Text(
                    'Optional. Your data stays private unless you choose to share it.'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _voiceProcessingConsent,
                onChanged: _setVoiceProcessingConsent,
                title: const Text('Allow microphone and speech transcription'),
                subtitle: const Text(
                    'Optional. Audio is streamed only to the configured secure voice service; the app does not intentionally retain raw audio.'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _speechObservationConsent,
                onChanged: _voiceProcessingConsent
                    ? (value) =>
                        setState(() => _speechObservationConsent = value)
                    : null,
                title: const Text('Include speech timing observations'),
                subtitle: const Text(
                    'Optional analysis of pauses and speech rate for clinician context. No raw audio is intentionally retained.'),
              ),
              if (_speechObservationStatus.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_speechObservationStatus),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildChoiceRow(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String> onSelected,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: option == selected,
                  onSelected: (_) => onSelected(option),
                );
              }).toList(),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffe2f1f0),
      appBar: AppBar(
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xffd2e8e7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xff263735),
        leadingWidth: 56,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
        ),
        titleSpacing: 16,
        title: const Text(
          'Basira AI',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _showPrivacyInfo,
            icon: const Icon(Icons.lock_outline_rounded, size: 27),
            tooltip: AppTranslations.translate(
                'Privacy and safety', _localeLanguageCode),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _chatScrollController,
              slivers: [
                if (_voiceError != null)
                  SliverToBoxAdapter(
                    child: MaterialBanner(
                      backgroundColor: const Color(0xfffff1df),
                      content: Text('Voice needs attention: $_voiceError'),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _voiceError = null),
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                if (_storageNotice != null)
                  SliverToBoxAdapter(
                    child: MaterialBanner(
                      backgroundColor: const Color(0xffeaf2f4),
                      content: Text(_storageNotice!),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _storageNotice = null),
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                SliverToBoxAdapter(child: _chatHistorySummary()),
                SliverToBoxAdapter(child: _buildWellbeingPanel()),
                SliverToBoxAdapter(child: _routingBanner()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final line = _messages[index];
                        return _buildMessageRow(
                          line,
                          showDate: _isNewMessageDate(index),
                        );
                      },
                      childCount: _messages.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: _buildBottomInputBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(_ChatLine line, {required bool showDate}) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: line.fromUser ? const Color(0xff008f83) : Colors.white,
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(18),
          topEnd: const Radius.circular(18),
          bottomStart: Radius.circular(line.fromUser ? 18 : 2),
          bottomEnd: Radius.circular(line.fromUser ? 2 : 18),
        ),
      ),
      child: Text(
        line.text,
        style: TextStyle(
          color: line.fromUser ? Colors.white : const Color(0xff064d47),
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          if (showDate)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xffb2dfdb),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text(
                    _formatMessageDate(line.createdAt),
                    style: const TextStyle(
                      color: Color(0xff064d47),
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                line.fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _messageRowChildren(line, bubble),
          ),
        ],
      ),
    );
  }

  List<Widget> _messageRowChildren(_ChatLine line, Widget bubble) {
    final time = _messageTime(line.createdAt);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    if (line.fromUser) {
      return isRtl ? [bubble, time] : [time, bubble];
    }
    return isRtl ? [time, bubble] : [bubble, time];
  }

  Widget _messageTime(DateTime value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Semantics(
          label: _formatTimestamp(value),
          child: Text(
            _formatMessageTime(value),
            style: const TextStyle(
              color: Color(0xff687572),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _buildBottomInputBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsetsDirectional.only(
                  start: 14,
                  end: 2,
                  top: 4,
                  bottom: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xfff8f8f8),
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff064d47).withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        textAlign: TextAlign.start,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          color: Color(0xff064d47),
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: AppTranslations.translate(
                              'Type a message', _localeLanguageCode),
                          hintStyle: const TextStyle(
                            color: Color(0xff668a85),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 5,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      constraints:
                          const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                      onPressed: _sending ? null : _toggleVoice,
                      tooltip: AppTranslations.translate(
                          _listening
                              ? 'Stop recording'
                              : 'Record voice message',
                          _localeLanguageCode),
                      icon: Icon(
                        _listening
                            ? Icons.stop_rounded
                            : (_speaking
                                ? Icons.volume_up
                                : Icons.mic_none_rounded),
                        color: _listening || _speaking
                            ? const Color(0xff008f83)
                            : const Color(0xff9ca5a3),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: _sending || _listening ? null : _send,
                tooltip: AppTranslations.translate(
                    _voiceTurnReady ? 'Send voice message' : 'Send message',
                    _localeLanguageCode),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xff008f83),
                  disabledBackgroundColor: const Color(0xffaeb7b4),
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  shadowColor: const Color(0xff064d47).withValues(alpha: 0.25),
                ),
                icon: const Icon(Icons.send_rounded, size: 21),
              ),
            ),
          ],
        ),
      );

  Future<void> _showPrivacyInfo() async {
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: const Text('Privacy and safety'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat is support, not diagnosis. You control whether optional voice processing is enabled.',
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _voiceProcessingConsent,
                  onChanged: (allowed) async {
                    await _setVoiceProcessingConsent(allowed);
                    dialogSetState(() {});
                  },
                  title: const Text('Allow microphone and transcription'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _speechObservationConsent,
                  onChanged: _voiceProcessingConsent
                      ? (enabled) => dialogSetState(
                            () => _speechObservationConsent = enabled,
                          )
                      : null,
                  title: const Text('Include speech timing observations'),
                ),
                if (_speechObservationStatus.isNotEmpty)
                  Text(
                    _speechObservationStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Understood'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatLine {
  _ChatLine(
    this.text,
    this.fromUser, {
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  })  : createdAt = createdAt ?? DateTime.now(),
        metadata = metadata ?? const {};

  final String text;
  final bool fromUser;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
}
