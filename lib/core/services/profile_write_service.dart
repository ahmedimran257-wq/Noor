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
      return _compactMap({
        'guardian_name': data.guardianName,
        'guardian_relationship': data.guardianRelationship,
        'guardian_email': data.guardianEmail,
        'guardian_authority_scope': data.guardianAuthorityScope,
        'guardian_phone_country_code': data.guardianPhoneCountryCode,
        'guardian_mode': 'active',
        'profile_creator_relation': data.profileCreatorRelation,
      });
    }

    switch (effectiveStep) {
      // Step 0 — ProfileForWhom (no DB fields, just local state)
      case 0:
        return _compactMap({
          'profile_creator_relation': data.profileCreatorRelation ??
              (data.profileFor == ProfileFor.myself ? 'self' : 'guardian'),
        });

      // Step 1 — Basic Identity
      case 1:
        return _compactMap({
          'first_name': data.firstName,
          'last_name': data.lastName,
          'date_of_birth': data.dateOfBirth?.toIso8601String().split('T')[0],
          'gender': _genderToString(data.gender),
          'city_id': data.cityId,
          'country_code': data.countryCode,
          'height_cm': data.heightCm,
          'complexion': data.complexion?.toLowerCase().replaceAll(' ', '_'),
          'mother_tongue': data.motherTongue,
          'community': data.community,
          'residency_status': data.residencyStatus,
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
          'special_needs': data.specialNeeds,
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
    });
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
      case PhotoPrivacy.publicAll:  return 'public';
      case PhotoPrivacy.mutualOnly: return 'mutual_only';
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
