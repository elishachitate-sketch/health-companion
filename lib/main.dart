import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'localization/app_language.dart';
import 'localization/localized_text.dart';
import 'screens/health_chat_screen.dart';
import 'screens/health_entry_log_screen.dart';
import 'screens/home_screen.dart';
import 'screens/multicognitive_studio_screen.dart';
import 'screens/review_summary_screen.dart';
import 'screens/voice_checkin_screen.dart';
import 'services/health_data.dart';
import 'services/health_entry_repository.dart';
import 'widgets/basira_bottom_navigation.dart';

void main() {
  loadAppLanguage();
  runApp(BasiraApp(clinicianMode: Uri.base.path.startsWith('/clinician')));
}

class BasiraApp extends StatelessWidget {
  const BasiraApp({super.key, this.clinicianMode = false});
  final bool clinicianMode;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.locale,
      builder: (context, locale, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'basira',
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: ThemeData(
                useMaterial3: true,
                fontFamily: 'NotoSans',
                scaffoldBackgroundColor: const Color(0xfff7f8f6),
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xff0e7c7b))),
            builder: (context, child) => Directionality(
              textDirection: locale.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            ),
            onGenerateRoute: (settings) {
              final name = settings.name ?? '';
              if (name == '/studio') {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const FlowScreen(
                    initialPage: 7,
                    initialTab: 1,
                    initialStudio: true,
                  ),
                );
              }
              if (name.startsWith('/tab/')) {
                final index = int.tryParse(name.substring('/tab/'.length));
                if (index != null && index >= 0 && index < 5) {
                  if (index == 3) {
                    return MaterialPageRoute<void>(
                      settings: settings,
                      builder: (_) => const HealthChatScreen(),
                    );
                  }
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => FlowScreen(
                      initialPage: 7,
                      initialTab: index,
                      initialStudio: index == 1,
                    ),
                  );
                }
              }
              return null;
            },
            home:
                clinicianMode ? const ClinicianDashboard() : const HomeScreen(),
          ));
}

// Patient-facing palette: charcoal text, teal actions, mint context cards.
const ink = Color(0xff343a38), cream = Color(0xfff6f3eb);

class ClinicianDashboard extends StatefulWidget {
  const ClinicianDashboard({super.key});
  @override
  State<ClinicianDashboard> createState() => _ClinicianDashboardState();
}

class _ClinicianDashboardState extends State<ClinicianDashboard> {
  int selectedCase = 0;
  bool demoDecisionRecorded = false;
  final _queueKey = GlobalKey();
  final cases = const [
    (
      'Leila, 72',
      'New difficulty with daily tasks',
      'Illustrative review pathway',
      Color(0xffe9d8b5),
      'A fictional report describes needing more help with familiar daily tasks. No validated cognitive measurement is supplied in this example.',
    ),
    (
      'Omar, 68',
      'Hearing concern with auditory task',
      'Context needed',
      Color(0xffd8e7e1),
      'A fictional report notes hearing difficulty during an auditory practice task. Comparable sensory context is unavailable; do not interpret a practice score.',
    ),
    (
      'Sam, 58',
      'Missed visit and context incomplete',
      'No comparison available',
      Color(0xfff1dfbd),
      'A fictional follow-up visit is missing. Change cannot be compared from the information shown; the appropriate demo state is to hold for context.',
    ),
    (
      'Noor, 77',
      'Sudden confusion reported',
      'Urgent guidance example',
      Color(0xfff0c6bd),
      'A fictional scenario describes sudden confusion. This prototype does not monitor emergencies or send a handoff; real users should contact local emergency or clinical services directly.',
    ),
  ];

  void _openReviewQueue() {
    final targetContext = _queueKey.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfff4f5ed),
        body: Row(children: [
          NavigationRail(
              backgroundColor: const Color(0xff142a32),
              extended: MediaQuery.sizeOf(context).width > 900,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              leading: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('basira\nCLINICIAN',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.inbox_outlined),
                    label: Text('Review queue')),
                NavigationRailDestination(
                    icon: Icon(Icons.analytics_outlined),
                    label: Text('Quality & equity')),
                NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: Text('Settings'))
              ]),
          Expanded(
              child: CustomScrollView(slivers: [
            SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xfff4f5ed),
                foregroundColor: ink,
                title: const Text('Brain Health Review Assistant'),
                actions: [
                  const Chip(label: Text('Synthetic demo · not signed in')),
                  const SizedBox(width: 16)
                ]),
            SliverPadding(
                padding: const EdgeInsets.all(28),
                sliver: SliverList(
                    delegate: SliverChildListDelegate([
                  Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                          color: const Color(0xff142a32),
                          borderRadius: BorderRadius.circular(24)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SYNTHETIC DEMO DATA · REVIEW QUEUE',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff9bf33b),
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            const Text('A clearer picture.',
                                style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const Text('A human-led review.',
                                style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xff9bf33b))),
                            const SizedBox(height: 10),
                            const Text(
                                'All names, cases and counts below are fictional examples. This dashboard is not connected to a live clinical service.',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                                onPressed: _openReviewQueue,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Browse fictional scenarios'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xff9bf33b),
                                    foregroundColor: const Color(0xff142a32)))
                          ])),
                  const SizedBox(height: 24),
                  _metrics(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                      builder: (_, c) => c.maxWidth > 760
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Expanded(child: _queue()),
                                  const SizedBox(width: 20),
                                  Expanded(child: _caseDetail())
                                ])
                          : Column(children: [
                              _queue(),
                              const SizedBox(height: 20),
                              _caseDetail()
                            ])),
                  const SizedBox(height: 24),
                  _workflow(),
                  const SizedBox(height: 24),
                  _audit(),
                ]))),
          ])),
        ]),
      );
  Widget _metrics() => Wrap(spacing: 12, runSpacing: 12, children: [
        _metric('4', 'Fictional scenarios'),
        _metric('0', 'Validated assessments'),
        _metric('0', 'Live clinical integrations'),
        _metric('12', 'Proposed workflow stages'),
      ]);

  Widget _metric(String value, String label) => Container(
        width: 190,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffe0e6e5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 25, color: ink, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label)
        ]),
      );
  Widget _queue() => _panel(
      'Synthetic scenario list',
      Column(children: [
        for (var i = 0; i < cases.length; i++)
          Material(
            color: Colors.transparent,
            child: ListTile(
                onTap: () => setState(() {
                      selectedCase = i;
                      demoDecisionRecorded = false;
                    }),
                selected: selectedCase == i,
                selectedTileColor: const Color(0xffe4f0eb),
                title: Text(cases[i].$1,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(cases[i].$2),
                trailing: Chip(
                    label:
                        Text(cases[i].$3, style: const TextStyle(fontSize: 11)),
                    backgroundColor: cases[i].$4)),
          )
      ]),
      key: _queueKey);
  Future<void> _recordDemoDecision() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Record a demo-only action?'),
            content: const Text(
                'This changes only the local demonstration state. It is not authenticated clinician review, approval, a referral, or a notification.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Record demo action'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) setState(() => demoDecisionRecorded = true);
  }

  Widget _caseDetail() {
    final item = cases[selectedCase];
    return _panel(
        'Case review · ${item.$1}',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.$2,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          const Text('Scenario notes · fictional',
              style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(item.$5),
          const SizedBox(height: 14),
          const Text('Data provenance and limits',
              style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
          const Text(
              'Source: synthetic scenario text. No patient record, validated assessment, connected risk data, or computed clinical score is present.'),
          const SizedBox(height: 14),
          Text(demoDecisionRecorded
              ? 'Demo action recorded locally · no real review or care action occurred.'
              : 'Workflow state: example awaiting human review. No real review queue is connected.'),
          const SizedBox(height: 14),
          FilledButton(
              onPressed: demoDecisionRecorded ? null : _recordDemoDecision,
              style: FilledButton.styleFrom(backgroundColor: ink),
              child: Text(demoDecisionRecorded
                  ? 'Demo action recorded'
                  : 'Simulate review action'))
        ]));
  }

  Widget _workflow() => _panel(
      'Proposed visit workflow · 12 stages · not executed',
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final stage in [
          'Consent & access',
          'Safety triage',
          'Clinical context',
          'Accessibility',
          'Assessment protocol',
          'Cognitive change scoring',
          'Care pathway',
          'Specialist liaison',
          'Evidence & documentation',
          'Clinician review · human',
          'Follow-up coordination',
          'Quality & equity audit'
        ])
          Chip(
              label: Text(stage),
              avatar: Icon(
                  stage.contains('Clinician')
                      ? Icons.person
                      : Icons.radio_button_unchecked,
                  size: 16),
              backgroundColor: stage.contains('Clinician')
                  ? const Color(0xffd9d0f3)
                  : const Color(0xffeef0ef))
      ]));
  Widget _audit() => _panel(
      'Quality & equity audit',
      const Text(
          'Evaluation plan only; this prototype has no measured clinical performance or subgroup results. A future, approved study should assess completion, test–retest reliability, sensitivity, specificity, meaningful-change detection, false-referral burden and time to assessment across relevant language, age and education groups. Reference labels must come from an independent qualified assessment.'));
  Widget _panel(String title, Widget child, {Key? key}) => Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: ink)),
        const SizedBox(height: 14),
        child
      ]));
}

class FlowScreen extends StatefulWidget {
  const FlowScreen({
    super.key,
    this.initialPage = 0,
    this.initialTab = 0,
    this.initialStudio = false,
  });

  final int initialPage;
  final int initialTab;
  final bool initialStudio;

  @override
  State<FlowScreen> createState() => _FlowState();
}

class _FlowState extends State<FlowScreen> {
  late int page, tab;
  late bool studioOpen;
  bool _careFromProfile = false;
  String _language = 'en';
  bool _hearingSupport = true;
  bool _visionSupport = true;
  bool _continueWithSomeone = false;
  final _dataService = DataService.instance;
  double _sleepHours = 7;
  String _sleepQuality = 'Good';
  SleepEntry? _latestSleepEntry;
  PreventionPlanEntry? _latestPlan;
  TimeOfDay? _reminderTime;
  int _supportLevel = 1;
  FunctionalEntry? _latestFunctionalEntry;
  final selectedGoals = <String>{};

  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
    tab = widget.initialTab;
    studioOpen = widget.initialStudio || widget.initialTab == 1;
    _loadPreferences();
    _loadSleepEntry();
    _loadPreventionPlan();
    _loadFunctionalEntry();
  }

  Future<void> _loadSleepEntry() async {
    try {
      final entry = await _dataService.getLatestSleepEntry();
      if (!mounted || entry == null) return;
      setState(() {
        _latestSleepEntry = entry;
        _sleepHours = entry.hours.clamp(4, 10).toDouble();
        _sleepQuality = entry.quality;
      });
    } catch (_) {
      // Sleep can still be logged if reading prior data fails.
    }
  }

  Future<void> _saveSleepEntry() async {
    final entry = SleepEntry(
      date: DateTime.now(),
      hours: _sleepHours,
      quality: _sleepQuality,
    );
    await _dataService.addSleepEntry(entry);
    if (mounted) setState(() => _latestSleepEntry = entry);
  }

  Future<void> _loadPreventionPlan() async {
    try {
      final entry = await _dataService.getLatestPreventionPlan();
      if (!mounted || entry == null) return;
      setState(() {
        _latestPlan = entry;
        selectedGoals
          ..clear()
          ..addAll(entry.actions);
      });
    } catch (_) {
      // The plan remains editable if local history cannot be read.
    }
  }

  Future<void> _savePreventionPlan() async {
    final entry = PreventionPlanEntry(
      date: DateTime.now(),
      actions: List.unmodifiable(selectedGoals),
    );
    await _dataService.savePreventionPlan(entry);
    if (mounted) setState(() => _latestPlan = entry);
  }

  Future<void> _openPlanLog(
    HealthEntryLogKind kind, {
    String? category,
  }) async {
    try {
      final repositories = await HealthEntryRepositories.initialize();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HealthEntryLogScreen(
          kind: kind,
          repositories: repositories,
          initialCategory: category,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the check-in right now.')),
      );
    }
  }

  Future<void> _openPlanSummary() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const ReviewSummaryScreen(),
    ));
  }

  Future<void> _loadFunctionalEntry() async {
    try {
      final snapshot = await _dataService.getReviewSnapshot();
      final entry = snapshot.functionalEntries.isEmpty
          ? null
          : snapshot.functionalEntries.last;
      if (!mounted || entry == null) return;
      final now = DateTime.now();
      final date = entry.date.toLocal();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        setState(() {
          _latestFunctionalEntry = entry;
          _supportLevel = entry.supportLevel;
        });
      }
    } catch (_) {
      // Function check-in remains available if old entries cannot be read.
    }
  }

  Future<void> _saveFunctionalEntry() async {
    final entry =
        FunctionalEntry(date: DateTime.now(), supportLevel: _supportLevel);
    await _dataService.addFunctionalEntry(entry);
    if (mounted) setState(() => _latestFunctionalEntry = entry);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final savedLanguage = prefs.getString('appLanguage') ??
          prefs.getString('consent_profile_language') ??
          'en';
      _language = savedLanguage.toLowerCase().startsWith('ar') ? 'ar' : 'en';
      AppLanguage.locale.value = Locale(_language);
      _hearingSupport = prefs.getBool('comfort_hearing_support') ?? true;
      _visionSupport = prefs.getBool('comfort_vision_support') ?? true;
      _continueWithSomeone =
          prefs.getBool('comfort_continue_with_someone') ?? false;
      if (prefs.getBool('in_app_daily_checkin_reminder_enabled') == true) {
        _reminderTime = TimeOfDay(
          hour: prefs.getInt('in_app_daily_checkin_reminder_hour') ?? 20,
          minute: prefs.getInt('in_app_daily_checkin_reminder_minute') ?? 0,
        );
      }
    });
  }

  Future<void> _chooseDailyReminderTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 20, minute: 0),
      helpText: 'Choose a daily check-in time',
    );
    if (selectedTime == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('in_app_daily_checkin_reminder_enabled', true);
    await prefs.setInt('in_app_daily_checkin_reminder_hour', selectedTime.hour);
    await prefs.setInt(
        'in_app_daily_checkin_reminder_minute', selectedTime.minute);
    if (mounted) setState(() => _reminderTime = selectedTime);
  }

  Future<void> _savePreference(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  void next() => setState(() => page = (page + 1).clamp(0, 6));
  void goTab(int i) {
    if (i == 3) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const HealthChatScreen(),
      ));
      return;
    }
    setState(() {
      tab = i;
      page = 7;
      studioOpen = i == 1;
      _careFromProfile = false;
    });
  }

  void openStudio() => setState(() {
        tab = 1;
        page = 7;
        studioOpen = true;
      });
  final data = const [
    [
      'Brain health, on your terms.',
      'A little context today can help you notice meaningful changes over time.',
      'Choose your language',
      'English     ✓\n\nالعربية',
      'Save preferences & continue'
    ],
    [
      'More than a moment in time.',
      'Welcome. Memory, your everyday experience matters alongside any assessment.',
      'Small changes deserve context.',
      'Look at patterns together, not a single brain-health score.',
      'Prepare for a check-in'
    ],
    [
      'Let’s start with your context.',
      'There is no test on this screen. These details help a clinician choose an appropriate assessment route.',
      'Language & learning',
      'Preferred assessment language\n\nArabic · Emirati dialect\n\nEducation and learning background\n\nSecondary school\n\nHow are you feeling today?\n\nA little worried\n\nSleep last night\n\nAbout 5 hours · interrupted',
      'Save & discuss assessment options'
    ],
    [
      'One picture. Different sources.',
      'Your health information belongs in context. See where each detail comes from and what is still missing.',
      'Physical & metabolic health',
      'BP 138/82 mmHg · HbA1c 6.0%. Review alongside your clinical history.\n\nSleep\n5–6 hours most nights; often interrupted.\n\nMental wellbeing\nFeeling worried lately; not yet discussed with a professional.\n\nFamily history\nMother had memory difficulties in later life.',
      'Review or update my information'
    ],
    [
      'A change to explore, not a conclusion.',
      'June–September 2024 · 4 example check-ins. These are your observations, not diagnostic findings.',
      'Effort you have reported',
      'Thinking & memory     Daily function\n\n━━━━━━━━━━━━━━━━\nJul          Aug          Sep\n\nWhat we can observe\nYour August and September check-ins described effort finding words.\n\nWhat may influence this\nInterrupted sleep · Hearing and language · Worry and familiarity',
      'Prepare a primary-care review'
    ],
    [
      'Small steps, shaped around you.',
      'Based on your sleep, walking routine and what matters to you. Choose what feels manageable.',
      'What matters to you',
      '“Staying independent and connected to my family.”\n\nMove in a way you enjoy\nRegular movement supports overall and brain health.\n\nMake room for rest\nA steadier routine may help persistent difficulties.\n\nNourish & connect\nBalanced meals and meaningful social time support wellbeing.',
      'Save my chosen steps'
    ],
    [
      'Your context, ready for care.',
      'Prepare a summary for a primary-care clinician. You decide what to include and when to share it.',
      'Awaiting clinical review',
      'No clinician has reviewed this example summary. No diagnosis, investigation, or referral has been decided.\n\nChoose what to include\nChanges over time ✓\nHealth and check-in context ✓\nYour prevention goals ✓\nFamily history',
      'Preview my review summary'
    ],
  ];
  @override
  Widget build(BuildContext context) => page < 7
      ? Scaffold(
          body: SafeArea(child: _onboarding()),
          bottomNavigationBar: _nav(),
        )
      : Scaffold(
          body: SafeArea(child: studioOpen ? _studio() : _app()),
          bottomNavigationBar: _nav(),
        );
  Widget _onboarding() {
    final pages = [
      _welcomePage(),
      _checkInPage(),
      _picturePage(),
      _changePage(),
      _contextPage(),
      _planPage(),
      _carePage()
    ];
    return Column(children: [
      _top(),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
            Text(
                '${(page + 1).toString().padLeft(2, '0')} / ${[
                  'GET COMFORTABLE',
                  'A BRIEF CHECK-IN',
                  'YOUR PERSONAL PICTURE',
                  'WHAT HAS CHANGED',
                  'CONNECT THE CONTEXT',
                  'SMALL STEPS THAT MATTER',
                  'CONNECTED TO CARE'
                ][page]}',
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xff0e7c7b),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            pages[page],
            const SizedBox(height: 18),
            FilledButton(
                onPressed: next,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff0e7c7b),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text([
                  'Set up my check-in',
                  'Continue',
                  'See my personal picture',
                  'Review my context',
                  'Connect my sources',
                  'Check in on my goals',
                  'Preview my review summary'
                ][page])),
            if (page == 0) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: () => setState(() => page = 7),
                  child: const Text('Prefer support? Ask a care navigator'))
            ]
          ]))
    ]);
  }

  Widget _headline(String title, String body) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 29,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: ink)),
        const SizedBox(height: 10),
        Text(body,
            style: const TextStyle(color: Color(0xff52605e), height: 1.35))
      ]);
  Widget _welcomePage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headline('A clearer picture.\nA healthier tomorrow.',
            'Brain health starts with understanding you, not just a score.'),
        const SizedBox(height: 18),
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/images/reference-flow.jpg',
                height: 145,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter)),
        const SizedBox(height: 18),
        _softCard(
            'Choose your language',
            Row(children: [
              _choice('English', _language == 'en', () {
                setState(() => _language = 'en');
                AppLanguage.setLanguage('en');
              }),
              const SizedBox(width: 8),
              _choice('العربية', _language == 'ar', () {
                setState(() => _language = 'ar');
                AppLanguage.setLanguage('ar');
              }),
            ])),
        const SizedBox(height: 12),
        _softCard(
            'Make this comfortable',
            Column(children: [
              _toggle('Hearing support', _hearingSupport, (value) {
                setState(() => _hearingSupport = value);
                _savePreference('comfort_hearing_support', value);
              }),
              _toggle('Vision support', _visionSupport, (value) {
                setState(() => _visionSupport = value);
                _savePreference('comfort_vision_support', value);
              }),
              _toggle('Continue with someone', _continueWithSomeone, (value) {
                setState(() => _continueWithSomeone = value);
                _savePreference('comfort_continue_with_someone', value);
              }),
            ]))
      ]);
  Widget _checkInPage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headline(
            'In the past 4 weeks, have you needed more help with daily tasks?',
            'Think about medicines, shopping or appointments you usually manage.'),
        const SizedBox(height: 16),
        for (final option in [
          'As independently as usual',
          'A little more help than usual',
          'Much more help than usual',
          'This is not part of my routine'
        ])
          _radio(option, option.startsWith('A little')),
        const SizedBox(height: 8),
        _softCard(
            'A signal, not a diagnosis',
            const Text(
                'Poor sleep, stress, hearing or vision can affect daily function. You can add this context before finishing.'))
      ]);
  Widget _picturePage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headline('Good morning, Amal.',
            'Your story over time matters more than a single score.'),
        const SizedBox(height: 16),
        _mintCard('Review recommended', 'A change deserves a conversation.',
            'Your navigator is arranging a review.'),
        const SizedBox(height: 14),
        const Text(
            'Your starting point                                      7 of 9 domains',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _mini('Cognition', 'Within usual range'),
          _mini('Daily function', 'More help reported'),
          _mini('Physical', 'Not recorded'),
          _mini('Metabolic', 'BP review'),
          _mini('Sleep', '5.5 h / night'),
          _mini('Wellbeing', 'More strain lately')
        ])
      ]);
  Widget _changePage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headline('A change worth looking into.',
            'Compared with your own starting point, not someone else’s.'),
        const SizedBox(height: 16),
        _softCard(
            'Increased risk · review recommended',
            const Text(
                'A screening signal, not a diagnosis or a prediction of dementia.')),
        const SizedBox(height: 12),
        _mintCard(
            'Daily function',
            'Your reported support needs changed over 4 check-ins.',
            '2 → 2 → 3 → 6 days'),
        const SizedBox(height: 12),
        _softCard(
            'How certain is this signal?',
            const Text(
                'Moderate. Sleep, mood, hearing and missing baseline data can affect interpretation.'))
      ]);
  Widget _contextPage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headline('One picture.\nMany parts of you.',
            'See what is connected, what is missing and where each finding comes from.'),
        const SizedBox(height: 16),
        _mintCard(
            '2 connections active', 'Wearable + home BP', 'Manage sharing →'),
        _contextTile('Cognition', 'Within usual range'),
        _contextTile('Daily function', 'Extra help on 6 of 28 days'),
        _contextTile('Physical capacity', 'No movement baseline yet'),
        _contextTile('Metabolic health', 'Home BP average 146/88'),
        _contextTile('Sleep', '5.5 h / night'),
        _contextTile('Family history', 'Mother had difficulties after 75')
      ]);
  Widget _planPage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headline('Your plan.\nAt your pace.',
            'Focus on what you can influence, with support for what you can’t.'),
        const SizedBox(height: 16),
        _contextTile('MOVEMENT',
            'A little movement, together\nTry a comfortable 10-minute walk.'),
        _contextTile('SLEEP',
            'Give evenings a softer landing\nAim for 4 evenings / week.'),
        _contextTile('BLOOD PRESSURE',
            'Bring a clear BP picture\nReview with your care team.'),
        _mintCard(
            'Together again · 18 Nov',
            'Review sleep, daily needs and BP together.',
            'Keep the check-in simple.')
      ]);

  Widget _planAction(
    double width,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) =>
      SizedBox(
        width: width,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xff0e7c7b), size: 23),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: ink, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xff67706e), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  Widget _carePage() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headline('A next step.\nAnd someone with you.',
            'Your referral stays open until the outcome is reviewed and a next action is agreed.'),
        const SizedBox(height: 16),
        _softCard(
            'A check-in was missed',
            const Text(
                'Your navigator has been notified and will contact you.')),
        _mintCard('Your next appointment', '11 Nov · 10:30 AM',
            'Primary-care review · Community clinic · Abu Dhabi'),
        _contextTile('Your care, step by step',
            'Recommendation · Appointment · Attendance · Outcome review'),
        _softCard(
            'Mariam · your care navigator',
            const Text(
                'A trusted person can join you. Your context stays your choice.'))
      ]);
  Widget _softCard(String title, Widget child) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, color: ink)),
            const SizedBox(height: 8),
            child
          ])));
  Widget _mintCard(String title, String body, String footer) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xffe4f0eb),
          borderRadius: BorderRadius.circular(15)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: ink)),
        const SizedBox(height: 7),
        Text(body,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.bold, color: ink)),
        const SizedBox(height: 7),
        Text(footer)
      ]));
  Widget _contextTile(String title, String body) => Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        const Icon(Icons.eco_outlined, color: ink, size: 19),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontSize: 12, color: Color(0xff67706e))),
          Text(body,
              style: const TextStyle(fontWeight: FontWeight.w600, color: ink))
        ]))
      ]));
  Widget _mini(String title, String body) => Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text('$title\n$body', style: const TextStyle(height: 1.35)));
  Widget _choice(String label, bool active, VoidCallback onTap) => Expanded(
      child: Semantics(
          button: true,
          selected: active,
          child: Material(
              color: active ? const Color(0xffe6f3f2) : const Color(0xfff5f5f2),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: active
                                  ? const Color(0xff0e7c7b)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(label)))))));
  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: value,
          onChanged: onChanged,
          title: Text(label),
          activeThumbColor: ink);
  Widget _radio(String label, bool selected) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: selected ? const Color(0xffe6f3f2) : Colors.white,
          border: Border.all(
              color: selected ? const Color(0xff0e7c7b) : Colors.transparent),
          borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? const Color(0xff0e7c7b) : Colors.grey),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600))
      ]));

  Widget _app() {
    if (tab == 0) return _overview();
    if (tab == 1) return _studio();
    if (tab == 2) return _plan();
    if (tab == 3) return _chatLanding();
    return _careFromProfile ? _care() : _profile();
    /* final bodies = [
      [
        'Your recent pattern',
        'Thinking & memory · Daily function\n\n━━━━━━━━━━━━━━━━\nIllustrative self-reports, not a test score.',
        'What you have noticed',
        'Everyday activities\nCooking, shopping and managing appointments remain independent.',
        'A pattern is not a diagnosis',
        'Your sleep, mood, language and sensory needs can affect what you notice.'
      ],
      [
        'Physical & metabolic health',
        'BP 138/82 mmHg · HbA1c 6.0%. Review alongside your clinical history.',
        'Sleep',
        '5–6 hours most nights; often interrupted.',
        'Mental wellbeing',
        'Feeling worried lately; not yet discussed with a professional.',
        'Family history',
        'Mother had memory difficulties in later life.'
      ],
      [
        'What matters to you',
        '“Staying independent and connected to my family.”',
        'Move in a way you enjoy',
        'Regular movement supports overall and brain health.',
        'Make room for rest',
        'A steadier routine may help persistent difficulties.',
        'Nourish & connect',
        'Balanced meals and meaningful social time support wellbeing.'
      ],
      [
        'An AI guide, not a clinician',
        'Helps you reflect and navigate care. It cannot diagnose cognitive impairment, interpret genomics or replace a clinician.',
        'Illustrative conversation',
        'You: I’ve been misplacing my keys and missed an appointment.\n\nBasira AI: That can feel unsettling. Thank you for sharing that.',
        'Message Basira AI',
        'Write your message…'
      ],
      [
        'Awaiting clinical review',
        'No clinician has reviewed this example summary. No diagnosis, investigation, or referral has been decided.',
        'Choose what to include',
        'Changes over time ✓\nHealth and check-in context ✓\nYour prevention goals ✓\nFamily history',
        'Sharing stays your choice',
        'Preview, share, or keep this summary private.'
      ],
    ];
    final items = bodies[tab];
    return Column(children: [
      _top(),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(18), children: [
        Text(headings[tab],
            style: const TextStyle(
                fontSize: 10, color: ink, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(titles[tab],
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 10),
        Text(tab == 3
            ? 'Reflect on changes you notice and prepare for a conversation about care.'
            : 'Choose what to include and when to share it.'),
        const SizedBox(height: 18),
        for (var i = 0; i < items.length; i += 2) ...[
          _Card(items[i], items[i + 1]),
          const SizedBox(height: 12)
        ],
        if (tab == 3) ...[
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () {}, child: const Text('Text'))),
            const SizedBox(width: 8),
            Expanded(
                child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xff0e7c7b)),
                    child: const Text('Voice')))
          ]),
          const SizedBox(height: 12),
          _Card('Basira AI · voice conversation',
              'Not listening\n\nMicrophone off. Tap start voice conversation when you are ready.'),
          FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff0e7c7b)),
              child: const Text('Start voice conversation'))
        ] else
          FilledButton(
              onPressed: () => setState(() => page = 0),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff0e7c7b)),
              child: Text(tab == 4
                  ? 'Preview my review summary'
                  : 'Review my health profile'))
      ]))
    ]); */
  }

  Widget _chatLanding() =>
      _shell('BASIRA AI · CHAT', 'Talk at your own pace.', [
        const Text(
            'Reflect on changes you notice and prepare for a conversation about care.'),
        const SizedBox(height: 18),
        const _Card('An AI guide, not a clinician',
            'Basira can help you reflect, organize context and navigate next steps. It cannot diagnose or replace professional care.'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HealthChatScreen())),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open Basira AI chat'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff0e7c7b),
                minimumSize: const Size.fromHeight(50))),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HealthChatScreen())),
            icon: const Icon(Icons.mic_none),
            label: const Text('Start voice conversation'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VoiceCheckInScreen())),
            icon: const Icon(Icons.mic_none_rounded),
            label: const Text('Start private voice check-in'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50))),
        const SizedBox(height: 12),
        const _Card('Safety first',
            'If you notice sudden confusion, feel unsafe or symptoms are rapidly worsening, contact emergency services or a trusted person immediately.'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => setState(() => studioOpen = true),
            icon: const Icon(Icons.piano_outlined),
            label: const Text('Open Multicognitive Studio'),
            style: FilledButton.styleFrom(
                backgroundColor: ink, minimumSize: const Size.fromHeight(50))),
      ]);

  Widget _studio() => Column(children: [
        const Expanded(
            child: MulticognitiveStudioScreen(showBottomNavigation: false)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => goTab(0),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Basira'),
            ),
          ),
        ),
      ]);
  Widget _shell(String heading, String title, List<Widget> children) {
    return Column(
      children: [
        _top(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(heading,
                  style: const TextStyle(
                      fontSize: 10, color: ink, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ],
    );
  }

  Widget _overview() => _shell('OVERVIEW', 'A little space to notice.', [
        const _Card('Your saved check-ins',
            'Review only the sleep, walking, mood, cognitive practice, chat tone and voice check-ins you have recorded on this device. These entries are not a diagnosis.'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReviewSummaryScreen())),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Open my health summary'),
            style: FilledButton.styleFrom(backgroundColor: ink)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: openStudio,
            icon: const Icon(Icons.piano_outlined),
            label: const Text('Try a practice activity'),
            style: FilledButton.styleFrom(backgroundColor: ink)),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: () => goTab(3),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff0e7c7b)),
            child: const Text('Talk through this with Basira')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ClinicianDashboard(),
          )),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Explore synthetic clinician review demo'),
        ),
      ]);
  Widget _profile() =>
      _shell('PROFILE · CONTEXT', 'One picture. Different sources.', [
        _Card(
          'Language and accessibility',
          'Selected language: ${_language == 'ar' ? 'Arabic' : 'English'}\nHearing support: ${_hearingSupport ? 'On' : 'Off'} · Vision support: ${_visionSupport ? 'On' : 'Off'}',
        ),
        const SizedBox(height: 12),
        const _Card(
          'Connected information sources',
          'This prototype currently reads only entries you record in the app. It is not connected to clinical records, wearables, blood pressure, laboratory results, family history or genomic services.',
        ),
        const SizedBox(height: 12),
        const _Card(
          'Personal and family context',
          'No family-history or genomic information has been entered or inferred.',
        ),
        const SizedBox(height: 12),
        const _Card(
          'Interpretation limits',
          'These check-ins and practice activities are descriptive. They are not validated to identify clinically meaningful change or to estimate an individual risk.',
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReviewSummaryScreen())),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Review my saved entries'),
            style: FilledButton.styleFrom(backgroundColor: ink)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _careFromProfile = true),
          icon: const Icon(Icons.favorite_outline),
          label: const Text('Care and support information'),
        ),
        const SizedBox(height: 8),
        const _Card(
          'Wearables and clinical records',
          'No wearable, blood-pressure, metabolic or clinical-record connection is active in this prototype.',
        ),
      ]);
  Widget _plan() =>
      _shell('MY PLAN · CHECK-INS', 'Small steps, shaped around you.', [
        const Text(
            'Log sleep and daily function, then save goals you choose. This is self-directed tracking—not a personalized clinical prescription.'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: const Color(0xfff7f9f8),
          child: ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Daily check-in reminder'),
            subtitle: Text(_reminderTime == null
                ? 'No reminder preference set. Notifications are not scheduled by this prototype.'
                : 'Preference: ${_reminderTime!.format(context)}. Notifications are not scheduled by this prototype.'),
            trailing: TextButton(
              onPressed: _chooseDailyReminderTime,
              child: Text(_reminderTime == null ? 'Set time' : 'Change'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _sleepLogger(),
        const SizedBox(height: 12),
        _functionalLogger(),
        const SizedBox(height: 18),
        const Text('Mood and daily wellbeing',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 4),
        const Text(
            'Add a check-in here, then review your mood trend and distribution in the summary.',
            style: TextStyle(color: Color(0xff67706e), height: 1.4)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _planAction(
                itemWidth,
                Icons.mood_outlined,
                'Mood check-in',
                'Log how you feel',
                () => _openPlanLog(HealthEntryLogKind.mood),
              ),
              _planAction(
                itemWidth,
                Icons.directions_walk_outlined,
                'Walking',
                'Rate today’s walking',
                () => _openPlanLog(HealthEntryLogKind.dailyFunction,
                    category: 'walking'),
              ),
              _planAction(
                itemWidth,
                Icons.restaurant_outlined,
                'Food & eating',
                'Rate eating today',
                () => _openPlanLog(HealthEntryLogKind.dailyFunction,
                    category: 'eating'),
              ),
              _planAction(
                itemWidth,
                Icons.people_outline_rounded,
                'Social connection',
                'Rate social activity',
                () => _openPlanLog(HealthEntryLogKind.dailyFunction,
                    category: 'social'),
              ),
              _planAction(
                itemWidth,
                Icons.spa_outlined,
                'Lifestyle action',
                'Log water, rest, or activity',
                () => _openPlanLog(HealthEntryLogKind.lifestyle),
              ),
            ],
          );
        }),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openPlanSummary,
            icon: const Icon(Icons.insights_outlined),
            label: const Text('View mood trend & distribution'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff0e7c7b),
              side: const BorderSide(color: Color(0xff0e7c7b)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final goal in [
          'Sleep routine',
          'Move with someone',
          'Review blood pressure',
          'Stay socially connected'
        ])
          CheckboxListTile(
              value: selectedGoals.contains(goal),
              onChanged: (v) => setState(() => v == true
                  ? selectedGoals.add(goal)
                  : selectedGoals.remove(goal)),
              title: Text(goal),
              subtitle: Text(goal == 'Review blood pressure'
                  ? 'Bring a clear home-monitoring record to your review.'
                  : 'A small, repeatable action for this week.'),
              activeColor: ink,
              contentPadding: EdgeInsets.zero),
        _Card(
            'Your selected actions',
            selectedGoals.isEmpty
                ? 'No actions selected yet. These general wellbeing options are not a personalized prescription.'
                : '${selectedGoals.length} general action(s) selected${_latestPlan == null ? '' : ' · saved ${_formatLocalDate(_latestPlan!.date)}'}. Review what feels suitable with your care team.'),
        const SizedBox(height: 12),
        FilledButton(
            onPressed: _savePreventionPlan,
            style: FilledButton.styleFrom(backgroundColor: ink),
            child: const Text('Save my chosen steps')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReviewSummaryScreen())),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Review my saved health data')),
      ]);

  Widget _functionalLogger() => Card(
        elevation: 0,
        color: const Color(0xfff7f9f8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily function check-in',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                  'Self-report only · Compare with your own entries; not a validated assessment.'),
              const SizedBox(height: 10),
              for (var level = 1; level <= 3; level++)
                RadioListTile<int>(
                  value: level,
                  groupValue: _supportLevel,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xff0e7c7b),
                  title: Text([
                    'Managed usual daily tasks independently',
                    'Needed some more help than usual',
                    'Needed much more help than usual',
                  ][level - 1]),
                  onChanged: (value) {
                    if (value != null) setState(() => _supportLevel = value);
                  },
                ),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saveFunctionalEntry,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff0e7c7b)),
                    child: const Text('Save daily check-in'),
                  ),
                  if (_latestFunctionalEntry != null) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Today’s daily-function entry is saved.',
                          style: TextStyle(
                              color: Color(0xff0e7c7b), fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );

  Widget _sleepLogger() => Card(
        elevation: 0,
        color: const Color(0xfff7f9f8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sleep logger',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Hours slept: ${_sleepHours.toStringAsFixed(1)}h'),
              Slider(
                min: 4,
                max: 10,
                divisions: 60,
                value: _sleepHours,
                activeColor: const Color(0xff0e7c7b),
                onChanged: (value) => setState(() => _sleepHours = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: _sleepQuality,
                decoration: const InputDecoration(
                  labelText: 'Quality',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'Poor', child: Text('Poor')),
                  DropdownMenuItem(value: 'Good', child: Text('Good')),
                  DropdownMenuItem(
                      value: 'Excellent', child: Text('Excellent')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _sleepQuality = value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saveSleepEntry,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff0e7c7b)),
                    child: const Text('Save sleep'),
                  ),
                  const SizedBox(width: 10),
                  if (_latestSleepEntry != null)
                    Expanded(
                      child: Text(
                        'Last night: ${_latestSleepEntry!.hours.toStringAsFixed(1)}h ${_latestSleepEntry!.quality} - Saved',
                        style: const TextStyle(
                          color: Color(0xff0e7c7b),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _care() =>
      _shell('CARE · NEXT STEPS', 'Your saved information, in one place.', [
        TextButton.icon(
          onPressed: () => setState(() => _careFromProfile = false),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Profile'),
        ),
        const _Card('Prototype care coordination',
            'This prototype does not send referrals, notify a clinician, or book appointments. It is not monitored for emergencies. Contact your care team or local emergency service directly for urgent or rapidly changing concerns.'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReviewSummaryScreen())),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Review my saved health data'),
            style: FilledButton.styleFrom(backgroundColor: ink)),
        const SizedBox(height: 12),
        const _Card(
          'Qualified review',
          'A qualified professional should interpret concerning or changing findings in context. This prototype does not decide diagnosis, referral, or clinical next steps.',
        ),
      ]);

  String _formatLocalDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Widget _top() => Column(children: [
        Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 8),
            child: Row(children: [
              Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: const Color(0xffe6f3f2),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.wb_sunny_outlined,
                      color: Color(0xff0e7c7b), size: 15)),
              const SizedBox(width: 7),
              const Text('basira',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff333b3a))),
              const Spacer(),
              TextButton(
                  onPressed: () {
                    final language = _language == 'ar' ? 'en' : 'ar';
                    setState(() => _language = language);
                    AppLanguage.setLanguage(language);
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xff56605e),
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(AppLanguage.isArabic ? 'English' : 'العربية',
                      style: const TextStyle(fontSize: 11))),
              Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: const Color(0xfff0f3f1),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.accessibility_new,
                      color: Color(0xff56605e), size: 16))
            ])),
        Container(
            width: double.infinity,
            color: const Color(0xffeef2f0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: const Text('ILLUSTRATIVE DATA · AMAL, 58 · 04 NOV 2026',
                style: TextStyle(
                    fontSize: 8, letterSpacing: .35, color: Color(0xff79817f))))
      ]);
  Widget _nav() => BasiraBottomNavigation(selectedIndex: tab);
}

class _Card extends StatelessWidget {
  const _Card(this.title, this.body);
  final String title, body;
  @override
  Widget build(BuildContext c) => Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$title\n\n$body',
                style: const TextStyle(
                    height: 1.45,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500)))
      ]));
}
