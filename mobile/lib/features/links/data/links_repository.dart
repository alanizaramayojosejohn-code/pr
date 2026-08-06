import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase/client.dart';

/// Una cuenta encontrada por email, candidata a vincularse.
class LinkCandidate {
  const LinkCandidate({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;
  final String email;
  final String role;

  bool get isInstructor => role == 'instructor';

  factory LinkCandidate.fromJson(Map<String, dynamic> json) => LinkCandidate(
        id: json['id'] as String,
        email: (json['email'] as String?) ?? '—',
        role: (json['role'] as String?) ?? 'user',
      );
}

/// Solicitud pendiente, vista desde quien la consulta.
class LinkRequest {
  const LinkRequest({
    required this.id,
    required this.counterpartId,
    required this.counterpartEmail,
    required this.counterpartRole,
    required this.iRequested,
    required this.createdAt,
  });

  final String id;
  final String counterpartId;
  final String counterpartEmail;
  final String counterpartRole;

  /// true = la mandé yo y espero respuesta. false = me toca responder.
  final bool iRequested;
  final DateTime createdAt;

  factory LinkRequest.fromJson(Map<String, dynamic> json) => LinkRequest(
        id: json['id'] as String,
        counterpartId: json['counterpart_id'] as String,
        counterpartEmail: (json['counterpart_email'] as String?) ?? '—',
        counterpartRole: (json['counterpart_role'] as String?) ?? 'user',
        iRequested: (json['i_requested'] as bool?) ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}

/// Vinculación instructor ↔ alumno.
///
/// Todo pasa por funciones `security definer`: `instructor_links` no tiene
/// políticas de escritura, así que la app no puede inventar un vínculo ni
/// aceptarlo por la otra parte aunque se manipule el cliente.
class LinksRepository {
  Future<LinkCandidate?> findByEmail(String email) async {
    try {
      final res = await supabase.rpc(
        'find_link_candidate',
        params: {'p_email': email.trim().toLowerCase()},
      );
      final rows = (res as List?) ?? const [];
      if (rows.isEmpty) return null;
      return LinkCandidate.fromJson(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> sendRequest(String email) async {
    try {
      await supabase.rpc(
        'send_link_request',
        params: {'p_target_email': email.trim().toLowerCase()},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> respond(String linkId, {required bool accept}) async {
    try {
      await supabase.rpc(
        'respond_link_request',
        params: {'p_link_id': linkId, 'p_accept': accept},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> cancel(String linkId) async {
    try {
      await supabase.rpc('cancel_link_request', params: {'p_link_id': linkId});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> endLink(String clientId) async {
    try {
      await supabase
          .rpc('end_instructor_link', params: {'p_client_id': clientId});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<List<LinkRequest>> fetchPending() async {
    final res = await supabase.rpc('my_link_requests');
    return ((res as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LinkRequest.fromJson)
        .toList();
  }

  /// Email del instructor a cargo. Null si el alumno todavía no tiene.
  Future<String?> fetchMyInstructorEmail() async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return null;

    final mine = await supabase
        .from('profiles')
        .select('instructor_id')
        .eq('id', me)
        .maybeSingle();

    final instructorId = mine?['instructor_id'] as String?;
    if (instructorId == null) return null;

    final row = await supabase
        .from('profiles')
        .select('email')
        .eq('id', instructorId)
        .maybeSingle();
    return row?['email'] as String?;
  }
}
