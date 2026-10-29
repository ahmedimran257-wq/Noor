import 'package:flutter/foundation.dart';

import 'my_account_snapshot.dart';
import 'supabase_service.dart';

/// Reads the small per-member relationship revision used by relationship
/// surfaces. This avoids reloading bounded-but-larger inbox queries merely
/// because a tab was selected or the app briefly resumed.
class RelationshipRevisionService {
  const RelationshipRevisionService._();

  // Chat and Interests check the revision together at startup and resume.
  // Concurrent checks share one request; a token is never reused once that
  // request has answered, so a later check always sees the server.
  static final _revision = AccountScopedRead<Object?>(
    load: (_) => SupabaseService.client.rpc('get_my_relationship_revision'),
  );

  static Future<String?> readToken() async {
    if (!SupabaseService.isInitialized) return null;
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) return null;

    try {
      final response = await _revision.read(userId);
      if (response is! List || response.isEmpty) return null;
      final row = Map<String, dynamic>.from(response.first as Map);
      final token = row['revision_token']?.toString();
      return token == null || token.isEmpty ? null : token;
    } catch (error) {
      // Revision reads are an optimization. The surface freshness fallback
      // remains authoritative if this tiny RPC is temporarily unavailable.
      debugPrint('Relationship revision check unavailable: $error');
      return null;
    }
  }
}
