import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import 'account_standing_state.dart';

/// One authoritative, realtime account-standing source for the whole app.
///
/// Deliberately does not read or expose shadowban fields. A shadowban is a
/// silent abuse-control mechanism; user-visible enforcement belongs in the
/// suspended or banned states.
class AccountStandingCubit extends Cubit<AccountStandingState> {
  AccountStandingCubit() : super(const AccountStandingState());

  String? _userId;
  RealtimeChannel? _channel;
  int _loadVersion = 0;

  Future<void> start(String userId) async {
    if (_userId == userId && _channel != null) {
      await refresh();
      return;
    }
    await stop();
    _userId = userId;
    emit(const AccountStandingState(loading: true));
    await refresh();
    if (isClosed || _userId != userId) return;
    _channel = SupabaseService.client
        .channel('account_standing_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => unawaited(refresh()),
        )
        .subscribe();
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null || !SupabaseService.isInitialized) return;
    final version = ++_loadVersion;
    try {
      final profile = await SupabaseService.client
          .from('my_profile_private')
          .select('id, visibility')
          .eq('user_id', userId)
          .maybeSingle();
      final user = await SupabaseService.client
          .from('users')
          .select('is_banned')
          .eq('id', userId)
          .maybeSingle();

      var hasPublishedPhoto = false;
      final profileId = profile?['id']?.toString();
      if (profileId != null && profileId.isNotEmpty) {
        final photo = await SupabaseService.client
            .from('photos')
            .select('id')
            .eq('profile_id', profileId)
            .eq('order_index', 0)
            .eq('status', 'active')
            .eq('admin_approved', true)
            .eq('nsfw_cleared', true)
            .limit(1);
        hasPublishedPhoto = (photo as List<dynamic>).isNotEmpty;
      }
      if (isClosed || version != _loadVersion || _userId != userId) return;

      final visibility = profile?['visibility']?.toString() ?? 'paused';
      final isBanned = user?['is_banned'] == true;
      final kind = isBanned
          ? AccountStandingKind.banned
          : switch (visibility) {
              'visible' => AccountStandingKind.active,
              'suspended' => AccountStandingKind.suspended,
              'deactivated' => AccountStandingKind.deactivated,
              _ => AccountStandingKind.paused,
            };
      emit(AccountStandingState(
        kind: kind,
        hasPublishedPhoto: hasPublishedPhoto,
      ));
    } catch (_) {
      if (isClosed || version != _loadVersion || _userId != userId) return;
      emit(state.copyWith(
        loading: false,
        errorMessage: 'Account status could not be refreshed.',
      ));
    }
  }

  Future<bool> resumeProfile() async {
    if (state.updating || state.kind != AccountStandingKind.paused) {
      return false;
    }
    emit(state.copyWith(updating: true, clearError: true));
    try {
      await SupabaseService.client.rpc(
        'set_profile_pause',
        params: {'p_paused': false},
      );
      await refresh();
      return state.kind == AccountStandingKind.active;
    } on PostgrestException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          updating: false,
          errorMessage: error.message.split('\n').first,
        ));
      }
      return false;
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(
          updating: false,
          errorMessage: 'Your profile could not be resumed. Please try again.',
        ));
      }
      return false;
    }
  }

  Future<void> stop() async {
    _userId = null;
    _loadVersion++;
    final channel = _channel;
    _channel = null;
    if (channel != null) await channel.unsubscribe();
    if (!isClosed) emit(const AccountStandingState());
  }

  @override
  Future<void> close() async {
    await stop();
    return super.close();
  }
}
