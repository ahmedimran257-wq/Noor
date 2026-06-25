// lib/core/router/app_router.dart
// ============================================================
// MITHAQ — GoRouter Configuration
// Auth-gated routing:
//   • Unauthenticated → /splash
//   • Authenticated, onboarding incomplete → /onboarding/:step
//   • Authenticated, onboarding complete   → /home
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';
import '../cubits/onboarding/onboarding_cubit.dart';
import '../models/onboarding_data.dart';

import '../../features/onboarding/screens/splash_brand_screen.dart';
import '../../features/onboarding/screens/assalam_animation_screen.dart';
import '../../features/onboarding/screens/language_selection_screen.dart';
import '../../features/onboarding/screens/legal_gate_screen.dart';
import '../../features/onboarding/screens/email_verification_screen.dart';
import '../../features/onboarding/screens/profile_for_whom_screen.dart';
import '../../features/onboarding/screens/quick_location_screen.dart';
import '../../features/onboarding/screens/basic_identity_screen.dart';
import '../../features/onboarding/screens/islamic_identity_screen.dart';
import '../../features/onboarding/screens/photo_upload_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/screens/edit_profile_screen.dart';
import '../../features/home/screens/profile_views_screen.dart';
import '../../features/home/screens/notifications_screen.dart';
import '../../features/home/screens/delete_account_screen.dart';
import '../../features/home/screens/block_list_screen.dart';
import '../../features/home/screens/subscription_screen.dart';
import '../../features/home/screens/guardian_dashboard_screen.dart';
import '../../features/home/screens/chat_screen.dart';
import '../../features/home/screens/referral_screen.dart';
import '../../features/home/screens/help_support_screen.dart';
import '../../features/verification/screens/badge_verification_screen.dart';
import '../../features/verification/screens/kyc_verification_screen.dart';

// ── Route names ───────────────────────────────────────────────

abstract final class AppRoutes {
  static const splash = '/';
  static const assalam = '/assalam';
  static const languageSelect = '/language';
  static const legal = '/legal';
  static const email = '/email';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const editProfile = '/edit-profile';
  static const profileViews = '/profile-views';
  static const notifications = '/notifications';
  static const deleteAccount = '/delete-account';
  static const blockList = '/block-list';
  static const subscription = '/subscription';
  static const guardianDashboard = '/guardian-dashboard';
  static const referral = '/referral';
  static const verify = '/verify';
  static const badgeVerification = '/badge-verification';
  static const helpSupport = '/help-support';
}

// ── Screen index → route path mapping ────────────────────────

String onboardingPathForStep(int step) {
  return '${AppRoutes.onboarding}/$step';
}

// ── Router factory ────────────────────────────────────────────

GoRouter buildAppRouter(
  AuthCubit authCubit, {
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: _AuthStateListenable(authCubit),
    redirect: (context, state) {
      final authState = authCubit.state;
      final location = state.matchedLocation;

      // Still checking session — no redirect yet
      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }

      // Unauthenticated: always go to splash
      if (authState is AuthUnauthenticated || authState is AuthOtpSent) {
        if (location == AppRoutes.assalam ||
            location == AppRoutes.languageSelect ||
            location == AppRoutes.splash ||
            location == AppRoutes.legal ||
            location == AppRoutes.email) {
          return null; // allow these pages
        }
        return AppRoutes.splash;
      }

      // Authenticated
      if (authState is AuthAuthenticated) {
        // Always allow the assalam greeting animation (it auto-navigates away)
        if (location == AppRoutes.assalam) return null;

        if (authState.isOnboardingComplete) {
          // Fully onboarded — go to home unless already there or on sub-routes
          if (location.startsWith(AppRoutes.home) ||
              location == AppRoutes.editProfile ||
              location == AppRoutes.profileViews ||
              location == AppRoutes.notifications ||
              location == AppRoutes.deleteAccount ||
              location == AppRoutes.blockList ||
              location == AppRoutes.subscription ||
              location == AppRoutes.guardianDashboard ||
              location == AppRoutes.referral ||
              location == AppRoutes.verify ||
              location == AppRoutes.badgeVerification ||
              location == AppRoutes.helpSupport) {
            return null;
          }
          return AppRoutes.home;
        } else {
          // Still onboarding — allow the language selection screen so
          // the first-install sequence isn't short-circuited.
          // Other pre-auth screens (splash, legal, email) should redirect
          // to the onboarding step once the user is authenticated.
          if (location == AppRoutes.languageSelect) {
            return null;
          }
          // Otherwise navigate to the current onboarding step.
          // goBack() already updates authState.onboardingStep to the
          // lower step, so the redirect naturally handles back-nav too.
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
        path: AppRoutes.assalam,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const AssalamAnimationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.languageSelect,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const LanguageSelectionScreen(),
        ),
      ),
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
        path: AppRoutes.email,
        pageBuilder: (context, state) {
          final mode = state.uri.queryParameters['mode'] == 'signup'
              ? EmailAuthMode.signUp
              : EmailAuthMode.signIn;
          return _slidePage(
            key: state.pageKey,
            child: EmailVerificationScreen(mode: mode),
          );
        },
      ),

      // ── Onboarding steps 0–11 ───────────────────────────
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
        pageBuilder: (context, state) {
          final tabIndexStr = state.uri.queryParameters['tab'];
          final initialTab =
              tabIndexStr != null ? int.tryParse(tabIndexStr) : null;
          return _slidePage(
            key: state.pageKey,
            child: HomeScreen(initialTab: initialTab),
          );
        },
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
      GoRoute(
        path: AppRoutes.subscription,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const SubscriptionScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.guardianDashboard,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const GuardianDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.verify,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const KycVerificationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.badgeVerification,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const BadgeVerificationScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const HelpSupportScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.referral,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const ReferralScreen(),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slidePage(
            key: state.pageKey,
            child: ChatScreen(conversationId: id),
          );
        },
      ),
    ],
  );
}

// ── Route → Screen mapping ────────────────────────────────────
//
// Myself path — 11 steps (completes at ≥ 11):
//   0  ProfileForWhom → 1 BasicIdentity → 2 IslamicIdentity →
//   3  IslamicMarriageDetails → 4 Background → 5 Family →
//   6  AboutYourself → 7 PartnerPreferences → 8 PhotoUpload →
//   9  ProfilePreview → 10 Welcome
//
// Guardian paths add +1 step (GuardianDetails at step 1).

Widget _screenForStep(BuildContext context, int step) {
  final data = context.read<OnboardingCubit>().currentData;
  final isGuardian = data.profileFor == ProfileFor.guardian;

  if (isGuardian) {
    switch (step) {
      case 0:
        return const ProfileForWhomScreen();
      case 1:
        return const QuickLocationScreen();
      case 2:
        return const BasicIdentityScreen();
      case 3:
        return const IslamicIdentityScreen();
      case 4:
        return const PhotoUploadScreen();
      default:
        return const ProfileForWhomScreen();
    }
  }

  // Myself path
  switch (step) {
    case 0:
      return const ProfileForWhomScreen();
    case 1:
      return const QuickLocationScreen();
    case 2:
      return const BasicIdentityScreen();
    case 3:
      return const IslamicIdentityScreen();
    case 4:
      return const PhotoUploadScreen();
    default:
      return const ProfileForWhomScreen();
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
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.25, 0.0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
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

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
