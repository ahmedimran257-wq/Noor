import 'supabase_service.dart';

/// Reads the server's explicit member projection. The RPC proves that each
/// requested profile came from discovery or an existing member relationship;
/// callers never receive the base profiles row.
class AuthorizedProfileService {
  AuthorizedProfileService._();

  static Future<List<Map<String, dynamic>>> load(
    Iterable<String> userIds,
  ) async {
    final ids = userIds
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(50)
        .toList(growable: false);
    if (ids.isEmpty) return const [];
    final raw = await SupabaseService.client.rpc(
      'get_authorized_member_profiles',
      params: {'p_user_ids': ids},
    );
    if (raw is! List) return const [];
    return raw.map<Map<String, dynamic>>((item) {
      if (item is Map && item.length == 1) {
        final nested = item['get_authorized_member_profiles'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
      }
      return Map<String, dynamic>.from(item as Map);
    }).toList(growable: false);
  }
}
