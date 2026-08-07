import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/client.dart';
import '../theme/app_theme.dart';

/// Alta de cuenta propia.
///
/// El perfil lo crea el trigger `on_auth_user_created`, no esta pantalla: si lo
/// insertara el cliente, una cuenta creada por Google se quedaría sin perfil.
/// Nace sin instructor y con la app entera disponible; vincularse es un paso
/// aparte y opcional.
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _needsConfirmation = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _email.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      setState(() => _error = 'Revisá el email.');
      return;
    }
    if (_pass.text.length < 6) {
      setState(() => _error = 'La contraseña necesita al menos 6 caracteres.');
      return;
    }
    if (_pass.text != _pass2.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: _pass.text,
      );
      if (!mounted) return;
      // Con la confirmación por correo activada no hay sesión todavía: no se
      // puede entrar a la app hasta que abra el link.
      if (res.session == null) {
        setState(() => _needsConfirmation = true);
      }
      // Con la sesión ya creada el redirect del router se encarga solo.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ac.overlayStyle,
      child: Scaffold(
        backgroundColor: ac.bg,
        body: AppGradient(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: _needsConfirmation
                        ? _ConfirmNotice(email: _email.text.trim())
                        : _form(ac),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(AppColors ac) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Crear cuenta',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: ac.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Entrenás solo desde el primer día. Vincularte con un instructor es '
          'opcional y se hace después.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5, color: ac.textDisabled),
        ),
        const SizedBox(height: 32),
        GlassCard(
          padding: const EdgeInsets.all(24),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _email,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: ac.textSecondary),
                  prefixIcon: Icon(Icons.mail_outline_rounded,
                      color: ac.textDisabled, size: 18),
                ),
                style: TextStyle(color: ac.textPrimary),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: TextStyle(color: ac.textSecondary),
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: ac.textDisabled, size: 18),
                ),
                style: TextStyle(color: ac.textPrimary),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass2,
                decoration: InputDecoration(
                  labelText: 'Repetir contraseña',
                  labelStyle: TextStyle(color: ac.textSecondary),
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: ac.textDisabled, size: 18),
                ),
                style: TextStyle(color: ac.textPrimary),
                obscureText: true,
                onSubmitted: (_) => _signUp(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _signUp,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _loading ? null : () => context.go('/login'),
          child: Text(
            '¿Ya tenés cuenta? Entrar',
            style: TextStyle(fontSize: 13, color: ac.textMedium),
          ),
        ),
      ],
    );
  }
}

class _ConfirmNotice extends StatelessWidget {
  const _ConfirmNotice({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_unread_outlined, size: 48, color: kSeed),
        const SizedBox(height: 20),
        Text(
          'Confirmá tu correo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ac.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Te mandamos un link a $email. Abrilo y después entrá con tu '
          'contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: ac.textMuted),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => context.go('/login'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          child: const Text('Ir a entrar'),
        ),
      ],
    );
  }
}
