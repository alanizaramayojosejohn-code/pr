import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_providers.dart';
import '../../auth/profile.dart';
import '../../supabase/client.dart';
import '../../theme/app_theme.dart';
import '../links/link_requests_section.dart';
import '../links/link_search_sheet.dart';
import '../links/providers.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final isInstructor = ref.watch(isInstructorProvider);
    final ac = AppColors.of(context);

    final email = session?.user.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          'Cuenta',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ac.textPrimary,
          ),
        ),
      ),
      body: AppGradient(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            // ── Avatar + email ──────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kSeed.withValues(alpha: 0.18),
                      border: Border.all(color: kSeed.withValues(alpha: 0.45), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ac.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: ac.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Instructor ──────────────────────────────────────────────────
            if (isInstructor) ...[
              _SectionLabel('INSTRUCTOR'),
              const SizedBox(height: 8),
              GlassCard(
                radius: 14,
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/instructor'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.groups_rounded,
                              size: 20, color: kSeed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Mis alumnos y plantillas',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ac.textPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: ac.textDisabled),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Mi instructor ───────────────────────────────────────────────
            // Solo para alumnos: un instructor no tiene instructor.
            if (!isInstructor) ...[
              _SectionLabel('MI INSTRUCTOR'),
              const SizedBox(height: 8),
              const _MyInstructorCard(),
              const SizedBox(height: 12),
              const LinkRequestsSection(),
              const SizedBox(height: 8),
            ],

            // ── Sesión ──────────────────────────────────────────────────────
            _SectionLabel('SESIÓN'),
            const SizedBox(height: 8),
            GlassCard(
              radius: 14,
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async => supabase.auth.signOut(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 20,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 12),
                        Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado del vínculo del alumno: o tiene instructor y puede cortarlo, o no
/// tiene y puede buscar uno.
class _MyInstructorCard extends ConsumerWidget {
  const _MyInstructorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    final email = ref.watch(myInstructorEmailProvider).asData?.value;

    if (email == null) {
      return GlassCard(
        radius: 14,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final sent = await LinkSearchSheet.show(
                context,
                lookingForInstructor: true,
              );
              if (sent == true) ref.invalidate(pendingLinksProvider);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.person_search_rounded,
                      size: 20, color: kSeed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buscar instructor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ac.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Opcional: te manda rutinas y te sigue el progreso',
                          style:
                              TextStyle(fontSize: 11, color: ac.textDisabled),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: ac.textDisabled),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GlassCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, size: 20, color: kSeed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ac.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _confirmUnlink(context, ref),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Desvincular', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular instructor'),
        content: const Text(
          'Deja de verte el progreso y de mandarte rutinas. Las que ya te '
          'mandó se quedan con vos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final me = supabase.auth.currentUser?.id;
    if (me == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(linksRepositoryProvider).endLink(me);
      ref.invalidate(myInstructorEmailProvider);
      ref.invalidate(myProfileProvider);
      ref.invalidate(pendingLinksProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.of(context).textMuted,
      ),
    );
  }
}
