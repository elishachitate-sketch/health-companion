import 'package:flutter/material.dart';

import '../models/review_summary.dart';
import '../widgets/basira_bottom_navigation.dart';

class ReviewPreviewScreen extends StatelessWidget {
  const ReviewPreviewScreen({
    super.key,
    this.shareSummary = false,
    this.includeFamilyHistory = false,
    this.onClose,
  });

  final bool shareSummary;
  final bool includeFamilyHistory;
  final VoidCallback? onClose;

  static const _teal = Color(0xff0e7c7b);
  static const _ink = Color(0xff171b24);

  @override
  Widget build(BuildContext context) {
    final summary = getIllustrativeSummary();

    return Scaffold(
      backgroundColor: const Color(0xfff3f6f5),
      bottomNavigationBar: const BasiraBottomNavigation(selectedIndex: 4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const _LtrText(
          'Preview my review summary',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            if (!shareSummary) ...[
              _card(
                child: const _LtrText(
                  'Sharing is OFF. This preview stays on this device.',
                  style: TextStyle(
                    color: Color(0xff5d6670),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: _LtrText(
                      'ILLUSTRATIVE DATA - AMAL, 58 - 04 NOV 2026',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff5d6670),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff1d6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const _LtrText(
                        'Awaiting clinical review',
                        style: TextStyle(
                          color: Color(0xff8a4b00),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff8e9),
                      border: Border.all(color: const Color(0xffffdf9b)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const _LtrText(
                      'No diagnosis or referral has been decided. A qualified professional should review abnormal or rapidly changing findings.',
                      style: TextStyle(height: 1.4, color: _ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(
              'Your context',
              [
                _detailRow('Name', summary.name),
                _detailRow('Age', summary.age),
                _detailRow('Language', summary.language),
                _detailRow('Date', summary.summaryDate),
              ],
            ),
            const SizedBox(height: 14),
            _section(
              'What you shared',
              [
                _detailRow('Sleep', summary.sleepNote),
                _detailRow('Daily Activity', summary.activityNote),
                _detailRow('Nutrition', summary.nutritionNote),
                _detailRow('Brain Exercises', summary.brainExerciseNote),
              ],
            ),
            const SizedBox(height: 14),
            if (includeFamilyHistory)
              _section(
                'Family history',
                [
                  _LtrText(
                    summary.familyHistoryNote,
                    style: const TextStyle(height: 1.4, color: _ink),
                  ),
                ],
              )
            else
              _card(
                child: const _LtrText(
                  'Not included by your choice.',
                  style: TextStyle(height: 1.4, color: _ink),
                ),
              ),
            const SizedBox(height: 14),
            _section(
              'What happens next',
              [
                _LtrText(
                  summary.nextStepNote,
                  style: const TextStyle(height: 1.4, color: _ink),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  content: const _LtrText(
                    'Sharing is optional. You decide what leaves this device.',
                    style: TextStyle(height: 1.4, color: _ink),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const _LtrText('Close'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.share_outlined),
              label: const _LtrText('Share'),
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _teal,
                minimumSize: const Size.fromHeight(54),
                side: const BorderSide(color: _teal),
              ),
              child: const _LtrText('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LtrText(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LtrText(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xff58636d),
              ),
            ),
            const SizedBox(height: 3),
            _LtrText(value, style: const TextStyle(height: 1.35, color: _ink)),
          ],
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe0e6e5)),
        ),
        child: child,
      );
}

class _LtrText extends StatelessWidget {
  const _LtrText(this.data, {this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        data,
        textAlign: TextAlign.start,
        style: style,
      );
}
