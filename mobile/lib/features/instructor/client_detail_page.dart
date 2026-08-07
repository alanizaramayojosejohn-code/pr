import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../routines/data/routines_repository.dart';
import 'data/instructor_repository.dart';
import 'instructor_page.dart' show AccessChip, routineStatsLabel;
import 'providers.dart';
import 'send_template_sheet.dart';

/// Ficha del alumno: acceso, constancia y rutinas que tiene asignadas.
/// Todo lo que se ve acá es de lectura salvo las rutinas, que el instructor
/// envía y retira.
class ClientDetailPage extends ConsumerWidget {
  const ClientDetailPage({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    final client = ref
        .watch(clientsProvider)
        .asData
        ?.value
        .where((c) => c.id == clientId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/instructor'),
        ),
        title: Text(
          client?.email ?? 'Alumno',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ac.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(clientActivityProvider(clientId));
          ref.invalidate(clientRoutinesProvider(clientId));
          ref.invalidate(clientsProvider);
          await ref.read(clientsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (client != null) _ClientHeader(client: client),
            const SizedBox(height: 24),
            _SectionLabel('ACTIVIDAD'),
            const SizedBox(height: 8),
            _ActivityCard(clientId: clientId),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel('RUTINAS'),
                TextButton.icon(
                  onPressed: () =>
                      showTemplatePicker(context, clientId: clientId),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Enviar plantilla'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _ClientRoutines(clientId: clientId),
          ],
        ),
      ),
    );
  }
}

// ── Cabecera ──────────────────────────────────────────────────────────────────

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return NeuroCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kSeed.withValues(alpha: 0.16),
            ),
            child: Text(
              client.email.isNotEmpty ? client.email[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kSeed,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ac.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                AccessChip(client: client),
                if (client.createdAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Alumno desde ${_dateLabel(client.createdAt!)}',
                    style: TextStyle(fontSize: 11, color: ac.textDisabled),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actividad ─────────────────────────────────────────────────────────────────

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncActivity = ref.watch(clientActivityProvider(clientId));
    final ac = AppColors.of(context);

    return asyncActivity.when(
      loading: () => const NeuroCard(
        radius: 16,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => NeuroCard(
        radius: 16,
        child: Text(
          'No se pudo cargar la actividad.\n$e',
          style: TextStyle(fontSize: 12, color: ac.textMuted, height: 1.4),
        ),
      ),
      data: (a) => NeuroCard(
        radius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Stat(value: '${a.streak}', label: 'RACHA'),
                _Stat(value: '${a.thisWeek}', label: 'SEMANA'),
                _Stat(value: '${a.thisMonth}', label: 'MES'),
                _Stat(value: '${a.total}', label: 'TOTAL'),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: ac.dividerColor),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.event_available_rounded,
              text: a.lastSessionAt == null
                  ? 'Todavía no registró ningún entreno'
                  : 'Último entreno ${_agoLabel(a.lastSessionAt!)}',
            ),
            if (a.lastWeightKg != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.monitor_weight_outlined,
                text: '${_fmt(a.lastWeightKg!)} kg'
                    '${a.lastWeightAt == null ? '' : ' · ${_dateLabel(a.lastWeightAt!)}'}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ac.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: ac.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: ac.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: ac.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ── Rutinas del alumno ────────────────────────────────────────────────────────

class _ClientRoutines extends ConsumerWidget {
  const _ClientRoutines({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutines = ref.watch(clientRoutinesProvider(clientId));
    final ac = AppColors.of(context);

    return asyncRoutines.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No se pudieron cargar las rutinas.\n$e',
          style: TextStyle(fontSize: 12, color: ac.textMuted, height: 1.4),
        ),
      ),
      data: (routines) {
        if (routines.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Sin rutinas todavía. Mandale una plantilla para que tenga qué '
              'entrenar.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: ac.textDisabled,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final r in routines)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _RoutineRow(
                  routine: r,
                  onRemove: () => _confirmRemove(context, ref, r),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    // Se toma antes del diálogo: después del await este context puede haberse
    // desmontado y `of(context)` lanzaría.
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar la rutina?'),
        content: Text(
          '"${routine.name}" desaparece de la app de tu alumno. Los entrenos '
          'que ya hizo con ella se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(instructorRepositoryProvider).removeClientRoutine(routine.id);
      ref.invalidate(clientRoutinesProvider(clientId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine, required this.onRemove});
  final Routine routine;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return NeuroCard(
      radius: 14,
      size: NeuroSize.sm,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        routine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ac.textPrimary,
                        ),
                      ),
                    ),
                    if (routine.isAssigned) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kSeed.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'ENVIADA',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: kSeed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [routineStatsLabel(routine), _daysLabel(routine)]
                      .where((s) => s.isNotEmpty)
                      .join('  ·  '),
                  style: TextStyle(fontSize: 11, color: ac.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
            ),
            tooltip: 'Quitar rutina',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _shortDays = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

String _daysLabel(Routine r) {
  if (r.daysOfWeek.isEmpty) return '';
  final sorted = [...r.daysOfWeek]..sort();
  return sorted.map((d) => _shortDays[d]).join(' · ');
}

String _dateLabel(DateTime d) {
  final local = d.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _agoLabel(DateTime d) {
  final days = DateTime.now().difference(d.toLocal()).inDays;
  if (days <= 0) return 'hoy';
  if (days == 1) return 'ayer';
  if (days < 30) return 'hace $days días';
  return 'el ${_dateLabel(d)}';
}

String _fmt(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

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
