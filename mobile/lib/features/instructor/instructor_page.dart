import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../routines/data/routines_repository.dart';
import '../routines/providers.dart';
import '../routines/routine_form_page.dart';
import '../links/link_requests_section.dart';
import '../links/link_search_sheet.dart';
import '../links/providers.dart';
import 'data/instructor_repository.dart';
import 'providers.dart';

/// Panel del instructor: sus alumnos y su biblioteca de plantillas.
class InstructorPage extends ConsumerWidget {
  const InstructorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ac = AppColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            'Instructor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ac.textPrimary,
            ),
          ),
          bottom: TabBar(
            indicatorColor: kSeed,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: kSeed,
            unselectedLabelColor: ac.textMuted,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            tabs: const [
              Tab(text: 'ALUMNOS'),
              Tab(text: 'PLANTILLAS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ClientsTab(), _TemplatesTab()],
        ),
      ),
    );
  }
}

// ── Alumnos ───────────────────────────────────────────────────────────────────

class _ClientsTab extends ConsumerWidget {
  const _ClientsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClients = ref.watch(clientsProvider);
    final ac = AppColors.of(context);

    return asyncClients.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        title: 'No se pudieron cargar tus alumnos',
        message: e.toString(),
      ),
      data: (clients) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingLinksProvider);
          ref.invalidate(clientsProvider);
          await ref.read(clientsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _PrimaryAction(
              icon: Icons.person_search_rounded,
              label: 'Buscar alumno',
              onTap: () => _findClient(context, ref),
            ),
            const SizedBox(height: 16),
            const LinkRequestsSection(),
            if (clients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.groups_outlined, size: 44, color: ac.textMuted),
                    const SizedBox(height: 14),
                    Text(
                      'Todavía no tenés alumnos.',
                      style: TextStyle(color: ac.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buscalo por el email con el que se registró y mandale '
                      'una solicitud.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ac.textDisabled,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final c in clients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ClientCard(client: c),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _findClient(BuildContext context, WidgetRef ref) async {
    final sent = await LinkSearchSheet.show(
      context,
      lookingForInstructor: false,
    );
    // La solicitud queda pendiente: el alumno todavía no es alumno, así que lo
    // que cambia es la bandeja de enviadas, no la lista.
    if (sent == true) ref.invalidate(pendingLinksProvider);
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: () => context.push('/instructor/alumnos/${client.id}'),
      child: NeuroCard(
        radius: 16,
        size: NeuroSize.sm,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kSeed.withValues(alpha: 0.16),
              ),
              child: Text(
                client.email.isNotEmpty ? client.email[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kSeed,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ac.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AccessChip(client: client),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: ac.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de acceso del alumno: bloqueada, vencida o días que le quedan.
class AccessChip extends StatelessWidget {
  const AccessChip({super.key, required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    final days = client.daysLeft;

    late final String label;
    late final Color color;
    if (client.isBlocked) {
      label = 'Bloqueada';
      color = error;
    } else if (days == null) {
      label = 'Sin vencimiento';
      color = ac.textMuted;
    } else if (days < 0) {
      label = 'Vencida hace ${-days} d';
      color = error;
    } else if (days <= 7) {
      label = days == 0 ? 'Vence hoy' : 'Vence en $days d';
      color = Colors.amber;
    } else {
      label = '$days días de acceso';
      color = kSeed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Plantillas ────────────────────────────────────────────────────────────────

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplates = ref.watch(templatesProvider);
    final ac = AppColors.of(context);

    return asyncTemplates.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        title: 'No se pudieron cargar las plantillas',
        message: e.toString(),
      ),
      data: (templates) => RefreshIndicator(
        onRefresh: () => ref.refresh(routinesProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _PrimaryAction(
              icon: Icons.add_rounded,
              label: 'Nueva plantilla',
              onTap: () => _createTemplate(context, ref),
            ),
            const SizedBox(height: 16),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 44, color: ac.textMuted),
                    const SizedBox(height: 14),
                    Text(
                      'Sin plantillas todavía.',
                      style: TextStyle(color: ac.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Armá una rutina modelo una vez y mandásela a todos los '
                      'alumnos que quieras.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ac.textDisabled,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final t in templates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TemplateCard(template: t),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTemplate(BuildContext context, WidgetRef ref) async {
    String? createdId;

    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RoutineFormPage(
          title: 'Nueva plantilla',
          onSave: (name, days) async {
            createdId = await ref
                .read(routinesRepositoryProvider)
                .createRoutine(name: name, daysOfWeek: days, isTemplate: true);
            ref.invalidate(routinesProvider);
          },
        ),
      ),
    );

    // Recién acá: el formulario se cierra solo al guardar, y navegar antes
    // haría que ese pop se llevara puesta la pantalla del detalle.
    if (createdId != null && context.mounted) {
      context.push('/rutinas/$createdId');
    }
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final Routine template;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: () => context.push('/rutinas/${template.id}'),
      child: NeuroCard(
        radius: 16,
        size: NeuroSize.sm,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kSeed.withValues(alpha: 0.14),
              ),
              child: const Icon(Icons.description_rounded,
                  size: 18, color: kSeed),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
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
                    routineStatsLabel(template),
                    style: TextStyle(fontSize: 11, color: ac.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: ac.textDisabled),
          ],
        ),
      ),
    );
  }
}

// ── Compartido ────────────────────────────────────────────────────────────────

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: ac.bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            ...ac.raised(NeuroSize.sm),
            BoxShadow(color: kSeed.withValues(alpha: 0.10), blurRadius: 18),
          ],
          border: Border.all(color: kSeed.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: kSeed),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: kSeed,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.error_outline,
            size: 44, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: ac.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

/// "5 ej. · ~45 min" — mismo cálculo que usa la lista de rutinas.
String routineStatsLabel(Routine r) {
  final exCount = r.exercises.length;
  if (exCount == 0) return 'Sin ejercicios';
  final totalSets = r.exercises.fold<int>(0, (a, e) => a + e.targetSets);
  final totalRest =
      r.exercises.fold<int>(0, (a, e) => a + e.targetSets * e.restSeconds);
  final raw = (totalSets * 30 + totalRest) / 60;
  final minutes = (raw / 5).round() * 5;
  return '$exCount ej. · ~${minutes < 5 ? 5 : minutes} min';
}
