import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../theme/app_theme.dart';

class _Tab {
  const _Tab(this.path, this.icon, this.activeIcon, this.label);
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _tabs = <_Tab>[
  _Tab('/', Icons.home_outlined, Icons.home_rounded, 'HOY'),
  _Tab('/rutinas', Icons.list_alt_outlined, Icons.list_alt_rounded, 'RUTINAS'),
  _Tab('/aprender', Icons.menu_book_outlined, Icons.menu_book_rounded, 'APRENDER'),
  _Tab('/medidas', Icons.straighten_outlined, Icons.straighten_rounded, 'MEDIDAS'),
  _Tab('/progreso', Icons.trending_up_outlined, Icons.trending_up_rounded, 'PROGRESO'),
  _Tab('/historial', Icons.history_rounded, Icons.history_rounded, 'HISTORIAL'),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBg,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: _GlassAppBar(initial: initial),
        body: AppGradient(child: child),
        bottomNavigationBar: _GlassNavBar(
          activeIndex: activeIndex >= 0 ? activeIndex : 0,
          onTap: (i) => context.go(_tabs[i].path),
        ),
      ),
    );
  }
}

// ── Glass AppBar ──────────────────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GlassAppBar({required this.initial});
  final String initial;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: kBg.withValues(alpha: 0.65),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _BrandMark(),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/cuenta'),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kSeed.withValues(alpha: 0.18),
                          border: Border.all(
                            color: kSeed.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xF2FFFFFF),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: kSeed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'PR',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 14,
            color: Color(0xF2FFFFFF),
          ),
        ),
      ],
    );
  }
}

// ── Glass NavigationBar ───────────────────────────────────────────────────────

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.activeIndex, required this.onTap});
  final int activeIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: kBg.withValues(alpha: 0.75),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          child: NavigationBar(
            selectedIndex: activeIndex,
            onDestinationSelected: onTap,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 64,
            destinations: _tabs
                .map((t) => NavigationDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.activeIcon),
                      label: t.label,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
