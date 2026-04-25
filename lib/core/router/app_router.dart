// lib/core/router/app_router.dart
// ============================================================
// NOOR — GoRouter Configuration
// Auth-gated routing:
//   • Unauthenticated → /splash
//   • Authenticated, step < 14 → /onboarding/:step
//   • Authenticated, step == 14 → /home
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';
import '../cubits/onboarding/onboarding_cubit.dart';
import '../models/onboarding_data.dart';

import '../../features/onboarding/screens/splash_brand_screen.dart';
import '../../features/onboarding/screens/legal_gate_screen.dart';
import '../../features/onboarding/screens/phone_verification_screen.dart';
import '../../features/onboarding/screens/profile_for_whom_screen.dart';
import '../../features/onboarding/screens/guardian_details_screen.dart';
import '../../features/onboarding/screens/basic_identity_screen.dart';
import '../../features/onboarding/screens/islamic_identity_screen.dart';
import '../../features/onboarding/screens/background_screen.dart';
import '../../features/onboarding/screens/income_screen.dart';
import '../../features/onboarding/screens/family_screen.dart';
import '../../features/onboarding/screens/about_yourself_screen.dart';
import '../../features/onboarding/screens/partner_preferences_screen.dart';
import '../../features/onboarding/screens/photo_upload_screen.dart';
import '../../features/onboarding/screens/profile_preview_screen.dart';
import '../../features/onboarding/screens/welcome_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/screens/edit_profile_screen.dart';
import '../../features/home/screens/profile_views_screen.dart';
import '../../features/home/screens/notifications_screen.dart';
import '../../features/home/screens/delete_account_screen.dart';
import '../../features/home/screens/block_list_screen.dart';

// ── Route names ───────────────────────────────────────────────

abstract final class AppRoutes {
  static const splash         = '/';
  static const legal          = '/legal';
  static const phone          = '/phone';
  static const onboarding     = '/onboarding';
  static const home           = '/home';
  static const editProfile    = '/edit-profile';
  static const profileViews   = '/profile-views';
  static const notifications  = '/notifications';
  static const deleteAccount  = '/delete-account';
  static const blockList      = '/block-list';
}

// ── Screen index → route path mapping ────────────────────────

String onboardingPathForStep(int step) {
  return '${AppRoutes.onboarding}/$step';
}

// ── Router factory ────────────────────────────────────────────

GoRouter buildAppRouter(BuildContext buildContext) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthStateListenable(buildContext.read<AuthCubit>()),
    redirect: (context, state) {
      final authState = context.read<AuthCubit>().state;
      final location  = state.matchedLocation;

      // Still checking session — no redirect yet
      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }

      // Unauthenticated: always go to splash
      if (authState is AuthUnauthenticated || authState is AuthOtpSent) {
        if (location == AppRoutes.splash ||
            location == AppRoutes.legal  ||
            location == AppRoutes.phone) {
          return null; // allow these pages
        }
        return AppRoutes.splash;
      }

      // Authenticated
      if (authState is AuthAuthenticated) {
        if (authState.isOnboardingComplete) {
          // Fully onboarded — go to home unless already there
          if (location.startsWith(AppRoutes.home)) return null;
          return AppRoutes.home;
        } else {
          // Still onboarding — go to correct step
          final targetPath = onboardingPathForStep(authState.onboardingStep);
          if (location == targetPath) return null;
          return targetPath;
        }
      }

      return null;
    },
    routes: [
      // ── Pre-auth screens ────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const SplashBrandScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.legal,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const LegalGateScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.phone,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const PhoneVerificationScreen(),
        ),
      ),

      // ── Onboarding steps 0–13 ───────────────────────────
      GoRoute(
        path: '${AppRoutes.onboarding}/:step',
        pageBuilder: (context, state) {
          final step = int.tryParse(state.pathParameters['step'] ?? '0') ?? 0;
          return _slidePage(
            key: state.pageKey,
            child: _screenForStep(context, step),
          );
        },
      ),

      // ── Home (post-onboarding) ───────────────────────────
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),

      // ── Full-screen sub-screens ──────────────────────────
      GoRoute(
        path: AppRoutes.editProfile,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profileViews,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const ProfileViewsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const DeleteAccountScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.blockList,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const BlockListScreen(),
        ),
      ),
    ],
  );
}

// ── Route → Screen mapping ────────────────────────────────────
//
// Guardian branch:
//   Step 0  → ProfileForWhomScreen        (picks 'myself' OR 'guardian')
//   Step 1  → GuardianDetailsScreen        (only when profileFor == guardian)
//   Step 2  → BasicIdentityScreen          (guardian: candidate's identity)
//   …
//   Step 11 → WelcomeScreen
//
// Myself branch:
//   Step 0  → ProfileForWhomScreen
//   Step 1  → BasicIdentityScreen
//   …
//   Step 10 → WelcomeScreen
//
// The cubit marks step complete at >= 12 (guardian) / >= 11 (myself).
// We detect the branch via OnboardingCubit.currentData.profileFor.

Widget _screenForStep(BuildContext context, int step) {
  final isGuardian = context.read<OnboardingCubit>().currentData.profileFor
      == ProfileFor.guardian;

  if (isGuardian) {
    // Guardian path — one extra step inserted at position 1
    switch (step) {
      case 0:  return const ProfileForWhomScreen();
      case 1:  return const GuardianDetailsScreen();
      case 2:  return const BasicIdentityScreen();
      case 3:  return const IslamicIdentityScreen();
      case 4:  return const BackgroundScreen();
      case 5:  return const IncomeScreen();
      case 6:  return const FamilyScreen();
      case 7:  return const AboutYourselfScreen();
      case 8:  return const PartnerPreferencesScreen();
      case 9:  return const PhotoUploadScreen();
      case 10: return const ProfilePreviewScreen();
      case 11: return const WelcomeScreen();
      default: return const ProfileForWhomScreen();
    }
  }

  // Default (myself) path
  switch (step) {
    case 0:  return const ProfileForWhomScreen();
    case 1:  return const BasicIdentityScreen();
    case 2:  return const IslamicIdentityScreen();
    case 3:  return const BackgroundScreen();
    case 4:  return const IncomeScreen();
    case 5:  return const FamilyScreen();
    case 6:  return const AboutYourselfScreen();
    case 7:  return const PartnerPreferencesScreen();
    case 8:  return const PhotoUploadScreen();
    case 9:  return const ProfilePreviewScreen();
    case 10: return const WelcomeScreen();
    default: return const ProfileForWhomScreen();
  }
}

// ── Custom page transition ("Unfold" — slides from right) ─────

CustomTransitionPage<void> _slidePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end:   Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve:  Curves.easeOutCubic,
      ));

      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end:   const Offset(-0.25, 0.0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve:  Curves.easeInCubic,
      ));

      return SlideTransition(
        position: slideOut,
        child: SlideTransition(
          position: slideIn,
          child: child,
        ),
      );
    },
  );
}

// ── Auth Listenable (triggers router refresh on auth change) ──

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(AuthCubit cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  late final Object _subscription;

  @override
  void dispose() {
    (_subscription as dynamic).cancel();
    super.dispose();
  }
}
