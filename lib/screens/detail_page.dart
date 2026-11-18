import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DetailEntry {
  const DetailEntry({required this.value, required this.timestamp});

  final String value;
  final DateTime timestamp;

  String get text => '$value - ${DateFormat('dd/MM/yyyy, hh:mm a').format(timestamp.toLocal())}';
}

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.title,
    required this.chartWidget,
    required this.entriesList,
  });

  final String title;
  final Widget chartWidget;
  final List<DetailEntry> entriesList;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  static const Color _navy = Color(0xff10244f);
  static const Color _blue = Color(0xff3679c9);
  static const Color _background = Color(0xffd9efff);
  static const Color _cardColor = Color(0xfff8fcff);
  static const Color _muted = Color(0xff52647d);

  String _filter = '7d';

  List<DetailEntry> get _visibleEntries {
    final sorted = [...widget.entriesList]
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));

    final now = DateTime.now();
    final cutoff = _filter == '7d'
        ? now.subtract(const Duration(days: 7))
        : _filter == '30d'
            ? now.subtract(const Duration(days: 30))
            : null;

    if (cutoff == null) return sorted;
    return sorted
        .where((entry) => !entry.timestamp.isBefore(cutoff))
        .toList();
  }

  Future<void> _shareSummary() async {
    final filtered = _visibleEntries;
    final summary = <String>[
      'Clinic summary: ${widget.title}',
      'Generated offline on ${DateFormat('dd/MM/yyyy, hh:mm a').format(DateTime.now().toLocal())}.',
      if (filtered.isEmpty) 'No entries in the selected time range.' else ...[
        for (final entry in filtered) '- ${entry.text}',
      ],
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Clinic summary copied for offline sharing.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleEntries = _visibleEntries;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _navy,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        actions: [
          IconButton(
            tooltip: 'Share clinic summary',
            onPressed: visibleEntries.isEmpty ? null : _shareSummary,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xffcfe7f8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(color: _muted, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(height: 220, child: widget.chartWidget),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ToggleButtons(
                  isSelected: [
                    _filter == '7d',
                    _filter == '30d',
                    _filter == 'all',
                  ],
                  onPressed: (index) {
                    setState(() {
                      _filter = index == 0 ? '7d' : index == 1 ? '30d' : 'all';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: Colors.white,
                  fillColor: _blue,
                  color: _navy,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  constraints: const BoxConstraints(minHeight: 42, minWidth: 100),
                  children: const [
                    Text('Last 7 days'),
                    Text('Last 30 days'),
                    Text('All'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xffdfeaf6)),
                  ),
                  child: visibleEntries.isEmpty
                      ? const Center(
                          child: Text(
                            'No data yet',
                            style: TextStyle(color: _muted, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: visibleEntries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = visibleEntries[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.radio_button_checked_rounded, size: 18, color: _blue),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      entry.text,
                                      style: const TextStyle(fontSize: 16, color: _navy, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
