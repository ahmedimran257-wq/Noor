// lib/core/services/profile_write_service.dart
// ============================================================
// NOOR — Profile Write Service
// Maps OnboardingData fields → Supabase column names and
// performs partial upserts per onboarding step.
//
// Used by OnboardingCubit.saveAndAdvance() to persist data
// instead of the mock Future.delayed(600ms).
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding_data.dart';
import 'supabase_service.dart';

class ProfileWriteService {
  ProfileWriteService._();

  /// Whether real writes are possible (Supabase configured).
  static bool get _canWrite => SupabaseService.isInitialized;

  /// Current authenticated user ID, or null.
  static String? get _userId => SupabaseService.currentUserId;

  // ── Step-based partial upsert ─────────────────────────────

  /// Persists the fields modified in [step] to Supabase.
  /// In mock mode (Supabase not configured), simulates a delay.
  /// Returns true on success, false on error.
  static const _keyPendingPhoneRetry = 'pending_guardian_phone_retry';

  /// Retries sending a previously failed guardian phone number RPC update.
  static Future<void> retryPendingGuardianPhone() async {
    if (!_canWrite || _userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingPhone = prefs.getString(_keyPendingPhoneRetry);
      if (pendingPhone == null) return;

      final profileRes = await SupabaseService.client
          .from('profiles')
          .select('id')
          .eq('user_id', _userId!)
          .single();

      await SupabaseService.client.rpc('set_guardian_phone', params: {
        'p_profile_id': profileRes['id'],
        'p_phone': pendingPhone,
      });

      // Success! Clear retry flag
      await prefs.remove(_keyPendingPhoneRetry);
      debugPrint('ProfileWriteService: Successfully retried setting guardian phone');
    } catch (e) {
      debugPrint('ProfileWriteService: Failed retrying guardian phone: $e');
    }
  }

  /// Persists the fields modified in [step] to Supabase.
  /// In mock mode (Supabase not configured), simulates a delay.
  /// Returns true on success, false on error.
  static Future<bool> saveStep({
    required int step,
    required OnboardingData data,
    required bool isGuardianPath,
  }) async {
    if (!_canWrite || _userId == null) {
      // Mock mode: simulate network latency
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    }

    // Attempt retry asynchronously
    retryPendingGuardianPhone();

    try {
      final fields = _fieldsForStep(step, data, isGuardianPath);
      if (fields.isEmpty) {
        debugPrint('ProfileWriteService: No fields to write for step $step');
        return true;
      }

      // Upsert to profiles table
      await SupabaseService.client
          .from('profiles')
          .upsert({
            'user_id': _userId,
            ...fields,
          }, onConflict: 'user_id');

      // If this step includes preferences, upsert those too
      final prefFields = _preferenceFieldsForStep(step, data);
      if (prefFields.isNotEmpty) {
        // Get the profile ID first
        final profileRes = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('user_id', _userId!)
            .single();

        await SupabaseService.client
            .from('profile_preferences')
            .upsert({
              'profile_id': profileRes['id'],
              ...prefFields,
            }, onConflict: 'profile_id');
      }

      // Guardian phone: encrypt via set_guardian_phone() SECURITY DEFINER RPC
      // This must happen AFTER the profiles upsert so the profile row exists.
      if (isGuardianPath && step == 1 && data.guardianPhone != null) {
        try {
          final profileRes = await SupabaseService.client
              .from('profiles')
              .select('id')
              .eq('user_id', _userId!)
              .single();

          await SupabaseService.client.rpc('set_guardian_phone', params: {
            'p_profile_id': profileRes['id'],
            'p_phone': data.guardianPhone,
          });
        } catch (rpcErr) {
          debugPrint('ProfileWriteService: RPC set_guardian_phone failed, queueing for retry: $rpcErr');
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyPendingPhoneRetry, data.guardianPhone!);
          } catch (prefErr) {
            debugPrint('ProfileWriteService: Failed to save phone for retry: $prefErr');
          }
        }
      }

      debugPrint('ProfileWriteService: Step $step saved (${fields.length} fields)');
      return true;
    } catch (e) {
      debugPrint('ProfileWriteService: Error saving step $step: $e');
      return false;
    }
  }

  /// Updates the onboarding_step column on the profiles table.
  static Future<void> updateOnboardingStep(int step) async {
    if (!_canWrite || _userId == null) return;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'onboarding_step': step})
          .eq('user_id', _userId!);
    } catch (e) {
      debugPrint('ProfileWriteService: Error updating step: $e');
    }
  }

  // ── Field mapping per step ────────────────────────────────

  /// Returns a map of DB column → value for the given onboarding step.
  /// Only includes fields that were actually set (non-null).
  static Map<String, dynamic> _fieldsForStep(
    int step,
    OnboardingData data,
    bool isGuardianPath,
  ) {
    // Guardian path shifts steps by +1 (step 1 = guardian details)
    final effectiveStep = isGuardianPath ? step - 1 : step;

    // Guardian details (only on guardian path, step 1)
    if (isGuardianPath && step == 1) {
      // Map 'parent' / 'sibling' / 'guardian' relation to accepted DB constraint ('other' if parent/sibling)
      String? dbRelation = 'other';
      if (data.guardianRelationship == 'guardian') {
        dbRelation = 'other';
      }

      return _compactMap({
        'guardian_name': data.guardianName,
        'guardian_relationship': dbRelation,
        'guardian_email': data.guardianEmail,
        'guardian_authority_scope': data.guardianAuthorityScope,
        'guardian_phone_country_code': data.guardianPhoneCountryCode,
        'guardian_mode': data.guardianMode ?? 'passive',
        'profile_creator_relation': data.profileCreatorRelation == 'son' || data.profileCreatorRelation == 'daughter'
            ? 'parent'
            : (data.profileCreatorRelation == 'brother' || data.profileCreatorRelation == 'sister' ? 'sibling' : data.profileCreatorRelation),
      });
    }

    switch (effectiveStep) {
      // Step 0 — ProfileForWhom (no DB fields, just local state)
      case 0:
        final relation = data.profileCreatorRelation ??
              (data.profileFor == ProfileFor.myself ? 'self' : 'guardian');
        final dbRelation = relation == 'son' || relation == 'daughter'
            ? 'parent'
            : (relation == 'brother' || relation == 'sister' ? 'sibling' : relation);

        return _compactMap({
          'profile_creator_relation': dbRelation,
        });

      // Step 1 — Basic Identity
      case 1:
        return _compactMap({
          'first_name': data.firstName,
          'last_name': data.lastName,
          'date_of_birth': data.dateOfBirth?.toIso8601String().split('T')[0],
          'gender': _genderToString(data.gender),
          'city_id': (data.cityId != null &&
                  RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
                      .hasMatch(data.cityId!))
              ? data.cityId
              : null,
          'country_code': data.countryCode,
          'height_cm': data.heightCm,
          'complexion': data.complexion?.toLowerCase().replaceAll(' ', '_'),
          'mother_tongue': data.motherTongue,
          'community': data.community,
          'residency_status': data.residencyStatus,
          'special_needs': data.specialNeeds, // Fixed Flaw 22: Written in step 1
        });

      // Step 2 — Islamic Identity
      case 2:
        return _compactMap({
          'sect': _sectToString(data.sect),
          'sub_sect': data.subSect,
          'deen_level': _deenLevelToString(data.deenLevel),
          'prays_five_daily': data.praysFiveDaily,
          'hijab': data.hijabStyle,
          'beard': data.beardStyle,
          'diet_type': data.dietType,
          'smoking_habit': data.smokingHabit,
          'vaping_habit': data.vapingHabit,
          'hookah_habit': data.hookahHabit,
        });

      // Step 3 — Islamic Marriage Details
      case 3:
        final fields = <String, dynamic>{
          'quran_memorization': data.quranMemorization,
          'religious_education': data.religiousEducation,
          'is_revert': data.isRevert,
          'marriage_timeline': data.marriageTimeline,
          'willing_to_relocate': data.willingToRelocate,
          'religious_leadership': data.religiousLeadership,
        };

        // Gender-specific fields
        if (data.gender == Gender.female) {
          fields.addAll({
            'niqab_preference': data.niqabPreference,
            'mahr_expectation': data.mahrExpectation,
            'willing_to_work_after_marriage': data.willingToWorkAfterMarriage,
            'polygamy_acceptance': data.polygamyAcceptance,
          });
        } else if (data.gender == Gender.male) {
          fields.addAll({
            'mahr_budget': data.mahrBudget,
            'can_provide_housing': data.canProvideHousing,
            'can_provide_maintenance': data.canProvideMaintenance,
            'debt_status': data.debtStatus,
            'polygamy_status': data.polygamyStatus,
          });
        }

        return _compactMap(fields);

      // Step 4 — Background
      case 4:
        return _compactMap({
          'education_level': data.educationLabel,
          'education_rank': data.educationRank,
          'field_of_study': data.fieldOfStudy,
          'profession': data.profession,
          'employment_status': _employmentStatusToString(data.employmentStatus),
          'income_bracket': data.incomeBracketId, // Fixed Flaw 16: Persisted
          'income_visibility': data.incomeVisibility, // Fixed Flaw 16: Persisted
        });

      // Step 5 — Family
      case 5:
        return _compactMap({
          'family_type': _familyTypeToString(data.familyType),
          'sibling_count': data.siblingCount,
          'is_eldest_child': data.isEldestChild,
          'parents_status': data.parentsStatus,
          'previously_married': data.previouslyMarried,
          'children_count': data.childrenCount,
          'living_expectation': data.livingExpectation,
          // Fixed Flaw 22: 'special_needs' removed here since it is in step 1
        });

      // Step 6 — About Yourself
      case 6:
        return _compactMap({
          'bio': data.bio,
          'interests': data.interests,
          'languages': data.languages,
        });

      // Step 7 — Partner Preferences (written to profile_preferences table)
      case 7:
        return {}; // Handled by _preferenceFieldsForStep

      // Step 8 — Photo Upload (handled by photo upload pipeline)
      case 8:
        return _compactMap({
          'photo_privacy': _photoPrivacyToString(data.photoPrivacy),
        });

      // Step 9 — Profile Preview (no new fields)
      case 9:
        return {};

      // Step 10 — Welcome (no new fields)
      case 10:
        return {};

      default:
        return {};
    }
  }

  /// Returns preference fields for step 7 (partner preferences).
  static Map<String, dynamic> _preferenceFieldsForStep(
    int step,
    OnboardingData data,
  ) {
    // Only step 7 (myself) or 8 (guardian) writes preferences
    final isGuardian = data.profileFor == ProfileFor.guardian;
    final prefStep = isGuardian ? 8 : 7;
    if (step != prefStep) return {};

    return _compactMap({
      'preferred_age_min': data.preferredAgeMin,
      'preferred_age_max': data.preferredAgeMax,
      'sect_preference': data.preferredSect,
      'deen_preference': data.preferredDeenLevel,
      'min_education_rank': data.minEducationRank,
      'open_to_divorced': data.openToDivorced,
      'open_to_widowed': data.openToWidowed,
      'open_to_has_children': data.openToWithChildren,
      'preferred_living_expectation': data.preferredLivingExpectation,
      'diaspora_mode': data.locationPreference == LocationPreference.diaspora,
      'location_preference': data.locationPreference?.name, // Fixed Flaw 21: Persist LocationPreference name
    });
  }

  /// Loads profile data from Supabase for the current user to restore onboarding state.
  static Future<OnboardingData?> loadProfile() async {
    if (!_canWrite || _userId == null) return null;

    try {
      // 1. Fetch profiles table row
      final profileRes = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('user_id', _userId!)
          .maybeSingle();

      if (profileRes == null) return null;

      // 2. Fetch profile_preferences table row if it exists
      Map<String, dynamic>? prefRes;
      try {
        prefRes = await SupabaseService.client
            .from('profile_preferences')
            .select()
            .eq('profile_id', profileRes['id'])
            .maybeSingle();
      } catch (e) {
        debugPrint('ProfileWriteService: Preferences row not found or error: $e');
      }

      // 3. Construct and return OnboardingData
      return _mapDbToOnboardingData(profileRes, prefRes);
    } catch (e) {
      debugPrint('ProfileWriteService: Error loading profile: $e');
      return null;
    }
  }

  static OnboardingData _mapDbToOnboardingData(
    Map<String, dynamic> p,
    Map<String, dynamic>? pr,
  ) {
    final creatorRel = p['profile_creator_relation'] as String?;
    final guardianMode = p['guardian_mode'] as String?;
    final isGuardian = creatorRel != 'self' && (guardianMode != null && guardianMode != 'none');

    // Parse date of birth
    DateTime? dob;
    if (p['date_of_birth'] != null) {
      dob = DateTime.tryParse(p['date_of_birth'] as String);
    }

    // Parse gender
    Gender? gender;
    if (p['gender'] != null) {
      gender = p['gender'] == 'female' ? Gender.female : Gender.male;
    }

    // Parse complexion
    String? complexionVal = p['complexion'] as String?;
    String? complexion;
    if (complexionVal != null) {
      switch (complexionVal) {
        case 'fair': complexion = 'Fair'; break;
        case 'medium': complexion = 'Medium'; break;
        case 'olive': complexion = 'Olive'; break;
        case 'dark': complexion = 'Dark'; break;
        case 'prefer_not_to_say': complexion = 'Prefer not to say'; break;
        default: complexion = complexionVal;
      }
    }

    // Parse sect
    Sect? sect;
    if (p['sect'] != null) {
      switch (p['sect'] as String) {
        case 'sunni': sect = Sect.sunni; break;
        case 'shia': sect = Sect.shia; break;
        case 'prefer_not_to_say': sect = Sect.preferNotToSay; break;
        case 'other': sect = Sect.other; break;
      }
    }

    // Parse deenLevel
    DeenLevel? deen;
    if (p['deen_level'] != null) {
      switch (p['deen_level'] as String) {
        case 'practicing': deen = DeenLevel.practicing; break;
        case 'moderate': deen = DeenLevel.moderate; break;
        case 'cultural': deen = DeenLevel.cultural; break;
      }
    }

    // Parse employmentStatus
    EmploymentStatus? empStatus;
    if (p['employment_status'] != null) {
      switch (p['employment_status'] as String) {
        case 'employed': empStatus = EmploymentStatus.employed; break;
        case 'self_employed': empStatus = EmploymentStatus.selfEmployed; break;
        case 'student': empStatus = EmploymentStatus.student; break;
        case 'not_working': empStatus = EmploymentStatus.notWorking; break;
      }
    }

    // Parse familyType
    FamilyType? famType;
    if (p['family_type'] != null) {
      switch (p['family_type'] as String) {
        case 'nuclear': famType = FamilyType.nuclear; break;
        case 'joint': famType = FamilyType.joint; break;
        case 'extended': famType = FamilyType.extended; break;
      }
    }

    // Parse maritalStatus
    MaritalStatus? marStatus;
    final previouslyMarried = p['previously_married'] as String?;
    if (previouslyMarried != null) {
      switch (previouslyMarried) {
        case 'no': marStatus = MaritalStatus.neverMarried; break;
        case 'divorced': marStatus = MaritalStatus.divorced; break;
        case 'widowed': marStatus = MaritalStatus.widowed; break;
      }
    }

    // Parse LocationPreference
    LocationPreference? locPref;
    if (pr != null) {
      final locPrefStr = pr['location_preference'] as String?;
      if (locPrefStr != null) {
        try {
          locPref = LocationPreference.values.byName(locPrefStr);
        } catch (_) {}
      }
      if (locPref == null) {
        final diaspora = pr['diaspora_mode'] as bool? ?? false;
        if (diaspora) {
          locPref = LocationPreference.diaspora;
        }
      }
    }

    // Map profile_creator_relation back
    String? profileCreatorRelation = creatorRel;
    String? guardianRelationship;
    if (isGuardian) {
      if (creatorRel == 'parent') {
        profileCreatorRelation = gender == Gender.female ? 'daughter' : 'son';
        guardianRelationship = 'parent';
      } else if (creatorRel == 'sibling') {
        profileCreatorRelation = gender == Gender.female ? 'sister' : 'brother';
        guardianRelationship = 'sibling';
      } else if (creatorRel == 'guardian') {
        profileCreatorRelation = 'guardian';
        guardianRelationship = 'guardian';
      }
    }

    return OnboardingData(
      profileFor: isGuardian ? ProfileFor.guardian : ProfileFor.myself,
      firstName: p['first_name'] as String?,
      lastName: p['last_name'] as String?,
      dateOfBirth: dob,
      gender: gender,
      cityId: p['city_id'] as String?,
      cityName: null, // Resolves locally in BasicIdentityScreen via _kCities
      countryCode: p['country_code'] as String?,
      heightCm: p['height_cm'] as int?,
      complexion: complexion,
      motherTongue: p['mother_tongue'] as String?,
      community: p['community'] as String?,
      residencyStatus: p['residency_status'] as String?,
      sect: sect,
      subSect: p['sub_sect'] as String?,
      deenLevel: deen,
      praysFiveDaily: p['prays_five_daily'] as bool?,
      hijabStyle: p['hijab'] as String?,
      beardStyle: p['beard'] as String?,
      dietType: p['diet_type'] as String?,
      smokingHabit: p['smoking_habit'] as String?,
      vapingHabit: p['vaping_habit'] as String?,
      hookahHabit: p['hookah_habit'] as String?,
      educationRank: p['education_rank'] as int?,
      educationLabel: p['education_level'] as String?,
      fieldOfStudy: p['field_of_study'] as String?,
      profession: p['profession'] as String?,
      employmentStatus: empStatus,
      incomeBracketId: p['income_bracket'] as int?,
      incomeVisibility: p['income_visibility'] as String?,
      familyType: famType,
      siblingCount: p['sibling_count'] as int?,
      isEldestChild: p['is_eldest_child'] as bool?,
      parentsStatus: p['parents_status'] as String?,
      maritalStatus: marStatus,
      hasChildren: (p['children_count'] as int? ?? 0) > 0,
      childrenCount: p['children_count'] as int?,
      livingExpectation: p['living_expectation'] as String?,
      bio: p['bio'] as String?,
      interests: p['interests'] != null ? List<String>.from(p['interests'] as Iterable) : null,
      languages: p['languages'] != null ? List<String>.from(p['languages'] as Iterable) : null,
      preferredAgeMin: pr?['preferred_age_min'] as int?,
      preferredAgeMax: pr?['preferred_age_max'] as int?,
      locationPreference: locPref,
      preferredSect: pr?['sect_preference'] as String?,
      preferredDeenLevel: pr?['deen_preference'] as String?,
      minEducationRank: pr?['min_education_rank'] as int?,
      openToDivorced: pr?['open_to_divorced'] as bool?,
      openToWidowed: pr?['open_to_widowed'] as bool?,
      openToWithChildren: pr?['open_to_has_children'] as bool?,
      preferredLivingExpectation: pr?['preferred_living_expectation'] as String?,
      photoPrivacy: p['photo_privacy'] == 'mutual_only'
          ? PhotoPrivacy.mutualOnly
          : p['photo_privacy'] == 'request_only'
              ? PhotoPrivacy.requestOnly
              : PhotoPrivacy.publicAll,
      quranMemorization: p['quran_memorization'] as String?,
      religiousEducation: p['religious_education'] as String?,
      marriageTimeline: p['marriage_timeline'] as String?,
      willingToRelocate: p['willing_to_relocate'] as String?,
      niqabPreference: p['niqab_preference'] as String?,
      mahrExpectation: p['mahr_expectation'] as String?,
      willingToWorkAfterMarriage: p['willing_to_work_after_marriage'] as bool?,
      mahrBudget: p['mahr_budget'] as String?,
      canProvideHousing: p['can_provide_housing'] as bool?,
      canProvideMaintenance: p['can_provide_maintenance'] as bool?,
      debtStatus: p['debt_status'] as String?,
      religiousLeadership: p['religious_leadership'] as String?,
      guardianName: p['guardian_name'] as String?,
      guardianRelationship: guardianRelationship,
      guardianPhoneCountryCode: p['guardian_phone_country_code'] as String?,
      profileCreatorRelation: profileCreatorRelation,
      guardianEmail: p['guardian_email'] as String?,
      guardianAuthorityScope: p['guardian_authority_scope'] as String?,
      guardianMode: guardianMode,
      isRevert: p['is_revert'] as String?,
      polygamyStatus: p['polygamy_status'] as String?,
      polygamyAcceptance: p['polygamy_acceptance'] as String?,
      specialNeeds: p['special_needs'] as String?,
    );
  }

  // ── Enum → String converters ──────────────────────────────

  static String? _genderToString(Gender? g) {
    if (g == null) return null;
    switch (g) {
      case Gender.male:   return 'male';
      case Gender.female: return 'female';
    }
  }

  static String? _sectToString(Sect? s) {
    if (s == null) return null;
    switch (s) {
      case Sect.sunni:          return 'sunni';
      case Sect.shia:           return 'shia';
      case Sect.preferNotToSay: return 'prefer_not_to_say';
      case Sect.other:          return 'other';
    }
  }

  static String? _deenLevelToString(DeenLevel? d) {
    if (d == null) return null;
    switch (d) {
      case DeenLevel.practicing: return 'practicing';
      case DeenLevel.moderate:   return 'moderate';
      case DeenLevel.cultural:   return 'cultural';
    }
  }

  static String? _familyTypeToString(FamilyType? f) {
    if (f == null) return null;
    switch (f) {
      case FamilyType.nuclear:  return 'nuclear';
      case FamilyType.joint:    return 'joint';
      case FamilyType.extended: return 'extended';
    }
  }

  static String? _employmentStatusToString(EmploymentStatus? e) {
    if (e == null) return null;
    switch (e) {
      case EmploymentStatus.employed:     return 'employed';
      case EmploymentStatus.selfEmployed: return 'self_employed';
      case EmploymentStatus.student:      return 'student';
      case EmploymentStatus.notWorking:   return 'not_working';
    }
  }

  static String? _photoPrivacyToString(PhotoPrivacy? p) {
    if (p == null) return null;
    switch (p) {
      case PhotoPrivacy.publicAll:    return 'public';
      case PhotoPrivacy.mutualOnly:   return 'mutual_only';
      case PhotoPrivacy.requestOnly:  return 'request_only';
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Removes null values from a map to enable partial upserts.
  static Map<String, dynamic> _compactMap(Map<String, dynamic> input) {
    return Map.fromEntries(
      input.entries.where((e) => e.value != null),
    );
  }
}
