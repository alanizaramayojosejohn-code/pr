import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/client.dart';
import '../theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.davidmorales.pr://callback',
      );
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBg,
        body: AppGradient(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand
                      Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kSeed.withValues(alpha: 0.15),
                              border: Border.all(
                                  color: kSeed.withValues(alpha: 0.35),
                                  width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '●',
                              style: TextStyle(color: kSeed, fontSize: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'PR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                              color: Color(0xF2FFFFFF),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Personal Record',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                              color: Color(0x66FFFFFF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        radius: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _email,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                labelStyle:
                                    TextStyle(color: Color(0x99FFFFFF)),
                                prefixIcon: Icon(Icons.mail_outline_rounded,
                                    color: Color(0x66FFFFFF), size: 18),
                              ),
                              style: const TextStyle(color: Color(0xF2FFFFFF)),
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              enableSuggestions: false,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pass,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                                labelStyle:
                                    TextStyle(color: Color(0x99FFFFFF)),
                                prefixIcon: Icon(Icons.lock_outline_rounded,
                                    color: Color(0x66FFFFFF), size: 18),
                              ),
                              style: const TextStyle(color: Color(0xF2FFFFFF)),
                              obscureText: true,
                              onSubmitted: (_) => _signIn(),
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
                              onPressed: _loading ? null : _signIn,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: const StadiumBorder(),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Entrar'),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    'o',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _loading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: const StadiumBorder(),
                                side: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.18)),
                                foregroundColor:
                                    Colors.white.withValues(alpha: 0.85),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _GoogleLogo(),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Continuar con Google',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    const segments = [
      (startAngle: -0.2,  sweep: 1.77, color: Color(0xFF4285F4)),
      (startAngle: 1.57,  sweep: 1.57, color: Color(0xFF34A853)),
      (startAngle: 3.14,  sweep: 0.79, color: Color(0xFFFBBC05)),
      (startAngle: 3.93,  sweep: 1.40, color: Color(0xFFEA4335)),
    ];

    for (final seg in segments) {
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
        seg.startAngle,
        seg.sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
