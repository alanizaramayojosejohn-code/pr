import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../routines/data/routines_repository.dart';
import '../routines/providers.dart';
import 'instructor_page.dart' show routineStatsLabel;
import 'providers.dart';

/// Desde una plantilla: elegir a qué alumnos mandársela.
Future<void> showClientPicker(
  BuildContext context, {
  required Routine template,
}) {
  return _showSheet(context, _ClientPicker(template: template));
}

/// Desde la ficha de un alumno: elegir qué plantilla mandarle.
Future<void> showTemplatePicker(
  BuildContext context, {
  required String clientId,
}) {
  return _showSheet(context, _TemplatePicker(clientId: clientId));
}

Future<void> _showSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SafeArea(child: child),
  );
}

// ── Elegir alumnos para una plantilla ─────────────────────────────────────────

class _ClientPicker extends ConsumerStatefulWidget {
  const _ClientPicker({required this.template});
  final Routine template;

  @override
  ConsumerState<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<_ClientPicker> {
  final _selected = <String>{};
  bool _sending = false;

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);

    final repo = ref.read(instructorRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      for (final clientId in _selected) {
        await repo.assignTemplate(
          templateId: widget.template.id,
          clientId: clientId,
        );
        ref.invalidate(clientRoutinesProvider(clientId));
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _selected.length == 1
                ? 'Rutina enviada.'
                : 'Rutina enviada a ${_selected.length} alumnos.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(_clean(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncClients = ref.watch(clientsProvider);
    final ac = AppColors.of(context);

    return _SheetFrame(
      title: 'Enviar "${widget.template.name}"',
      subtitle: 'Se copia a la cuenta de cada alumno que elijas.',
      child: asyncClients.when(
        loading: () => const _SheetLoading(),
        error: (e, _) => _SheetMessage(text: _clean(e)),
        data: (clients) {
          if (clients.isEmpty) {
            return const _SheetMessage(
              text: 'Todavía no tenés alumnos a quien enviarle esto.',
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: clients.length,
                  itemBuilder: (context, i) {
                    final c = clients[i];
                    final checked = _selected.contains(c.id);
                    return CheckboxListTile(
                      value: checked,
                      activeColor: kSeed,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        c.email,
                        style: TextStyle(fontSize: 14, color: ac.textPrimary),
                      ),
                      subtitle: c.isBlocked
                          ? Text(
                              'Cuenta bloqueada',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            )
                          : null,
                      onChanged: _sending
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  _selected.add(c.id);
                                } else {
                                  _selected.remove(c.id);
                                }
                              }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _selected.isEmpty || _sending ? null : _send,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder(),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _selected.isEmpty
                            ? 'Elegí al menos un alumno'
                            : 'Enviar a ${_selected.length}',
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Elegir plantilla para un alumno ───────────────────────────────────────────

class _TemplatePicker extends ConsumerStatefulWidget {
  const _TemplatePicker({required this.clientId});
  final String clientId;

  @override
  ConsumerState<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends ConsumerState<_TemplatePicker> {
  bool _sending = false;

  Future<void> _send(Routine template) async {
    setState(() => _sending = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref.read(instructorRepositoryProvider).assignTemplate(
            templateId: template.id,
            clientId: widget.clientId,
          );
      ref.invalidate(clientRoutinesProvider(widget.clientId));
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('"${template.name}" enviada.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(_clean(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncTemplates = ref.watch(templatesProvider);
    final ac = AppColors.of(context);

    return _SheetFrame(
      title: 'Enviar plantilla',
      subtitle: 'Si ya le mandaste esta plantilla, se actualiza la que tiene.',
      child: asyncTemplates.when(
        loading: () => const _SheetLoading(),
        error: (e, _) => _SheetMessage(text: _clean(e)),
        data: (templates) {
          if (templates.isEmpty) {
            return const _SheetMessage(
              text: 'No tenés plantillas. Creá una desde la pestaña '
                  'Plantillas.',
            );
          }
          return Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (context, i) {
                final t = templates[i];
                return ListTile(
                  enabled: !_sending,
                  leading: const Icon(Icons.description_rounded,
                      size: 20, color: kSeed),
                  title: Text(
                    t.name,
                    style: TextStyle(fontSize: 14, color: ac.textPrimary),
                  ),
                  subtitle: Text(
                    routineStatsLabel(t),
                    style: TextStyle(fontSize: 11, color: ac.textMuted),
                  ),
                  trailing: Icon(Icons.send_rounded,
                      size: 18, color: ac.textDisabled),
                  onTap: _sending ? null : () => _send(t),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Piezas comunes ────────────────────────────────────────────────────────────

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ac.textDisabled.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ac.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, height: 1.4, color: ac.textMuted),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SheetLoading extends StatelessWidget {
  const _SheetLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.of(context).textMuted,
          ),
        ),
      );
}

String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
