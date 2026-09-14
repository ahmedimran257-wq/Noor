import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

@immutable
class ProfileViewActivitySummary {
  const ProfileViewActivitySummary({
    required this.weeklyViewerCount,
    required this.unseenViewerCount,
  });

  final int weeklyViewerCount;
  final int unseenViewerCount;
}

/// Server-authoritative profile-view analytics.
///
/// Recording is idempotent per viewer/profile/day in Postgres. A detail-page
/// view can also enqueue a generic, throttled owner notification. The free
/// tier can read its aggregate weekly count; viewer identities remain
/// Premium-only.
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
        params: {
          'p_viewed_user_id': viewedUserId,
          'p_notify_owner': true,
        },
      );
    } catch (error) {
      debugPrint('[ProfileViewService] record failed: $error');
    }
  }

  Future<int> weeklyDistinctCount() async {
    final summary = await activitySummary();
    return summary.weeklyViewerCount;
  }

  Future<ProfileViewActivitySummary> activitySummary() async {
    if (!SupabaseService.isInitialized) {
      return const ProfileViewActivitySummary(
        weeklyViewerCount: 0,
        unseenViewerCount: 0,
      );
    }
    final response = await SupabaseService.client.rpc(
      'get_my_profile_view_summary',
    );
    final rows = response as List<dynamic>;
    if (rows.isEmpty) {
      return const ProfileViewActivitySummary(
        weeklyViewerCount: 0,
        unseenViewerCount: 0,
      );
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    return ProfileViewActivitySummary(
      weeklyViewerCount: (row['viewer_count'] as num?)?.toInt() ?? 0,
      unseenViewerCount: (row['unseen_viewer_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> markSeen() async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client.rpc('mark_profile_views_seen');
      return true;
    } catch (error) {
      debugPrint('[ProfileViewService] mark seen failed: $error');
      return false;
    }
  }
}
