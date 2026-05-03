import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _Tab {
  const _Tab(this.path, this.icon, this.activeIcon, this.label);
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _tabs = <_Tab>[
  _Tab('/', Icons.home_outlined, Icons.home, 'HOY'),
  _Tab('/rutinas', Icons.list_alt_outlined, Icons.list_alt, 'RUTINAS'),
  _Tab('/aprender', Icons.menu_book_outlined, Icons.menu_book, 'APRENDER'),
  _Tab('/medidas', Icons.straighten_outlined, Icons.straighten, 'MEDIDAS'),
  _Tab('/progreso', Icons.trending_up_outlined, Icons.trending_up, 'PROGRESO'),
  _Tab('/historial', Icons.history_outlined, Icons.history, 'HISTORIAL'),
];

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final activeIndex = _tabs.indexWhere((t) => t.path == location);
    final session = ref.watch(currentSessionProvider);
    final email = session?.user.email ?? '';
    final initial = email.isNotEmpty ? email.substring(0, 1).toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            _BrandDot(),
            SizedBox(width: 8),
            Text(
              'PR',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.push('/cuenta'),
              child: CircleAvatar(
                radius: 16,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeIndex >= 0 ? activeIndex : 0,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon, size: 22),
                  selectedIcon: Icon(t.activeIcon, size: 22),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _BrandDot extends StatelessWidget {
  const _BrandDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
