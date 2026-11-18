import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_entries.dart';
import '../services/health_entry_repository.dart';
import '../services/health_data.dart' as health_data;
import '../widgets/basira_bottom_navigation.dart';
import 'detail_page.dart';
import 'health_entry_log_screen.dart';

class ReviewSummaryScreen extends StatefulWidget {
  const ReviewSummaryScreen({
    super.key,
    this.repositories,
    this.chatEntriesLoader,
    this.cognitiveEntriesLoader,
  });

  final HealthEntryRepositories? repositories;
  final Future<List<health_data.ChatEntry>> Function()? chatEntriesLoader;
  final Future<List<health_data.CognitiveTaskResult>> Function()?
      cognitiveEntriesLoader;

  @override
  State<ReviewSummaryScreen> createState() => _ReviewSummaryScreenState();
}

class _ReviewSummaryScreenState extends State<ReviewSummaryScreen> {
  static const _navy = Color(0xff164845);
  static const _blue = Color(0xff0e7c7b);
  static const _background = Color(0xffe3f2f0);
  static const _cardColor = Color(0xfffbfefe);
  static const _muted = Color(0xff526d6b);

  HealthEntryRepositories? _repositories;
  List<health_data.ChatEntry> _chatEntries = const [];
  List<({DateTime timestamp, int score, String detail})> _cognitiveEntries =
      const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final repositories = _repositories ??
          widget.repositories ??
          await HealthEntryRepositories.initialize();
      var chatEntries = <health_data.ChatEntry>[];
      var cognitiveEntries =
          <({DateTime timestamp, int score, String detail})>[];
      try {
        chatEntries = await (widget.chatEntriesLoader?.call() ??
            health_data.DataService.instance.getChatEntriesLast7Days());
      } catch (_) {
        // Keep the summary available if the chat history store is unavailable.
      }
      try {
        final practiceEntries = await (widget.cognitiveEntriesLoader?.call() ??
            health_data.DataService.instance.getLast30Days());
        cognitiveEntries = [
          ...practiceEntries.map((entry) => (
                timestamp: entry.date,
                score: entry.score,
                detail: '${entry.task.name} · ${entry.score}/100',
              )),
          ...repositories.cognitive.getAllSortedNewestFirst().map((entry) => (
                timestamp: entry.timestamp,
                score: entry.score,
                detail:
                    '${entry.score}/100 · ${entry.totalQuestions} questions',
              )),
        ]..sort((left, right) => right.timestamp.compareTo(left.timestamp));
      } catch (_) {
        // Keep other health summary cards available if practice history fails.
      }
      if (!mounted) return;
      setState(() {
        _repositories = repositories;
        _chatEntries = chatEntries;
        _cognitiveEntries = cognitiveEntries;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Saved data could not be opened on this device.';
      });
    }
  }

  HealthEntryRepositories get _data => _repositories!;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        bottomNavigationBar: const BasiraBottomNavigation(selectedIndex: 0),
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _navy,
          elevation: 0,
          title: const _SummaryText(
            'Your health summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh saved entries',
              onPressed: _loading ? null : _loadResults,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _SummaryText(
                        _error!,
                        style: const TextStyle(fontSize: 18, color: _navy),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 720
                              ? 2
                              : 1;
                      const gap = 12.0;
                      final width =
                          (constraints.maxWidth - 32 - gap * (columns - 1)) /
                              columns;
                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            sliver: SliverList.list(
                              children: [
                                _header(),
                                const SizedBox(height: 12),
                                _privacyBanner(),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                    _moodCard(width),
                                    _moodDistributionCard(width),
                                    _dailyFunctionCard(width),
                                    _cognitiveCard(width),
                                    _lifestyleCard(width),
                                    _chatToneCard(width),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _safetyNotice(),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      );

  Widget _header() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryText(
              'Hello 👋',
              style: TextStyle(
                color: _navy,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            _SummaryText(
              'Your own check-ins over time',
              style: TextStyle(color: _muted, fontSize: 18, height: 1.35),
            ),
          ],
        ),
      );

  Widget _privacyBanner() => Semantics(
        label:
            'Your information stays on this device. The summary works offline.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xffcce7e2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: _navy, size: 25),
              SizedBox(width: 10),
              Expanded(
                child: _SummaryText(
                  'Your data stays on this device. Works offline.',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _moodCard(double width) {
    final entries = _data.moods.getLast7Days();
    if (entries.isEmpty) {
      return _emptyCard(
        width: width,
        title: 'Mood trend',
        onLog: () => _openLogger(HealthEntryLogKind.mood),
      );
    }
    return _card(
      width: width,
      title: 'Mood trend',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SummaryText('Mood over the last 7 days',
              style: TextStyle(color: _muted, fontSize: 15)),
          const SizedBox(height: 6),
          SizedBox(height: _chartHeight(width), child: _moodLine(entries)),
        ],
      ),
      details: entries
          .map((entry) => _detail(
                entry.timestamp,
                '${_moodLabel(entry.mood)}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
              ))
          .toList(),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPage(
            title: 'Mood trend',
            chartWidget: SizedBox(height: 220, child: _moodLine(entries)),
            entriesList: entries
                .map((entry) => DetailEntry(
                      value: _moodLabel(entry.mood),
                      timestamp: entry.timestamp,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _moodDistributionCard(double width) {
    final entries = _data.moods.getLast7Days();
    final distribution = _distributionForMood(entries);
    if (entries.isEmpty) {
      return _emptyCard(
        width: width,
        title: 'Mood distribution',
        onLog: () => _openLogger(HealthEntryLogKind.mood),
      );
    }
    return _card(
      width: width,
      title: 'Mood distribution',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              height: _chartHeight(width),
              child: _pieChart(distribution, showPercent: true)),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final entry in distribution.entries)
                _SummaryText(
                  '${_moodLabel(entry.key)} · ${_percentage(entry.value, entries.length).round()}%',
                  style: const TextStyle(color: _navy, fontSize: 13),
                ),
            ],
          ),
        ],
      ),
      details: entries
          .map((entry) => _detail(entry.timestamp, _moodLabel(entry.mood)))
          .toList(),
      onTap: () => _showDetails(
          'Mood distribution',
          entries
              .map((entry) => _detail(entry.timestamp, _moodLabel(entry.mood)))
              .toList()),
    );
  }

  Widget _dailyFunctionCard(double width) {
    final entries = _data.dailyFunctions.getLast7Days();
    if (entries.isEmpty) {
      return _emptyCard(
        width: width,
        title: 'Daily Function',
        onLog: () => _openLogger(HealthEntryLogKind.dailyFunction),
      );
    }
    const categories = ['eating', 'walking', 'sleep', 'social'];
    final averages = {
      for (final category in categories)
        category: _averageValue(entries, category),
    };
    return _card(
      width: width,
      title: 'Daily Function',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SummaryText('Scale 0–5',
              style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            height: _chartHeight(width, factor: 0.8),
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 5,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= categories.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _SummaryText(
                            _categoryLabel(categories[index]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: _navy),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var index = 0; index < categories.length; index++)
                    BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: averages[categories[index]] ?? 0,
                          color: _blue,
                          width: 25,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ],
                    ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
        ],
      ),
      details: entries
          .map((entry) => _detail(
                entry.timestamp,
                '${_categoryLabel(entry.category)} · ${entry.value}/5',
              ))
          .toList(),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPage(
            title: 'Daily Function',
            chartWidget: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 5,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= categories.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _SummaryText(
                              _categoryLabel(categories[index]),
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontSize: 11, color: _navy),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var index = 0; index < categories.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: averages[categories[index]] ?? 0,
                            color: _blue,
                            width: 25,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ],
                      ),
                  ],
                ),
                duration: Duration.zero,
              ),
            ),
            entriesList: entries
                .map((entry) => DetailEntry(
                      value:
                          '${_categoryLabel(entry.category)} · ${entry.value}/5',
                      timestamp: entry.timestamp,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _lifestyleCard(double width) {
    final entries = _data.lifestyle.getLast7Days();
    final distribution = _data.lifestyle.getDistribution(entries: entries);
    if (entries.isEmpty) {
      return _emptyCard(
        width: width,
        title: 'Lifestyle Actions',
        onLog: () => _openLogger(HealthEntryLogKind.lifestyle),
      );
    }
    return _card(
      width: width,
      title: 'Lifestyle Actions',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: _chartHeight(width), child: _pieChart(distribution)),
          for (final entry in distribution.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _SummaryText(
                '${_actionLabel(entry.key)} · ${entry.value}',
                style: const TextStyle(color: _navy, fontSize: 13),
              ),
            ),
        ],
      ),
      details: entries
          .map((entry) => _detail(entry.timestamp, _actionLabel(entry.action)))
          .toList(),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPage(
            title: 'Lifestyle Actions',
            chartWidget: SizedBox(height: 220, child: _pieChart(distribution)),
            entriesList: entries
                .map((entry) => DetailEntry(
                      value: _actionLabel(entry.action),
                      timestamp: entry.timestamp,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _chatToneCard(double width) {
    final loggedEntries = _data.chatTones.getLast7Days();
    final chatEntries = _chatEntries;
    final distribution = <String, int>{};
    for (final entry in loggedEntries) {
      distribution.update(entry.tone, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final entry in chatEntries) {
      distribution.update(entry.tone.name, (count) => count + 1,
          ifAbsent: () => 1);
    }
    if (distribution.isEmpty) {
      return _emptyCard(
        width: width,
        title: 'Chat Tone',
        onLog: () => _openLogger(HealthEntryLogKind.chatTone),
      );
    }
    final detailEntries = <({DateTime timestamp, String value})>[
      ...loggedEntries.map((entry) => (
            timestamp: entry.timestamp,
            value: '${_toneLabel(entry.tone)} · ${entry.messageSnippet}',
          )),
      ...chatEntries.map((entry) => (
            timestamp: entry.date,
            value: _toneLabel(entry.tone.name),
          )),
    ]..sort((left, right) => right.timestamp.compareTo(left.timestamp));
    final details = detailEntries
        .map((entry) => _detail(entry.timestamp, entry.value))
        .toList();
    return _card(
      width: width,
      title: 'Chat Tone',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _chartHeight(width),
            child: _pieChart(distribution),
          ),
          for (final entry in distribution.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _SummaryText(
                '${_toneLabel(entry.key)} · ${entry.value}',
                style: const TextStyle(color: _navy, fontSize: 13),
              ),
            ),
        ],
      ),
      details: details,
      onTap: () => _showDetails('Chat Tone', details),
    );
  }

  Widget _cognitiveCard(double width) {
    final entries = _cognitiveEntries;
    if (entries.isEmpty) {
      return _emptyCard(
        width: width,
        title: 'Cognitive',
        onLog: () => _openLogger(HealthEntryLogKind.cognitive),
      );
    }
    final points = entries.take(12).toList().reversed.toList();
    Widget chart(double height) => SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              minX: 0,
              maxX: math.max(1, points.length - 1).toDouble(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var index = 0; index < points.length; index++)
                      FlSpot(index.toDouble(), points[index].score.toDouble()),
                  ],
                  isCurved: true,
                  color: _blue,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: _blue.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
            duration: Duration.zero,
          ),
        );

    final details =
        entries.map((entry) => _detail(entry.timestamp, entry.detail)).toList();
    return _card(
      width: width,
      title: 'Cognitive score',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SummaryText('Practice over time',
              style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 8),
          chart(_chartHeight(width, factor: 0.8)),
          _SummaryText(
            points.map((entry) => _monthLabel(entry.timestamp)).join(' · '),
            maxLines: 2,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
      details: details,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPage(
            title: 'Cognitive score',
            chartWidget: chart(220),
            entriesList: entries
                .map((entry) => DetailEntry(
                      value: entry.detail,
                      timestamp: entry.timestamp,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard({
    required double width,
    required String title,
    required VoidCallback onLog,
  }) =>
      _card(
        width: width,
        title: title,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Center(
              child: _SummaryText(
                'No data yet',
                style: TextStyle(
                  color: _muted,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onLog,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const _SummaryText('Log now'),
              ),
            ),
          ],
        ),
        details: const [],
      );

  Widget _card({
    required double width,
    required String title,
    required Widget body,
    required List<String> details,
    VoidCallback? onTap,
  }) =>
      Semantics(
        button: details.isNotEmpty,
        label: details.isEmpty
            ? '$title. No data yet. Log now.'
            : '$title. ${details.length} entries. Tap to see details with date and time.',
        child: Material(
          child: InkWell(
            onTap: details.isEmpty
                ? null
                : onTap ?? () => _showDetails(title, details),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              key: ValueKey('summary-card-$title'),
              width: width,
              constraints: const BoxConstraints(minHeight: 230),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xffcde4e0), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14164643),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryText(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _navy.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  body,
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: _SummaryText(
                        'Tap for details',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget _moodLine(List<MoodEntry> entries) {
    final points = entries.take(7).toList();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 5,
        minX: 0,
        maxX: math.max(1, points.length - 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < points.length; index++)
                FlSpot(index.toDouble(), _moodNumericValue(points[index].mood)),
            ],
            isCurved: true,
            color: _blue,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: _blue.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }

  Widget _pieChart(
    Map<String, int> distribution, {
    bool showPercent = false,
  }) {
    const palette = [
      Color(0xff0e7c7b),
      Color(0xff43a99c),
      Color(0xff78c4b6),
      Color(0xff226f75),
      Color(0xffa1d8cc),
    ];
    final items = distribution.entries.toList();
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 24,
        sections: [
          for (var index = 0; index < items.length; index++)
            PieChartSectionData(
              value: items[index].value.toDouble(),
              color: palette[index % palette.length],
              radius: 52,
              title: showPercent
                  ? '${_percentage(items[index].value, distribution.values.fold<int>(0, (total, count) => total + count)).round()}%'
                  : '${items[index].value}',
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }

  Map<String, int> _distributionForMood(List<MoodEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      counts.update(entry.mood, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  double _averageValue(List<DailyFunctionEntry> entries, String category) {
    final matches = entries.where((entry) => entry.category == category);
    if (matches.isEmpty) return 0;
    return matches.fold<int>(0, (sum, entry) => sum + entry.value) /
        matches.length;
  }

  String _monthLabel(DateTime timestamp) =>
      DateFormat('MMM', 'en').format(timestamp.toLocal());

  Future<void> _openLogger(HealthEntryLogKind kind) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HealthEntryLogScreen(kind: kind, repositories: _data),
    ));
    await _loadResults();
  }

  Future<void> _showDetails(String title, List<String> entries) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(title, style: const TextStyle(color: _navy, fontSize: 22)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in entries) ...[
                  Text(entry,
                      style: const TextStyle(
                          color: _navy, fontSize: 17, height: 1.45)),
                  const Divider(height: 20),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _detail(DateTime timestamp, String value) =>
      '${formatHealthEntryTimestamp(timestamp)}\n$value';

  String _moodLabel(String mood) => switch (mood) {
        'happy' => 'Happy',
        'neutral' => 'Neutral',
        'worried' => 'Worried',
        _ => 'Tired',
      };

  double _moodNumericValue(String mood) => switch (mood) {
        'happy' => 5,
        'neutral' => 3,
        'worried' => 2,
        _ => 1,
      };

  String _categoryLabel(String category) => switch (category) {
        'eating' => 'Eating',
        'walking' => 'Walking',
        'sleep' => 'Sleep',
        _ => 'Social',
      };

  String _actionLabel(String action) => switch (action) {
        'water' => 'Water',
        'exercise' => 'Exercise',
        'rest' => 'Rest',
        'prayer' => 'Prayer',
        _ => 'Meals',
      };

  String _toneLabel(String tone) => switch (tone) {
        'supportive' => 'Supportive',
        'encouraging' => 'Encouraging',
        'worried' => 'Worried',
        'tired' => 'Tired',
        'hopeful' => 'Hopeful',
        'calm' => 'Calm',
        _ => 'Neutral',
      };

  double _percentage(int count, int total) =>
      total == 0 ? 0 : count * 100 / total;

  double _chartHeight(double width, {double factor = 0.72}) =>
      (width * factor).clamp(112, 160).toDouble();

  Widget _safetyNotice() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffcce7e2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'These entries are self-reported, not a diagnosis. Cognitive scores are practice results only.',
          style: TextStyle(color: _navy, fontSize: 16, height: 1.4),
        ),
      );
}

class _SummaryText extends StatelessWidget {
  const _SummaryText(
    this.data, {
    this.style,
    this.maxLines,
    this.textAlign,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(
        data,
        style: style,
        maxLines: maxLines,
        textAlign: textAlign,
        overflow: overflow,
      );
}
