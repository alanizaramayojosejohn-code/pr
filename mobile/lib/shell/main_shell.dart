import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/profile.dart';
import '../features/updater/update_dialog.dart';
import '../features/updater/update_service.dart';
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
  _Tab('/progreso', Icons.trending_up_outlined, Icons.trending_up_rounded, 'PROGRESO'),
  _Tab('/historial', Icons.history_rounded, Icons.history_rounded, 'HISTORIAL'),
];

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;
    await ref.read(updateServiceProvider.notifier).checkForUpdate();
    if (!mounted) return;
    final result = ref.read(updateServiceProvider).asData?.value;
    if (result == null) return;
    if (result.status == UpdateStatus.forced) {
      context.go('/force-update');
    } else if (result.status == UpdateStatus.suggested) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(manifest: result.manifest!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final activeIndex = _tabs.indexWhere((t) => t.path == location);
    final session = ref.watch(currentSessionProvider);
    final email = session?.user.email ?? '';
    final initial = email.isNotEmpty ? email.substring(0, 1).toUpperCase() : '?';
    final isInstructor = ref.watch(isInstructorProvider);
    final ac = AppColors.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ac.overlayStyle,
      child: Scaffold(
        backgroundColor: ac.bg,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: _NeuroAppBar(initial: initial, isInstructor: isInstructor),
        body: widget.child,
        bottomNavigationBar: _NeuroNavBar(
          activeIndex: activeIndex >= 0 ? activeIndex : 0,
          onTap: (i) => context.go(_tabs[i].path),
        ),
      ),
    );
  }
}

// ── Neumorphic AppBar ─────────────────────────────────────────────────────────

class _NeuroAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _NeuroAppBar({required this.initial, required this.isInstructor});
  final String initial;
  final bool isInstructor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: ac.bg,
        boxShadow: [
          BoxShadow(color: ac.shadowSh, blurRadius: 10, offset: const Offset(0, 6)),
          BoxShadow(color: ac.shadowHi, blurRadius: 6, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _BrandMark(),
                const Spacer(),
                if (isInstructor) ...[
                  GestureDetector(
                    onTap: () => context.push('/instructor'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ac.bg,
                        boxShadow: ac.raised(NeuroSize.sm),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.groups_rounded,
                        size: 18,
                        color: kSeed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                GestureDetector(
                  onTap: () => context.push('/cuenta'),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ac.bg,
                      boxShadow: ac.raised(NeuroSize.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kSeed,
                      ),
                    ),
                  ),
                ),
              ],
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
    final ac = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/img/logo.webp',
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'PR',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 14,
            color: ac.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Neumorphic NavigationBar ──────────────────────────────────────────────────

class _NeuroNavBar extends StatelessWidget {
  const _NeuroNavBar({required this.activeIndex, required this.onTap});
  final int activeIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: ac.bg,
        boxShadow: ac.floatNav(),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (int i = 0; i < _tabs.length; i++)
              Expanded(
                child: _NavItem(
                  tab: _tabs[i],
                  isActive: i == activeIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });
  final _Tab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 46,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ac.bg,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive ? ac.raised(NeuroSize.sm) : [],
            ),
            child: Icon(
              isActive ? tab.activeIcon : tab.icon,
              size: 20,
              color: isActive ? kSeed : ac.textDisabled,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tab.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.6,
              color: isActive ? kSeed : ac.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}
