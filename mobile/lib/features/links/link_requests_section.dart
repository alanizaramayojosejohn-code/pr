import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/profile.dart';
import '../../theme/app_theme.dart';
import '../instructor/providers.dart';
import 'data/links_repository.dart';
import 'providers.dart';

/// Bandeja de solicitudes pendientes. La usan las dos partes: al instructor le
/// muestra las de sus futuros alumnos y al alumno las de su futuro instructor.
///
/// Si no hay nada pendiente no ocupa lugar: devuelve un `SizedBox.shrink()`.
class LinkRequestsSection extends ConsumerWidget {
  const LinkRequestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingLinksProvider).asData?.value ?? const [];
    final sent = ref.watch(sentLinksProvider).asData?.value ?? const [];
    if (incoming.isEmpty && sent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (incoming.isNotEmpty) ...[
          _Header(
            label: 'SOLICITUDES',
            // El contador solo cuenta lo accionable: lo que mandé yo no urge.
            badge: incoming.length,
          ),
          const SizedBox(height: 10),
          for (final r in incoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IncomingCard(request: r),
            ),
        ],
        if (sent.isNotEmpty) ...[
          if (incoming.isNotEmpty) const SizedBox(height: 8),
          const _Header(label: 'ENVIADAS'),
          const SizedBox(height: 10),
          for (final r in sent)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SentCard(request: r),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Refresca todo lo que depende del vínculo. Aceptar cambia la lista de
/// alumnos del instructor y el `instructor_id` del alumno a la vez.
void _refreshAfterLinkChange(WidgetRef ref) {
  ref.invalidate(pendingLinksProvider);
  ref.invalidate(clientsProvider);
  ref.invalidate(myProfileProvider);
  ref.invalidate(myInstructorEmailProvider);
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    _refreshAfterLinkChange(ref);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
    );
  }
}

class _IncomingCard extends ConsumerWidget {
  const _IncomingCard({required this.request});
  final LinkRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    final isInstructor = request.counterpartRole == 'instructor';

    return NeuroCard(
      radius: 16,
      size: NeuroSize.sm,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(email: request.counterpartEmail),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.counterpartEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ac.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isInstructor
                          ? 'Quiere ser tu instructor'
                          : 'Quiere que lo entrenes',
                      style: TextStyle(fontSize: 11, color: ac.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _run(
                    context,
                    ref,
                    () => ref
                        .read(linksRepositoryProvider)
                        .respond(request.id, accept: false),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    shape: const StadiumBorder(),
                    foregroundColor: ac.textMuted,
                    side: BorderSide(
                      color: ac.glassBorderBase.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Text('Rechazar', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _run(
                    context,
                    ref,
                    () => ref
                        .read(linksRepositoryProvider)
                        .respond(request.id, accept: true),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Aceptar', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentCard extends ConsumerWidget {
  const _SentCard({required this.request});
  final LinkRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    return NeuroCard(
      radius: 16,
      size: NeuroSize.sm,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _Avatar(email: request.counterpartEmail),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.counterpartEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ac.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Esperando respuesta',
                  style: TextStyle(fontSize: 11, color: ac.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _run(
              context,
              ref,
              () => ref.read(linksRepositoryProvider).cancel(request.id),
            ),
            child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label, this.badge});
  final String label;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: ac.textMuted,
          ),
        ),
        if (badge != null && badge! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: kSeed,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kSeed.withValues(alpha: 0.16),
      ),
      child: Text(
        email.isNotEmpty ? email[0].toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.w800, color: kSeed),
      ),
    );
  }
}
