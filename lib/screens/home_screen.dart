import 'package:flutter/material.dart' as material;
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_language.dart';
import '../localization/localized_text.dart' as localized;
import '../localization/translations.dart' as translations;
import 'health_entry_log_screen.dart';
import 'review_summary_screen.dart';
import '../services/health_data.dart';
import '../services/health_entry_repository.dart';
import '../widgets/basira_bottom_navigation.dart';

class HomeScreen extends material.StatefulWidget {
  const HomeScreen({super.key});

  @override
  material.State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends material.State<HomeScreen> {
  static const _teal = material.Color(0xff0e7c7b);
  static const _orange = material.Color(0xfff59e0b);
  static const _ink = material.Color(0xff171b24);
  static const _navy = material.Color(0xff16435a);

  bool _hearingSupport = true;
  bool _visionSupport = true;
  bool _withSomeone = true;
  final _moodNoteController = material.TextEditingController();
  final _stepsController = material.TextEditingController(text: '0');
  final _dataService = DataService.instance;
  int? _selectedMood;
  MoodEntry? _todayMood;
  WalkEntry? _todayWalk;
  material.TimeOfDay? _dailyReminderTime;

  @override
  void initState() {
    super.initState();
    _loadComfortPreferences();
    _loadTodayEntries();
    _loadReminderPreference();
  }

  @override
  void dispose() {
    _moodNoteController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  bool _isToday(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  Future<void> _loadTodayEntries() async {
    try {
      final mood = await _dataService.getLatestMoodEntry();
      final walk = await _dataService.getLatestWalkEntry();
      if (!mounted) return;
      setState(() {
        _todayMood = mood != null && _isToday(mood.date) ? mood : null;
        _todayWalk = walk != null && _isToday(walk.date) ? walk : null;
        if (_todayMood != null) _selectedMood = _todayMood!.score;
        if (_todayWalk != null) _stepsController.text = '${_todayWalk!.steps}';
      });
    } catch (_) {
      // Logging remains available even if reading previous entries fails.
    }
  }

  Future<void> _saveMood() async {
    final score = _selectedMood;
    if (score == null) return;
    final entry = MoodEntry(
      date: DateTime.now(),
      score: score,
      note: _moodNoteController.text.trim(),
    );
    await _dataService.addMoodEntry(entry);
    if (mounted) setState(() => _todayMood = entry);
  }

  Future<void> _saveWalk() async {
    final steps =
        int.tryParse(_stepsController.text.replaceAll(',', '').trim());
    if (steps == null || steps < 0) return;
    final entry = WalkEntry(date: DateTime.now(), steps: steps);
    await _dataService.addWalkEntry(entry);
    if (mounted) setState(() => _todayWalk = entry);
  }

  Future<void> _loadComfortPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hearingSupport = preferences.getBool('comfort_hearing_support') ?? true;
      _visionSupport = preferences.getBool('comfort_vision_support') ?? true;
      _withSomeone =
          preferences.getBool('comfort_continue_with_someone') ?? true;
    });
  }

  Future<void> _loadReminderPreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted ||
        preferences.getBool('in_app_daily_checkin_reminder_enabled') != true) {
      return;
    }
    setState(() {
      _dailyReminderTime = material.TimeOfDay(
        hour: preferences.getInt('in_app_daily_checkin_reminder_hour') ?? 20,
        minute: preferences.getInt('in_app_daily_checkin_reminder_minute') ?? 0,
      );
    });
  }

  Future<void> _configureReminder() async {
    final initialTime =
        _dailyReminderTime ?? const material.TimeOfDay(hour: 20, minute: 0);
    final selectedTime = await material.showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Choose a daily check-in time',
    );
    if (selectedTime == null) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('in_app_daily_checkin_reminder_enabled', true);
    await preferences.setInt(
        'in_app_daily_checkin_reminder_hour', selectedTime.hour);
    await preferences.setInt(
        'in_app_daily_checkin_reminder_minute', selectedTime.minute);
    if (!mounted) return;
    setState(() => _dailyReminderTime = selectedTime);
    material.ScaffoldMessenger.of(context).showSnackBar(
      material.SnackBar(
        content: material.Text(
          'In-app reminder preference saved for ${selectedTime.format(context)}. Notifications are not scheduled by this prototype.',
        ),
      ),
    );
  }

  Future<void> _openSummary() async {
    await material.Navigator.of(context).push(material.MaterialPageRoute<void>(
      builder: (_) => const ReviewSummaryScreen(),
    ));
  }

  Future<void> _openCheckIn(
    HealthEntryLogKind kind, {
    String? category,
  }) async {
    try {
      final repositories = await HealthEntryRepositories.initialize();
      if (!mounted) return;
      await material.Navigator.of(context)
          .push(material.MaterialPageRoute<void>(
        builder: (_) => HealthEntryLogScreen(
          kind: kind,
          repositories: repositories,
          initialCategory: category,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      material.ScaffoldMessenger.of(context).showSnackBar(
        const material.SnackBar(
          content: material.Text('Could not open this check-in right now.'),
        ),
      );
    }
  }

  void _openPractice() {
    material.Navigator.of(context).pushNamed('/studio');
  }

  void _openPlan() {
    material.Navigator.of(context).pushNamed('/tab/2');
  }

  void _openProfile() => material.Navigator.of(context).pushNamed('/tab/4');

  Future<void> _saveComfortPreference(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }

  void _setLanguage(String languageCode) {
    setState(() {});
    AppLanguage.setLanguage(languageCode);
  }

  @override
  material.Widget build(material.BuildContext context) => material.Scaffold(
        backgroundColor: material.Colors.white,
        extendBody: true,
        bottomNavigationBar: const BasiraBottomNavigation(selectedIndex: 0),
        body: material.SafeArea(
          child: material.SingleChildScrollView(
            child: material.Column(
              crossAxisAlignment: material.CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const material.Divider(height: 1),
                const material.SizedBox(height: 14),
                material.Padding(
                  padding: const material.EdgeInsets.symmetric(horizontal: 16),
                  child: material.Column(
                    crossAxisAlignment: material.CrossAxisAlignment.start,
                    children: [
                      material.Center(
                        child: _text(
                          'YOUR CHECK-INS · SAVED ON THIS DEVICE',
                          fontSize: 13,
                          color: const material.Color(0xff656b73),
                        ),
                      ),
                      const material.SizedBox(height: 20),
                      _text(
                        'A clearer picture.\nA healthier tomorrow.',
                        fontSize: 34,
                        weight: material.FontWeight.w800,
                        color: _ink,
                        height: 1.18,
                      ),
                      const material.SizedBox(height: 8),
                      _text(
                        'Brain health starts with understanding you, not just a score.',
                        fontSize: 20,
                        color: _ink,
                        height: 1.3,
                      ),
                      const material.SizedBox(height: 24),
                      _buildTopicCards(),
                      const material.SizedBox(height: 14),
                      _moodLoggerCard(),
                      const material.SizedBox(height: 10),
                      _quickCheckInsCard(),
                      const material.SizedBox(height: 12),
                      _walkLoggerCard(),
                      const material.SizedBox(height: 28),
                      const material.Divider(height: 1),
                      const material.SizedBox(height: 18),
                      material.Center(
                        child: _text(
                          'Choose your language',
                          fontSize: 26,
                          weight: material.FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const material.SizedBox(height: 12),
                      _buildLanguageButtons(),
                      const material.SizedBox(height: 22),
                      material.Center(
                        child: _text(
                          'Make this comfortable',
                          fontSize: 26,
                          weight: material.FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const material.SizedBox(height: 12),
                      _buildComfortCard(
                        icon: material.Icons.hearing_rounded,
                        title: 'Hearing support',
                        subtitle: 'Amplify sound and clarify speech',
                        value: _hearingSupport,
                        color: _teal,
                        onChanged: (value) {
                          setState(() => _hearingSupport = value);
                          _saveComfortPreference(
                              'comfort_hearing_support', value);
                        },
                      ),
                      const material.SizedBox(height: 10),
                      _buildComfortCard(
                        icon: material.Icons.visibility_rounded,
                        title: 'Vision support',
                        subtitle: 'Increase contrast and text size',
                        value: _visionSupport,
                        color: _orange,
                        onChanged: (value) {
                          setState(() => _visionSupport = value);
                          _saveComfortPreference(
                              'comfort_vision_support', value);
                        },
                      ),
                      const material.SizedBox(height: 10),
                      _buildComfortCard(
                        icon: material.Icons.people_alt_outlined,
                        title: 'Continue with someone',
                        subtitle: 'Invite a companion during use',
                        value: _withSomeone,
                        color: _teal,
                        onChanged: (value) {
                          setState(() => _withSomeone = value);
                          _saveComfortPreference(
                              'comfort_continue_with_someone', value);
                        },
                      ),
                      const material.SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  material.Widget _moodLoggerCard() => material.Card(
        elevation: 0,
        color: const material.Color(0xfff7f9f8),
        child: material.Padding(
          padding: const material.EdgeInsets.all(14),
          child: material.Column(
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              _text('Mood logger',
                  fontSize: 18, weight: material.FontWeight.w700, color: _ink),
              const material.SizedBox(height: 10),
              material.Row(
                children: [
                  for (var score = 1; score <= 5; score++)
                    material.Expanded(
                      child: material.InkWell(
                        onTap: () => setState(() => _selectedMood = score),
                        borderRadius: material.BorderRadius.circular(12),
                        child: material.Container(
                          padding: const material.EdgeInsets.symmetric(
                              vertical: 8, horizontal: 2),
                          decoration: material.BoxDecoration(
                            color: _selectedMood == score
                                ? const material.Color(0xffe6f3f2)
                                : material.Colors.transparent,
                            borderRadius: material.BorderRadius.circular(12),
                            border: material.Border.all(
                              color: _selectedMood == score
                                  ? _teal
                                  : material.Colors.transparent,
                            ),
                          ),
                          child: material.Column(
                            children: [
                              _text(
                                ['☹️', '🙁', '😐', '🙂', '😄'][score - 1],
                                fontSize: 22,
                                color: _ink,
                              ),
                              _text('$score', fontSize: 12, color: _ink),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const material.SizedBox(height: 4),
              material.Row(
                children: [
                  for (final label in [
                    'Very Low',
                    'Low',
                    'Okay',
                    'Good',
                    'Great',
                  ])
                    material.Expanded(
                      child: _text(label,
                          fontSize: 9,
                          color: const material.Color(0xff58636d),
                          maxLines: 1),
                    ),
                ],
              ),
              const material.SizedBox(height: 8),
              material.TextField(
                controller: _moodNoteController,
                textAlign: material.TextAlign.start,
                decoration: material.InputDecoration(
                  hintText: translations.AppTranslations.translate(
                    'How are you today?',
                    AppLanguage.locale.value.languageCode,
                  ),
                  border: const material.OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const material.SizedBox(height: 8),
              material.Row(
                children: [
                  material.FilledButton(
                    onPressed: _selectedMood == null ? null : _saveMood,
                    style:
                        material.FilledButton.styleFrom(backgroundColor: _teal),
                    child: _text('Save mood', color: material.Colors.white),
                  ),
                  const material.SizedBox(width: 10),
                  if (_todayMood != null)
                    _text(
                      "Today's mood: ${_todayMood!.score} - Saved",
                      fontSize: 13,
                      weight: material.FontWeight.w600,
                      color: _teal,
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  material.Widget _quickCheckInsCard() => material.Card(
        elevation: 0,
        color: const material.Color(0xfff7f9f8),
        child: material.Padding(
          padding: const material.EdgeInsets.all(14),
          child: material.Column(
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              _text('More check-ins',
                  fontSize: 17, weight: material.FontWeight.w700, color: _ink),
              const material.SizedBox(height: 4),
              _text('Track everyday patterns with a quick rating.',
                  fontSize: 13, color: _navy),
              const material.SizedBox(height: 10),
              material.LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 500 ? 4 : 2;
                const gap = 8.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return material.Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _checkInTile(
                      width,
                      material.Icons.directions_walk_outlined,
                      'Walking',
                      () => _openCheckIn(HealthEntryLogKind.dailyFunction,
                          category: 'walking'),
                    ),
                    _checkInTile(
                      width,
                      material.Icons.restaurant_outlined,
                      'Food',
                      () => _openCheckIn(HealthEntryLogKind.dailyFunction,
                          category: 'eating'),
                    ),
                    _checkInTile(
                      width,
                      material.Icons.bedtime_outlined,
                      'Sleep',
                      () => _openCheckIn(HealthEntryLogKind.dailyFunction,
                          category: 'sleep'),
                    ),
                    _checkInTile(
                      width,
                      material.Icons.people_outline_rounded,
                      'Social',
                      () => _openCheckIn(HealthEntryLogKind.dailyFunction,
                          category: 'social'),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      );

  material.Widget _checkInTile(
    double width,
    material.IconData icon,
    String label,
    material.VoidCallback onTap,
  ) =>
      material.SizedBox(
        width: width,
        child: material.Material(
          color: const material.Color(0xffe6f3f2),
          borderRadius: material.BorderRadius.circular(12),
          child: material.InkWell(
            key: material.ValueKey<String>('home-checkin-$label'),
            onTap: onTap,
            borderRadius: material.BorderRadius.circular(12),
            child: material.Padding(
              padding: const material.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 12),
              child: material.Row(
                children: [
                  material.Icon(icon, color: _teal, size: 20),
                  const material.SizedBox(width: 8),
                  material.Expanded(
                    child: _text(label,
                        fontSize: 14,
                        weight: material.FontWeight.w700,
                        color: _ink,
                        maxLines: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  material.Widget _walkLoggerCard() => material.Card(
        elevation: 0,
        color: const material.Color(0xfff7f9f8),
        child: material.Padding(
          padding: const material.EdgeInsets.all(14),
          child: material.Column(
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              _text('Walking logger',
                  fontSize: 18, weight: material.FontWeight.w700, color: _ink),
              const material.SizedBox(height: 8),
              material.TextField(
                controller: _stepsController,
                keyboardType: const material.TextInputType.numberWithOptions(
                    decimal: false),
                textAlign: material.TextAlign.start,
                decoration: material.InputDecoration(
                  labelText: translations.AppTranslations.translate(
                      'Steps today', AppLanguage.locale.value.languageCode),
                  border: const material.OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const material.SizedBox(height: 8),
              material.Row(
                children: [
                  material.FilledButton(
                    onPressed: _saveWalk,
                    style:
                        material.FilledButton.styleFrom(backgroundColor: _teal),
                    child: _text('Log walk', color: material.Colors.white),
                  ),
                  const material.SizedBox(width: 10),
                  if (_todayWalk != null)
                    _text(
                      'Today: ${_formatSteps(_todayWalk!.steps)} steps - Saved',
                      fontSize: 13,
                      weight: material.FontWeight.w600,
                      color: _teal,
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  String _formatSteps(int steps) => steps.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

  material.Widget _buildHeader() => material.Padding(
        padding: const material.EdgeInsets.symmetric(horizontal: 16)
            .copyWith(bottom: 12),
        child: material.Row(
          children: [
            _text('basira',
                fontSize: 42, weight: material.FontWeight.w800, color: _teal),
            const material.Spacer(),
            material.IconButton(
              onPressed: _configureReminder,
              icon: const material.Icon(
                material.Icons.notifications_none_rounded,
                color: _orange,
                size: 30,
              ),
            ),
            material.IconButton(
              onPressed: _openProfile,
              icon: const material.Icon(
                material.Icons.account_circle_outlined,
                color: _teal,
                size: 34,
              ),
            ),
          ],
        ),
      );

  material.Widget _buildTopicCards() {
    final cards = [
      (
        'Health Summary',
        material.Icons.psychology_outlined,
        _teal,
        _openSummary,
        'View entries saved on this device',
      ),
      (
        'Brain Exercises',
        material.Icons.psychology_alt_outlined,
        _orange,
        _openPractice,
        'Open practice activities',
      ),
      (
        'Sleep',
        material.Icons.nightlight_round,
        _navy,
        _openPlan,
        'Log sleep in My Plan',
      ),
      (
        'Daily Activity',
        material.Icons.directions_walk_rounded,
        _orange,
        _openPlan,
        'Open activity check-in',
      ),
      (
        'Nutrition',
        material.Icons.restaurant_outlined,
        _teal,
        _openPlan,
        'Choose a general wellbeing goal',
      ),
      (
        'Reminders',
        material.Icons.notifications_active_outlined,
        _orange,
        _configureReminder,
        _dailyReminderTime == null
            ? 'Set an in-app reminder preference'
            : 'Daily · ${_dailyReminderTime!.format(context)}',
      ),
    ];

    final width = ((material.MediaQuery.sizeOf(context).width - 48) / 3)
        .clamp(100, 220)
        .toDouble();
    return material.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final card in cards)
          _topicCard(
            card.$1,
            card.$2,
            card.$3,
            card.$4,
            card.$5,
            width,
          ),
      ],
    );
  }

  material.Widget _topicCard(
    String title,
    material.IconData icon,
    material.Color color,
    material.VoidCallback onTap,
    String subtitle,
    double width,
  ) =>
      material.Semantics(
        button: true,
        label: '$title. $subtitle',
        child: material.Material(
          color: color,
          borderRadius: material.BorderRadius.circular(16),
          elevation: 2,
          child: material.InkWell(
            key: material.ValueKey<String>('home-topic-$title'),
            onTap: onTap,
            borderRadius: material.BorderRadius.circular(16),
            child: material.Container(
              width: width,
              height: 112,
              padding: const material.EdgeInsets.all(10),
              child: material.Column(
                crossAxisAlignment: material.CrossAxisAlignment.start,
                children: [
                  material.Icon(icon, color: material.Colors.white, size: 25),
                  const material.Spacer(),
                  _text(
                    title,
                    fontSize: 13,
                    weight: material.FontWeight.w700,
                    color: material.Colors.white,
                    maxLines: 1,
                  ),
                  _text(
                    subtitle,
                    fontSize: 9,
                    color: material.Colors.white,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  material.Widget _buildLanguageButtons() => material.Row(
        children: [
          material.Expanded(
            child: material.FilledButton(
              onPressed: () => _setLanguage('ar'),
              style: material.FilledButton.styleFrom(
                backgroundColor: AppLanguage.locale.value.languageCode == 'ar'
                    ? _teal
                    : material.Colors.white,
                foregroundColor: AppLanguage.locale.value.languageCode == 'ar'
                    ? material.Colors.white
                    : _ink,
                side: const material.BorderSide(color: _teal),
                minimumSize: const material.Size.fromHeight(58),
                shape: material.RoundedRectangleBorder(
                    borderRadius: material.BorderRadius.circular(13)),
              ),
              child: _text('العربية',
                  fontSize: 21, weight: material.FontWeight.w700),
            ),
          ),
          const material.SizedBox(width: 8),
          material.Expanded(
            child: material.OutlinedButton(
              onPressed: () => _setLanguage('en'),
              style: material.OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const material.BorderSide(color: _teal),
                minimumSize: const material.Size.fromHeight(58),
                shape: material.RoundedRectangleBorder(
                    borderRadius: material.BorderRadius.circular(13)),
              ),
              child: _text('English',
                  fontSize: 21, weight: material.FontWeight.w700),
            ),
          ),
        ],
      );

  material.Widget _buildComfortCard({
    required material.IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required material.Color color,
    required material.ValueChanged<bool> onChanged,
  }) =>
      material.Container(
        constraints: const material.BoxConstraints(minHeight: 88),
        padding:
            const material.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: material.BoxDecoration(
          color: const material.Color(0xfffbfcfb),
          border: material.Border.all(color: const material.Color(0xffd5dddd)),
          borderRadius: material.BorderRadius.circular(17),
        ),
        child: material.Row(
          children: [
            material.Container(
              width: 64,
              height: 64,
              decoration: material.BoxDecoration(
                color: color,
                borderRadius: material.BorderRadius.circular(13),
              ),
              child:
                  material.Icon(icon, color: material.Colors.white, size: 34),
            ),
            const material.SizedBox(width: 14),
            material.Expanded(
              child: material.Column(
                crossAxisAlignment: material.CrossAxisAlignment.start,
                mainAxisAlignment: material.MainAxisAlignment.center,
                children: [
                  _text(title,
                      fontSize: 20,
                      weight: material.FontWeight.w700,
                      color: _ink),
                  const material.SizedBox(height: 2),
                  _text(subtitle,
                      fontSize: 14, color: const material.Color(0xff555d65)),
                ],
              ),
            ),
            material.Switch(
              value: value,
              activeTrackColor: color,
              activeThumbColor: material.Colors.white,
              onChanged: onChanged,
            ),
          ],
        ),
      );

  localized.Text _text(
    String value, {
    double fontSize = 16,
    material.FontWeight weight = material.FontWeight.w400,
    material.Color color = _ink,
    double height = 1.2,
    int? maxLines,
  }) =>
      localized.Text(
        value,
        textAlign: material.TextAlign.start,
        maxLines: maxLines,
        style: material.TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
          height: height,
        ),
      );
}
