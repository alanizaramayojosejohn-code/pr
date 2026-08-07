import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'data/links_repository.dart';
import 'providers.dart';

/// Buscar a la contraparte por email y mandarle solicitud.
///
/// Sirve para los dos lados: el rol de quien busca decide a quién encuentra, y
/// eso lo resuelve la base (`find_link_candidate`), no esta pantalla.
class LinkSearchSheet extends ConsumerStatefulWidget {
  const LinkSearchSheet({super.key, required this.lookingForInstructor});

  /// Solo cambia los textos. La autorización real vive en la base.
  final bool lookingForInstructor;

  static Future<bool?> show(
    BuildContext context, {
    required bool lookingForInstructor,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          LinkSearchSheet(lookingForInstructor: lookingForInstructor),
    );
  }

  @override
  ConsumerState<LinkSearchSheet> createState() => _LinkSearchSheetState();
}

class _LinkSearchSheetState extends ConsumerState<LinkSearchSheet> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _searched = false;
  String? _error;
  LinkCandidate? _found;

  String get _what => widget.lookingForInstructor ? 'instructor' : 'alumno';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final email = _email.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      setState(() => _error = 'Revisá el email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
      _searched = false;
    });
    try {
      final found = await ref.read(linksRepositoryProvider).findByEmail(email);
      if (!mounted) return;
      setState(() {
        _found = found;
        _searched = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(linksRepositoryProvider).sendRequest(_email.text.trim());
      ref.invalidate(pendingLinksProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: ac.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ac.textDisabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Buscar $_what',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ac.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Escribí el email exacto con el que se registró. Le llega una '
              'solicitud y el vínculo se arma cuando la acepta.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: ac.textDisabled,
              ),
            ),
            const SizedBox(height: 18),
            NeuroCard(
              pressed: true,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                style: TextStyle(color: ac.textPrimary, fontSize: 16),
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Email del $_what',
                  labelStyle: TextStyle(color: ac.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorBox(message: _error!),
            ],
            if (_searched && _found == null && _error == null) ...[
              const SizedBox(height: 14),
              Text(
                'No hay ningún $_what registrado con ese email. Pedile que se '
                'cree la cuenta primero.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: ac.textMuted,
                ),
              ),
            ],
            if (_found != null) ...[
              const SizedBox(height: 16),
              NeuroCard(
                radius: 16,
                size: NeuroSize.sm,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _Avatar(email: _found!.email),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _found!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ac.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : (_found == null ? _search : _send),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_found == null ? 'Buscar' : 'Mandar solicitud'),
            ),
          ],
        ),
      ),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, height: 1.4, color: scheme.error),
      ),
    );
  }
}
