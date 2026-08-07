import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/client.dart';
import 'auth_providers.dart';

/// Fila de `profiles` del usuario logueado. El rol vive en la base, nunca en
/// el JWT: cambiarlo desde el panel tiene efecto en cuanto la app recarga el
/// perfil, sin necesidad de cerrar sesión.
class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.status,
    this.email,
    this.instructorId,
    this.expiresAt,
  });

  final String id;
  final String role; // user | instructor | admin
  final String status; // approved | blocked
  final String? email;
  final String? instructorId;
  final DateTime? expiresAt;

  bool get isInstructor => role == 'instructor';

  factory Profile.fromJson(Map<String, dynamic> json) {
    final expires = json['expires_at'] as String?;
    return Profile(
      id: json['id'] as String,
      role: (json['role'] as String?) ?? 'user',
      status: (json['status'] as String?) ?? 'approved',
      email: json['email'] as String?,
      instructorId: json['instructor_id'] as String?,
      expiresAt: expires == null ? null : DateTime.parse(expires),
    );
  }
}

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentSessionProvider)?.user.id;
  if (userId == null) return null;
  final res = await supabase
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
  return res == null ? null : Profile.fromJson(res);
});

/// Falso mientras el perfil carga: la sección de instructor aparece cuando hay
/// certeza, no antes.
final isInstructorProvider = Provider<bool>((ref) {
  return ref.watch(myProfileProvider).asData?.value?.isInstructor ?? false;
});
