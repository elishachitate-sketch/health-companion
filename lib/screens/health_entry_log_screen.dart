import 'package:flutter/material.dart';

import '../models/health_entries.dart';
import '../services/health_entry_repository.dart';
import '../widgets/basira_bottom_navigation.dart';

enum HealthEntryLogKind { mood, dailyFunction, cognitive, lifestyle, chatTone }

class HealthEntryLogScreen extends StatefulWidget {
  const HealthEntryLogScreen({
    super.key,
    required this.kind,
    required this.repositories,
    this.initialCategory,
  });

  final HealthEntryLogKind kind;
  final HealthEntryRepositories repositories;
  final String? initialCategory;

  @override
  State<HealthEntryLogScreen> createState() => _HealthEntryLogScreenState();
}

class _HealthEntryLogScreenState extends State<HealthEntryLogScreen> {
  static const _navy = Color(0xff10244f);
  static const _blue = Color(0xff3679c9);

  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _snippetController = TextEditingController();
  String _mood = 'happy';
  String _category = 'eating';
  String _action = 'water';
  String _tone = 'supportive';
  double _functionValue = 3;
  double _cognitiveScore = 50;
  final _totalQuestionsController = TextEditingController(text: '10');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    const categories = {'eating', 'walking', 'sleep', 'social'};
    if (categories.contains(widget.initialCategory)) {
      _category = widget.initialCategory!;
    }
  }

  String get _title => switch (widget.kind) {
        HealthEntryLogKind.mood => 'Log Mood',
        HealthEntryLogKind.dailyFunction => 'Log Daily Function',
        HealthEntryLogKind.cognitive => 'Log Cognitive Practice',
        HealthEntryLogKind.lifestyle => 'Log Lifestyle Action',
        HealthEntryLogKind.chatTone => 'Log Chat Tone',
      };

  @override
  void dispose() {
    _noteController.dispose();
    _snippetController.dispose();
    _totalQuestionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final timestamp = DateTime.now();
    final id = '${timestamp.microsecondsSinceEpoch}';
    try {
      switch (widget.kind) {
        case HealthEntryLogKind.mood:
          await widget.repositories.moods.addEntry(MoodEntry(
            id: id,
            mood: _mood,
            timestamp: timestamp,
            note: _noteController.text.trim(),
          ));
          break;
        case HealthEntryLogKind.dailyFunction:
          await widget.repositories.dailyFunctions.addEntry(
            DailyFunctionEntry(
              id: id,
              category: _category,
              value: _functionValue.round(),
              timestamp: timestamp,
            ),
          );
          break;
        case HealthEntryLogKind.cognitive:
          await widget.repositories.cognitive.addEntry(CognitiveEntry(
            id: id,
            score: _cognitiveScore.round(),
            totalQuestions: int.parse(_totalQuestionsController.text.trim()),
            timestamp: timestamp,
          ));
          break;
        case HealthEntryLogKind.lifestyle:
          await widget.repositories.lifestyle.addEntry(LifestyleEntry(
            id: id,
            action: _action,
            timestamp: timestamp,
          ));
          break;
        case HealthEntryLogKind.chatTone:
          await widget.repositories.chatTones.addEntry(ChatToneEntry(
            id: id,
            tone: _tone,
            messageSnippet: _snippetController.text.trim(),
            timestamp: timestamp,
          ));
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save this entry. Please retry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xffd9efff),
        bottomNavigationBar: const BasiraBottomNavigation(selectedIndex: 0),
        appBar: AppBar(
          backgroundColor: const Color(0xffd9efff),
          foregroundColor: _navy,
          title: Text(_title),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 24,
                            color: _navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Date and time: ${formatHealthEntryTimestamp(DateTime.now())}',
                          style: const TextStyle(fontSize: 16, color: _navy),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Saved locally on this device. You can delete local entries from your summary.',
                          style: TextStyle(fontSize: 15, color: _navy),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: _formFields(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(58),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save entry'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _formFields() => switch (widget.kind) {
        HealthEntryLogKind.mood => _moodForm(),
        HealthEntryLogKind.dailyFunction => _dailyFunctionForm(),
        HealthEntryLogKind.cognitive => _cognitiveForm(),
        HealthEntryLogKind.lifestyle => _lifestyleForm(),
        HealthEntryLogKind.chatTone => _chatToneForm(),
      };

  Widget _moodForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How are you feeling?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _mood,
            decoration: const InputDecoration(labelText: 'Mood'),
            items: const [
              DropdownMenuItem(value: 'happy', child: Text('Happy')),
              DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
              DropdownMenuItem(value: 'worried', child: Text('Worried')),
              DropdownMenuItem(value: 'tired', child: Text('Tired')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _mood = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );

  Widget _dailyFunctionForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose a daily activity and rate it from 0 to 5.',
              style: TextStyle(fontSize: 17)),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'eating', child: Text('Eating')),
              DropdownMenuItem(value: 'walking', child: Text('Walking')),
              DropdownMenuItem(value: 'sleep', child: Text('Sleep')),
              DropdownMenuItem(value: 'social', child: Text('Social')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 12),
          Text('Your rating: ${_functionValue.round()} / 5'),
          Slider(
            value: _functionValue,
            min: 0,
            max: 5,
            divisions: 5,
            label: '${_functionValue.round()}',
            onChanged: (value) => setState(() => _functionValue = value),
          ),
        ],
      );

  Widget _cognitiveForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Record a practice result only. This is not a validated screening score.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text('Practice score: ${_cognitiveScore.round()} / 100'),
          Slider(
            value: _cognitiveScore,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_cognitiveScore.round()}',
            onChanged: (value) => setState(() => _cognitiveScore = value),
          ),
          TextFormField(
            controller: _totalQuestionsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total questions',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              return parsed == null || parsed <= 0
                  ? 'Enter a number greater than zero.'
                  : null;
            },
          ),
        ],
      );

  Widget _lifestyleForm() => DropdownButtonFormField<String>(
        initialValue: _action,
        decoration: const InputDecoration(labelText: 'Lifestyle action'),
        items: const [
          DropdownMenuItem(value: 'water', child: Text('Water')),
          DropdownMenuItem(value: 'exercise', child: Text('Exercise')),
          DropdownMenuItem(value: 'rest', child: Text('Rest')),
          DropdownMenuItem(value: 'meals', child: Text('Meals')),
          DropdownMenuItem(value: 'prayer', child: Text('Prayer')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _action = value);
        },
      );

  Widget _chatToneForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _tone,
            decoration: const InputDecoration(labelText: 'Chat tone'),
            items: const [
              DropdownMenuItem(value: 'supportive', child: Text('Supportive')),
              DropdownMenuItem(
                  value: 'encouraging', child: Text('Encouraging')),
              DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _tone = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _snippetController,
            maxLength: 180,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Short message snippet',
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Enter a short message snippet.'
                : null,
          ),
        ],
      );
}
