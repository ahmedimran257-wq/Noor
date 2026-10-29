import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_service.dart';

/// One shared, short-lived copy of the signed-in member's own account rows.
///
/// A cold start used to send the same `users` and `my_profile_private` reads
/// from auth, billing, chat, discovery and onboarding independently. Readers
/// now share one request and a short freshness window, following the
/// `PhotoVerificationService.fetchStatus` pattern.
///
/// Every write the app sends through Supabase clears all shared reads (see
/// [AccountSnapshotInvalidatingClient]), so a member's own change is never
/// read back stale. Reads that must observe server-side changes, such as
/// account standing after a moderation push, pass `force: true`.
class MyAccountSnapshot {
  MyAccountSnapshot._();

  static final instance = MyAccountSnapshot._();

  static const freshness = Duration(seconds: 30);

  /// Union of the `users` columns the app reads for the signed-in member.
  /// Column grants on `users` are explicit, so this never selects `*`.
  static const userColumns = '''
    gender, onboarding_step, is_guardian_path, profile_owner_type,
    onboarding_completed, account_role, email, country_code, is_banned,
    messaging_suspended_until, onboarding_profile_for,
    onboarding_profile_creator_relation, onboarding_city_id,
    onboarding_city_name, onboarding_state_name, onboarding_postal_code,
    onboarding_lat, onboarding_lng
  ''';

  /// Union of the `my_profile_private` columns the app reads for the
  /// signed-in member, including everything onboarding restores.
  static const profileColumns = '''
    id, visibility, onboarding_completed, onboarding_step, approved_at,
    is_boosted, boost_expires_at, boost_last_activated_at,
    profile_owner_type, profile_creator_relation, guardian_mode,
    guardian_user_id, ward_relationship, relationship_to_ward, date_of_birth, gender,
    complexion, sect, deen_level, employment_status, family_type,
    previously_married, first_name, last_name, city_id, country_code,
    height_cm, mother_tongue, community, residency_status, sub_sect,
    prays_five_daily, hijab, beard, diet_type, smoking_habit, vaping_habit,
    hookah_habit, education_rank, education_level, field_of_study, profession,
    income_bracket, income_visibility, sibling_count, is_eldest_child,
    parents_status, children_count, living_expectation, bio, interests,
    languages, photo_privacy, quran_memorization, religious_education,
    marriage_timeline, willing_to_relocate, niqab_preference, mahr_expectation,
    willing_to_work_after_marriage, mahr_budget, can_provide_housing,
    can_provide_maintenance, debt_status, religious_leadership, guardian_name,
    guardian_email, guardian_authority_scope,
    is_revert, polygamy_status, polygamy_acceptance, special_needs
  ''';

  final _user = AccountScopedRead<Map<String, dynamic>?>(
    freshness: freshness,
    load: (userId) => SupabaseService.client
        .from('users')
        .select(userColumns)
        .eq('id', userId)
        .maybeSingle(),
  );

  final _profile = AccountScopedRead<Map<String, dynamic>?>(
    freshness: freshness,
    load: (userId) => SupabaseService.client
        .from('my_profile_private')
        .select(profileColumns)
        .eq('user_id', userId)
        .maybeSingle(),
  );

  /// The member's `users` row, or null when it does not exist yet.
  Future<Map<String, dynamic>?> user(String userId, {bool force = false}) =>
      _user.read(userId, force: force).then(_copy);

  /// The member's `my_profile_private` row, or null before the profile row
  /// is created during onboarding.
  Future<Map<String, dynamic>?> profile(String userId, {bool force = false}) =>
      _profile.read(userId, force: force).then(_copy);

  // Each reader gets its own map so one cannot edit another's view.
  static Map<String, dynamic>? _copy(Map<String, dynamic>? row) =>
      row == null ? null : Map<String, dynamic>.of(row);

  /// Drops every shared account read. Called for each write and on sign-out.
  static void invalidate() => AccountScopedRead.invalidateAll();
}

/// A per-member read shared by concurrent callers and reused for
/// [freshness]. A zero freshness only joins a request already in flight.
class AccountScopedRead<T> {
  AccountScopedRead({required this.load, this.freshness = Duration.zero}) {
    _all.add(this);
  }

  final Future<T> Function(String userId) load;
  final Duration freshness;

  // Shared reads are long-lived service fields, so holding them strongly
  // lets sign-out release every cached account row at once.
  static final _all = <AccountScopedRead<Object?>>[];
  static int _generation = 0;

  /// Invalidates every [AccountScopedRead]. A request already in flight when
  /// this runs is neither joined by later callers nor cached.
  static void invalidateAll() {
    _generation++;
    for (final read in _all) {
      read._clearValue();
    }
  }

  void _clearValue() {
    _value = null;
    _hasValue = false;
    _valueFor = null;
    _valueAt = null;
  }

  T? _value;
  bool _hasValue = false;
  String? _valueFor;
  int _valueGeneration = -1;
  DateTime? _valueAt;

  Future<T>? _inFlight;
  String? _inFlightFor;
  int _inFlightGeneration = -1;

  Future<T> read(String userId, {bool force = false}) {
    final generation = _generation;
    final valueAt = _valueAt;
    if (!force &&
        _hasValue &&
        _valueFor == userId &&
        _valueGeneration == generation &&
        valueAt != null &&
        DateTime.now().difference(valueAt) < freshness) {
      return Future.value(_value as T);
    }
    final pending = _inFlight;
    if (!force &&
        pending != null &&
        _inFlightFor == userId &&
        _inFlightGeneration == generation) {
      return pending;
    }
    late final Future<T> request;
    request = load(userId).then((value) {
      if (_generation == generation) {
        _value = value;
        _hasValue = true;
        _valueFor = userId;
        _valueGeneration = generation;
        _valueAt = DateTime.now();
      }
      return value;
    }).whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
    _inFlight = request;
    _inFlightFor = userId;
    _inFlightGeneration = generation;
    return request;
  }
}

/// Clears shared account reads after any Supabase write completes.
///
/// Hooking the HTTP layer covers every RPC, table write, Storage upload and
/// Edge Function the app sends, including ones added later, instead of
/// relying on each writer to remember an invalidation call. Only RPCs that
/// are read-only or never touch the member's account rows are exempt.
class AccountSnapshotInvalidatingClient extends http.BaseClient {
  AccountSnapshotInvalidatingClient([http.Client? inner])
      : _inner = inner ?? http.Client();

  final http.Client _inner;

  static const _readOnlyRpcPrefixes = ['get_', 'can_', 'search_', 'email_'];
  static const _accountNeutralRpcs = {
    // Only clears deletion_* columns, none of which the snapshot holds.
    'cancel_my_account_deletion',
    'record_user_presence',
    'record_discovery_inventory',
    'record_profile_view',
    'register_my_fcm_token',
    'unregister_my_fcm_token',
  };
  // The locale sync patches these on every launch; the snapshot holds
  // neither, so a patch limited to them leaves it valid.
  static const _accountNeutralUserFields = {'preferred_language', 'timezone'};

  static bool isAccountWrite(http.BaseRequest request) {
    final method = request.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD' || method == 'OPTIONS') {
      return false;
    }
    final segments = request.url.pathSegments;
    if (segments.isEmpty) return false;
    // Auth token refreshes and sign-in calls do not change account rows; a
    // different member is handled because every read is keyed by user id.
    if (segments.first == 'auth') return false;
    final rpcIndex = segments.indexOf('rpc');
    if (segments.first == 'rest' && rpcIndex >= 0) {
      if (rpcIndex + 1 >= segments.length) return true;
      final name = segments[rpcIndex + 1];
      if (_accountNeutralRpcs.contains(name)) return false;
      if (name == 'patch_my_user') return !_patchesOnlyNeutralFields(request);
      return !_readOnlyRpcPrefixes.any(name.startsWith);
    }
    return true;
  }

  static bool _patchesOnlyNeutralFields(http.BaseRequest request) {
    if (request is! http.Request) return false;
    try {
      final body = jsonDecode(request.body);
      final fields = body is Map ? body['p_fields'] : null;
      return fields is Map &&
          fields.isNotEmpty &&
          fields.keys.every(_accountNeutralUserFields.contains);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final write = isAccountWrite(request);
    try {
      return await _inner.send(request);
    } finally {
      // Invalidate after the server has answered, so a read that started
      // while the write was in flight cannot repopulate the snapshot.
      if (write) MyAccountSnapshot.invalidate();
    }
  }

  @override
  void close() => _inner.close();
}
