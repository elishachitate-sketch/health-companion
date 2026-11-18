import 'package:flutter/material.dart' hide Text;

import '../localization/localized_text.dart';
import '../widgets/basira_bottom_navigation.dart';
import 'health_chat_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      bottomNavigationBar: const BasiraBottomNavigation(selectedIndex: 0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8F6),
        elevation: 0,
        title: const Text('Health Companion'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Good morning',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How is your memory, focus, and daily functioning today?',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: const Color(0xFFDee9e3),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.favorite_outline,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'A short check-in can help spot meaningful changes early and guide you toward the right preventive care or support.',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff0e7c7b),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const HealthChatScreen(),
                                  ),
                                ),
                                child: const Text('Start check-in'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.bedtime_outlined,
                            label: 'Sleep',
                            value: 'Not logged',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.bolt_outlined,
                            label: 'Energy',
                            value: 'Not logged',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: colors.secondaryContainer,
                          child: const Icon(Icons.auto_awesome),
                        ),
                        title:
                            const Text('Your brain health companion is ready'),
                        subtitle: const Text(
                          'Talk, type, or use your voice. Privacy-first support and early monitoring, not diagnosis.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const HealthChatScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This is brain-health monitoring support, not a diagnosis or replacement for professional care.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If you notice sudden confusion, worsening symptoms, or feel unsafe, contact emergency services or a trusted person right away.',
                      style: TextStyle(height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BottomNavItem(icon: Icons.home_outlined, active: true),
                    _BottomNavItem(icon: Icons.analytics_outlined),
                    _BottomNavItem(icon: Icons.chat_bubble_outline),
                    _BottomNavItem(icon: Icons.person_outline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({required this.icon, this.active = false});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: active
          ? BoxDecoration(
              color: const Color(0xff0e7c7b),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Icon(
        icon,
        color: active ? Colors.white : Colors.black54,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
