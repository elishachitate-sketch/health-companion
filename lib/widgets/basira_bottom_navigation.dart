import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/translations.dart';

class BasiraBottomNavigation extends StatelessWidget {
  const BasiraBottomNavigation({
    super.key,
    required this.selectedIndex,
  });

  final int selectedIndex;

  static const _destinations = <(String, IconData)>[
    ('Overview', Icons.home_outlined),
    ('Studio', Icons.psychology_alt_outlined),
    ('Plan', Icons.eco_outlined),
    ('Chat', Icons.chat_bubble_outline),
    ('Profile', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 12,
        shadowColor: const Color(0x260d2020),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
            child: Row(
              children: [
                for (var index = 0; index < _destinations.length; index++)
                  Expanded(
                    child: _NavigationItem(
                      label: AppTranslations.translate(
                        _destinations[index].$1,
                        AppLanguage.locale.value.languageCode,
                      ),
                      icon: _destinations[index].$2,
                      selected: index == selectedIndex,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/tab/$index'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xff0e7c7b) : const Color(0xff8a9190);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 38,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 34, color: color),
                    if (selected)
                      const PositionedDirectional(
                        top: -1,
                        end: -7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xff0e7c7b),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 8, height: 8),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
