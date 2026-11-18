import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../localization/app_language.dart';
import '../localization/localized_text.dart' as localized;
import '../screens/review_summary_screen.dart';
import '../services/health_data.dart';
import '../services/voice_companion_service.dart';
import '../widgets/basira_bottom_navigation.dart';

const _studioInk = Color(0xff343a38);
const _studioMuted = Color(0xff66716e);
const _studioTeal = Color(0xff0e7c7b);
const _studioMint = Color(0xffe4f0eb);

/// Practice-only activities. These interactions are not a diagnostic test and
/// do not produce clinical scores or alter an individual's risk category.
class MulticognitiveStudioScreen extends StatefulWidget {
  const MulticognitiveStudioScreen({
    super.key,
    this.showBottomNavigation = true,
  });

  final bool showBottomNavigation;

  @override
  State<MulticognitiveStudioScreen> createState() =>
      _MulticognitiveStudioScreenState();
}

class _MulticognitiveStudioScreenState
    extends State<MulticognitiveStudioScreen> {
  int _activityIndex = 0;
  int _pianoStep = 0;
  final List<int> _pianoInput = [];
  int _attentionRound = 0;
  int _ruleRound = 0;
  int _recallStep = 0;
  int? _selectedTile;
  final TextEditingController _recallController = TextEditingController();
  final _dataService = DataService.instance;
  final List<CognitiveTaskResult> _recentResults = [];
  bool _isListening = false;
  bool _showPianoSequence = false;
  bool _showRecallWords = true;
  bool _colorRule = true;
  bool _savingTask = false;
  String? _completionMessage;
  DateTime? _taskStartedAt;
  int _taskAttempts = 0;
  int _taskCorrect = 0;
  String _status =
      'Choose a practice activity. You can pause or stop at any time.';

  static const _sequenceNotes = <String>['Do', 'Mi', 'Sol', 'Mi'];
  static const _pianoKeys = <String>['Do', 'Mi', 'Sol', 'La'];
  static const _sequenceKeyIndexes = <int>[0, 1, 2, 1];
  static const _noteColors = <Color>[
    Color(0xff0e7c7b),
    Color(0xffd9a14a),
    Color(0xff568b78),
    Color(0xff7185a6),
  ];
  static const _words = <String>['Lemon', 'Key', 'Garden'];

  @override
  void initState() {
    super.initState();
    _taskStartedAt = DateTime.now();
    _loadRecentResults();
  }

  Future<void> _loadRecentResults() async {
    try {
      final results = await _dataService.getLast30Days();
      if (!mounted) return;
      setState(() {
        _recentResults
          ..clear()
          ..addAll(results);
      });
    } catch (_) {
      // The practice UI remains usable if local storage is unavailable.
    }
  }

  @override
  void dispose() {
    if (_isListening) {
      unawaited(VoiceCompanionService.instance.stopListening());
    }
    unawaited(VoiceCompanionService.instance.stopSpeaking());
    _recallController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: widget.showBottomNavigation
            ? const BasiraBottomNavigation(selectedIndex: 0)
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(),
                  const _IllustrativeNotice(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        _heading(),
                        const SizedBox(height: 16),
                        _comfortCard(),
                        const SizedBox(height: 16),
                        _weeklyProgressCard(),
                        const SizedBox(height: 16),
                        _activityPicker(),
                        const SizedBox(height: 14),
                        _activityContent(),
                        if (_completionMessage != null) ...[
                          const SizedBox(height: 12),
                          _completionCard(),
                        ],
                        const SizedBox(height: 14),
                        _progressCard(),
                        const SizedBox(height: 12),
                        const _PracticeDisclaimer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: _studioTeal, size: 23),
            const SizedBox(width: 8),
            const _StudioText('basira',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _studioInk)),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  AppLanguage.setLanguage(AppLanguage.isArabic ? 'en' : 'ar'),
              child: _StudioText(AppLanguage.isArabic ? 'English' : 'العربية',
                  style: const TextStyle(fontSize: 12)),
            ),
            IconButton(
              tooltip: 'Accessibility options',
              onPressed: () => _showAccessibilityOptions(),
              icon: const Icon(Icons.accessibility_new, color: _studioMuted),
            ),
          ],
        ),
      );

  Widget _heading() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StudioText('PRACTICE COACHING · MULTICOGNITIVE STUDIO',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: .45,
                  color: _studioTeal,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 7),
          _StudioText('Practice at your pace.',
              style: TextStyle(
                  fontSize: 29,
                  height: 1.12,
                  color: _studioInk,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          _StudioText(
              'A friendly practice space for memory, attention and flexible thinking. No timer, no grades.',
              style:
                  TextStyle(color: _studioMuted, height: 1.45, fontSize: 15)),
        ],
      );

  Widget _comfortCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _studioMint, borderRadius: BorderRadius.circular(15)),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tune_rounded, color: _studioInk),
            SizedBox(width: 10),
            Expanded(
                child: _StudioText(
                    'Make this comfortable\nUse larger text, sound or a helper. Take a break whenever you like.',
                    style: TextStyle(color: _studioInk, height: 1.4))),
          ],
        ),
      );

  Widget _activityPicker() {
    const labels = ['Piano', 'Find', 'Switch', 'Recall'];
    const icons = [
      Icons.piano_outlined,
      Icons.search_rounded,
      Icons.swap_horiz_rounded,
      Icons.lightbulb_outline
    ];
    return Semantics(
      label: 'Choose a practice activity',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < labels.length; i++)
            FilterChip(
              avatar: Icon(icons[i], size: 18),
              label: _StudioText(labels[i],
                  style: const TextStyle(fontSize: 14, color: _studioInk)),
              labelStyle: const TextStyle(fontSize: 14, color: _studioInk),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              selected: _activityIndex == i,
              selectedColor: const Color(0xffe6f3f2),
              checkmarkColor: _studioTeal,
              onSelected: (_) => setState(() {
                _activityIndex = i;
                _taskStartedAt = DateTime.now();
                _taskAttempts = 0;
                _taskCorrect = 0;
                _completionMessage = null;
                _status = 'Selected ${labels[_activityIndex]} practice.';
                _selectedTile = null;
              }),
            ),
        ],
      ),
    );
  }

  Widget _activityContent() => switch (_activityIndex) {
        0 => _pianoActivity(),
        1 => _attentionActivity(),
        2 => _ruleSwitchingActivity(),
        _ => _recallActivity(),
      };

  Widget _pianoActivity() => _panel(
        icon: Icons.piano_outlined,
        title: 'Piano sequence',
        subtitle: 'Memory & sequencing · Follow the notes, then try the order.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepLabel(_pianoStep == 0
                ? 'Step 1 of 3 · See'
                : _pianoStep == 1
                    ? 'Step 2 of 3 · Hear'
                    : 'Step 3 of 3 · Play'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xfff5f6f4),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  _StudioText(
                      _showPianoSequence
                          ? _sequenceNotes.join('   ·   ')
                          : 'Four notes will appear here',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _studioInk),
                      textAlign: TextAlign.start),
                  const SizedBox(height: 16),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [for (var i = 0; i < 4; i++) _pianoKey(i)]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: _showNotes,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const _StudioText('See')),
              OutlinedButton.icon(
                  onPressed: _hearNotes,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const _StudioText('Hear')),
              FilledButton.icon(
                  onPressed: _startPianoPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const _StudioText('Play')),
            ]),
            const SizedBox(height: 8),
            _StudioText(_status,
                key: const ValueKey('pianoStatus'),
                style: const TextStyle(color: _studioMuted, height: 1.4)),
          ],
        ),
      );

  Widget _pianoKey(int index) {
    final isActive = _selectedTile == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        label: 'Piano key ${_pianoKeys[index]}',
        child: InkWell(
          key: ValueKey('piano-key-$index'),
          onTap: _pianoStep < 2 ? null : () => _playNote(index),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 54,
            height: 88,
            decoration: BoxDecoration(
              color: isActive
                  ? _noteColors[index].withValues(alpha: .25)
                  : Colors.white,
              border: Border.all(
                  color: _noteColors[index], width: isActive ? 3 : 1.5),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                      color: _noteColors[index].withValues(alpha: .16),
                      blurRadius: 8)
              ],
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 9),
            child: _StudioText(_pianoKeys[index],
                style: TextStyle(
                    color: _noteColors[index], fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  void _showNotes() => setState(() {
        _pianoStep = 1;
        _pianoInput.clear();
        _selectedTile = null;
        _showPianoSequence = true;
        _status = 'Look at the notes in order: Do, Mi, Sol, Mi.';
      });

  Future<void> _hearNotes() async {
    setState(() {
      _taskStartedAt ??= DateTime.now();
      _pianoStep = 2;
      _pianoInput.clear();
      _showPianoSequence = false;
      _status = 'Listen to the note names in order.';
    });
    try {
      await VoiceCompanionService.instance.speak(_sequenceNotes.join(', '));
      if (mounted) {
        setState(
            () => _status = 'Now tap the notes in the order you heard them.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status =
            'Sound is unavailable. Use See to view the sequence, then Play.');
      }
    }
  }

  void _startPianoPlay() => setState(() {
        _taskStartedAt ??= DateTime.now();
        _taskAttempts = 0;
        _taskCorrect = 0;
        _completionMessage = null;
        _pianoStep = 2;
        _pianoInput.clear();
        _showPianoSequence = false;
        _selectedTile = null;
        _status = 'Tap the keys in order: Do, Mi, Sol, Mi.';
      });

  void _playNote(int noteIndex) {
    final attemptIndex = _pianoInput.length;
    final isCorrect = noteIndex == _sequenceKeyIndexes[attemptIndex];
    _taskAttempts++;
    if (isCorrect) _taskCorrect++;
    var completed = false;
    var correctCount = _taskCorrect;
    setState(() {
      _pianoInput.add(noteIndex);
      _selectedTile = noteIndex;
      if (_pianoInput.length == _sequenceNotes.length) {
        completed = true;
        _status = correctCount == _sequenceNotes.length
            ? 'Sequence complete. You followed the note order.'
            : 'Sequence complete. You can listen and try again if you like.';
        _pianoInput.clear();
      } else {
        _status =
            'Note ${_pianoInput.length} of ${_sequenceNotes.length} played.';
      }
    });
    if (completed) {
      _completeTask(
        task: CognitiveTask.memory,
        correct: correctCount,
        total: _sequenceNotes.length,
        unit: 'notes',
      );
    }
  }

  Widget _attentionActivity() {
    final targetIndex = (_attentionRound * 3 + 2) % 12;
    final symbols = List<String>.generate(12,
        (index) => index == targetIndex ? '○' : (index % 2 == 0 ? '△' : '□'));
    return _panel(
      icon: Icons.search_rounded,
      title: 'Visual attention',
      subtitle: 'Selective attention · Find the circle among the shapes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepLabel('See · Find the circle'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xfff5f6f4),
                borderRadius: BorderRadius.circular(14)),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: symbols.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.15),
              itemBuilder: (context, index) => Semantics(
                button: true,
                label: 'Shape ${index + 1}',
                child: Material(
                  color: _selectedTile == index ? _studioMint : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectAttention(index, targetIndex),
                    child: Center(
                        child: _StudioText(symbols[index],
                            style: const TextStyle(
                                fontSize: 34, color: _studioInk))),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _status = 'Look for the circle: ○'),
              icon: const Icon(Icons.visibility_outlined),
              label: const _StudioText('See')),
          _StudioText(_status,
              style: const TextStyle(color: _studioMuted, height: 1.4)),
        ],
      ),
    );
  }

  void _selectAttention(int index, int targetIndex) {
    _taskAttempts++;
    final found = index == targetIndex;
    if (found) _taskCorrect++;
    setState(() {
      _selectedTile = index;
      if (found) {
        _attentionRound++;
        _selectedTile = null;
        _status = 'You found it. A new practice round is ready.';
      } else {
        _status = 'Not that one. Take your time and look again.';
      }
    });
    if (found) {
      _completeTask(
        task: CognitiveTask.attention,
        correct: 1,
        total: _taskAttempts,
        unit: 'tries',
      );
    }
  }

  Widget _ruleSwitchingActivity() {
    final targetColor = _colorRule ? _studioTeal : const Color(0xff568b78);
    final targetShape = _colorRule ? Icons.circle : Icons.square_rounded;
    return _panel(
      icon: Icons.swap_horiz_rounded,
      title: 'Rule switching',
      subtitle: 'Cognitive flexibility · Choose the shape or color rule.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepLabel('See · Round ${_ruleRound + 1}'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _studioMint, borderRadius: BorderRadius.circular(13)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _StudioText('Current rule: ${_colorRule ? 'Color' : 'Shape'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: _studioInk)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(targetShape, size: 36, color: targetColor),
                const SizedBox(width: 10),
                const _StudioText('Match this symbol',
                    style: TextStyle(color: _studioInk))
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const _StudioText('Sort by color'),
                selected: _colorRule,
                onSelected: (_) => setState(() {
                      _colorRule = true;
                      _status = 'Color rule selected.';
                    })),
            ChoiceChip(
                label: const _StudioText('Sort by shape'),
                selected: !_colorRule,
                onSelected: (_) => setState(() {
                      _colorRule = false;
                      _status = 'Shape rule selected.';
                    })),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: () => setState(() => _status =
                  'Current rule: ${_colorRule ? 'Color' : 'Shape'}. Match the symbol above.'),
              icon: const Icon(Icons.visibility_outlined),
              label: const _StudioText('See')),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _ruleOption(Icons.circle, _studioTeal),
            _ruleOption(Icons.square_rounded, const Color(0xff568b78)),
            _ruleOption(Icons.circle, const Color(0xff568b78)),
            _ruleOption(Icons.square_rounded, _studioTeal),
          ]),
          const SizedBox(height: 10),
          _StudioText(_status,
              style: const TextStyle(color: _studioMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _ruleOption(IconData shape, Color color) => Semantics(
        button: true,
        label:
            'Option ${shape == Icons.circle ? 'circle' : 'square'}, ${color == _studioTeal ? 'teal' : 'green'}',
        child: InkWell(
          onTap: () {
            _taskAttempts++;
            final correct = _colorRule
                ? color == _studioTeal
                : shape == Icons.square_rounded;
            if (correct) _taskCorrect++;
            setState(() {
              if (correct) {
                _ruleRound++;
                _colorRule = !_colorRule;
                _status = 'Good. The sorting rule has switched.';
              } else {
                _status = 'Try again using the current rule.';
              }
            });
            if (correct) {
              _completeTask(
                task: CognitiveTask.flexibleThinking,
                correct: 1,
                total: _taskAttempts,
                unit: 'choices',
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 64,
            height: 58,
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xffdfe5e2)),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(shape, color: color, size: 30),
          ),
        ),
      );

  Widget _recallActivity() => _panel(
        icon: Icons.lightbulb_outline,
        title: 'Everyday recall',
        subtitle:
            'Self-reported recall · Learn a short list, then remember it.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepLabel(_recallStep == 0 ? 'Step 1 · See' : 'Step 2 · Remember'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xfff5f6f4),
                  borderRadius: BorderRadius.circular(14)),
              child: _StudioText(
                  _showRecallWords
                      ? _words.join('     ·     ')
                      : 'What words do you remember?',
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _studioInk)),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: _seeRecallWords,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const _StudioText('See')),
              FilledButton.icon(
                  onPressed: _beginRecall,
                  icon: const Icon(Icons.psychology_outlined),
                  label: const _StudioText('Remember')),
            ]),
            if (_recallStep > 0) ...[
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('recallInput'),
                controller: _recallController,
                minLines: 1,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Type or say any words you remember',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_outlined)),
                onChanged: (value) => setState(() => _status = value.isEmpty
                    ? 'Take your time. This is only practice.'
                    : 'Response entered for practice.'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _savingTask ? null : _finishRecall,
                icon: const Icon(Icons.check_rounded),
                label: const _StudioText('Finish practice'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  onPressed: _toggleListening,
                  icon: Icon(_isListening
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none),
                  label: _StudioText(
                      _isListening ? 'Stop voice input' : 'Speak your recall')),
            ],
            const SizedBox(height: 8),
            _StudioText(_status,
                style: const TextStyle(color: _studioMuted, height: 1.4)),
          ],
        ),
      );

  void _seeRecallWords() => setState(() {
        _recallStep = 1;
        _showRecallWords = true;
        _status = 'Take a moment to look at the words.';
      });

  void _beginRecall() => setState(() {
        _recallStep = 2;
        _showRecallWords = false;
        _taskStartedAt ??= DateTime.now();
        _taskAttempts = _words.length;
        _status = 'Share any words you remember, then finish the practice.';
      });

  void _finishRecall() {
    final recalled = _recallController.text
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((word) => word.isNotEmpty)
        .toSet();
    final correct =
        _words.where((word) => recalled.contains(word.toLowerCase())).length;
    _taskCorrect = correct;
    _completeTask(
      task: CognitiveTask.memory,
      correct: correct,
      total: _words.length,
      unit: 'words',
    );
  }

  Future<void> _toggleListening() async {
    final voice = VoiceCompanionService.instance;
    if (_isListening) {
      await voice.stopListening();
      if (mounted) {
        setState(() {
          _isListening = false;
          _status = 'Voice input stopped.';
        });
      }
      return;
    }
    final ready = await voice.initialize(onError: (message) {
      if (mounted) _announce('Voice input is unavailable: $message');
    });
    if (!ready) {
      if (mounted) {
        _announce(
            'Voice input is not available on this device. You can type instead.');
      }
      return;
    }
    await voice.configureLanguage(AppLanguage.locale.value.languageCode);
    await voice.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            if (result.recognizedWords.isNotEmpty) {
              _recallController.value = TextEditingValue(
                text: result.recognizedWords,
                selection: TextSelection.collapsed(
                  offset: result.recognizedWords.length,
                ),
              );
            }
            _status = result.recognizedWords.isEmpty
                ? 'Listening. Speak when you are ready.'
                : 'Voice response entered for practice.';
          });
        },
        localeId: AppLanguage.locale.value.languageCode);
    if (mounted) {
      setState(() {
        _isListening = true;
        _status = 'Listening. Tap stop when you are finished.';
      });
    }
  }

  Future<void> _completeTask({
    required CognitiveTask task,
    required int correct,
    required int total,
    required String unit,
  }) async {
    if (_savingTask || total <= 0) return;
    final finishedAt = DateTime.now();
    final elapsed = _taskStartedAt == null
        ? 0
        : finishedAt.difference(_taskStartedAt!).inSeconds;
    final score = (correct * 100 / total).round().clamp(0, 100);
    setState(() {
      _savingTask = true;
      _completionMessage = null;
    });

    try {
      await _dataService.saveCognitiveTaskResult(
        CognitiveTaskResult(
          date: finishedAt,
          task: task,
          score: score,
          timeSeconds: elapsed,
        ),
      );
      final results = await _dataService.getLast30Days();
      if (!mounted) return;
      setState(() {
        _recentResults
          ..clear()
          ..addAll(results);
        _completionMessage =
            'Nice work, Amal! You got $correct of $total $unit. Score: $score. Saved to your 30-day picture.';
        _taskStartedAt = DateTime.now();
        _taskAttempts = 0;
        _taskCorrect = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _completionMessage =
            'Nice work, Amal! You got $correct of $total $unit. Score: $score. Your result could not be saved on this device.';
      });
    } finally {
      if (mounted) setState(() => _savingTask = false);
    }
  }

  Widget _weeklyProgressCard() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final thisWeek = _recentResults
        .where((result) => result.date.isAfter(weekAgo))
        .toList()
      ..sort((left, right) => left.date.compareTo(right.date));
    final memory = thisWeek
        .where((result) => result.task == CognitiveTask.memory)
        .toList();
    final attention = thisWeek
        .where((result) => result.task == CognitiveTask.attention)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff0f5f5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StudioText('Your last 7 days:',
              style: TextStyle(
                  color: _studioInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          if (memory.isEmpty && attention.isEmpty)
            const _StudioText(
                'Complete a practice activity to begin your personal picture.',
                style: TextStyle(color: _studioMuted, height: 1.35))
          else ...[
            if (memory.isNotEmpty) _progressLine('Memory', memory),
            if (attention.isNotEmpty) _progressLine('Focus', attention),
          ],
        ],
      ),
    );
  }

  Widget _progressLine(String label, List<CognitiveTaskResult> results) {
    final first = results.first.score;
    final latest = results.last.score;
    if (results.length == 1) {
      return _StudioText('$label  $latest% recorded',
          style: const TextStyle(color: _studioInk, height: 1.5));
    }
    final indicator = latest > first
        ? '↑'
        : latest < first
            ? '↓'
            : '→';
    return _StudioText('$label  $first → $latest $indicator',
        style: const TextStyle(color: _studioInk, height: 1.5));
  }

  Widget _completionCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xffe6f3f2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StudioText(_completionMessage!,
                style: const TextStyle(color: _studioInk, height: 1.4)),
            if (_completionMessage!
                .contains('Saved to your 30-day picture.')) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReviewSummaryScreen(),
                  ),
                ),
                icon: const Icon(Icons.insights_outlined),
                label: const _StudioText('See my progress'),
              ),
            ],
          ],
        ),
      );

  Widget _progressCard() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.spa_outlined, color: _studioMuted),
            const SizedBox(width: 10),
            Expanded(
                child: _StudioText('Practice status\n$_status',
                    style: const TextStyle(color: _studioInk, height: 1.45))),
            TextButton(
                onPressed: _resetPractice,
                child: const _StudioText('Start over')),
          ],
        ),
      );

  Widget _panel(
          {required IconData icon,
          required String title,
          required String subtitle,
          required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0c24342e),
                  blurRadius: 12,
                  offset: Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: _studioInk, size: 22),
            const SizedBox(width: 9),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _StudioText(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _studioInk)),
                  const SizedBox(height: 3),
                  _StudioText(subtitle,
                      style:
                          const TextStyle(color: _studioMuted, height: 1.35)),
                ])),
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      );

  Widget _stepLabel(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xffe6f3f2),
            borderRadius: BorderRadius.circular(20)),
        child: _StudioText(text,
            style: const TextStyle(
                fontSize: 12, color: _studioInk, fontWeight: FontWeight.w600)),
      );

  void _resetPractice() => setState(() {
        _pianoStep = 0;
        _pianoInput.clear();
        _attentionRound = 0;
        _ruleRound = 0;
        _recallStep = 0;
        _selectedTile = null;
        _showPianoSequence = false;
        _showRecallWords = true;
        _colorRule = true;
        _recallController.clear();
        _status = 'Practice reset. Choose where you would like to begin.';
      });

  void _announce(String message) {
    setState(() => _status = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: _StudioText(message)));
  }

  void _showAccessibilityOptions() => showModalBottomSheet<void>(
        context: context,
        builder: (context) => const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StudioText('Make this comfortable',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _studioInk)),
                  SizedBox(height: 12),
                  ListTile(
                      leading: Icon(Icons.text_fields),
                      title: _StudioText('Larger text'),
                      subtitle:
                          _StudioText('Use your device text-size setting.')),
                  ListTile(
                      leading: Icon(Icons.volume_up_outlined),
                      title: _StudioText('Sound'),
                      subtitle: _StudioText('Use Hear when audio is helpful.')),
                  ListTile(
                      leading: Icon(Icons.people_outline),
                      title: _StudioText('Practice with someone'),
                      subtitle: _StudioText(
                          'A trusted person can help navigate the activities.')),
                ]),
          ),
        ),
      );
}

class _IllustrativeNotice extends StatelessWidget {
  const _IllustrativeNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xffeef2f0),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: const _StudioText(
            'PRACTICE ACTIVITIES · NOT A DIAGNOSTIC ASSESSMENT',
            textAlign: TextAlign.start,
            style: TextStyle(
                fontSize: 10,
                letterSpacing: .25,
                color: _studioMuted,
                fontWeight: FontWeight.w600)),
      );
}

class _StudioText extends StatelessWidget {
  const _StudioText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String data;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => localized.Text(
        data,
        style: style,
        textAlign: textAlign,
      );
}

class _PracticeDisclaimer extends StatelessWidget {
  const _PracticeDisclaimer();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xfff1eee6),
            borderRadius: BorderRadius.circular(13)),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 19, color: _studioMuted),
          SizedBox(width: 9),
          Expanded(
              child: _StudioText(
                  'These activities are for familiarization and practice only. Practice scores are saved locally to your 30-day picture; they are not used to estimate risk. A clinician chooses and interprets any formal assessment.',
                  style: TextStyle(color: _studioMuted, height: 1.4))),
        ]),
      );
}
