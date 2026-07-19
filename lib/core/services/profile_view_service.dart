import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// Server-authoritative profile-view analytics.
///
/// Recording is idempotent per viewer/profile/day in Postgres. The free tier
/// can read its aggregate weekly count; viewer identities remain Premium-only.
class ProfileViewService {
  ProfileViewService._();

  static final ProfileViewService instance = ProfileViewService._();

  Future<void> record(String viewedUserId) async {
    if (!SupabaseService.isInitialized || viewedUserId.trim().isEmpty) return;
    final me = await SupabaseService.currentUserIdOrRefresh();
    if (me == null || me == viewedUserId) return;
    try {
      await SupabaseService.client.rpc(
        'record_profile_view',
        params: {'p_viewed_user_id': viewedUserId},
      );
    } catch (error) {
      debugPrint('[ProfileViewService] record failed: $error');
    }
  }

  Future<int> weeklyDistinctCount() async {
    if (!SupabaseService.isInitialized) return 0;
    final response = await SupabaseService.client.rpc(
      'get_my_profile_view_summary',
    );
    final rows = response as List<dynamic>;
    if (rows.isEmpty) return 0;
    return (rows.first as Map)['viewer_count'] is num
        ? ((rows.first as Map)['viewer_count'] as num).toInt()
        : 0;
  }
}
