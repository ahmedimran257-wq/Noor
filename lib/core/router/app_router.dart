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

import '../../features/onboarding/screens/splash_brand_screen.dart';
import '../../features/onboarding/screens/legal_gate_screen.dart';
import '../../features/onboarding/screens/phone_verification_screen.dart';
import '../../features/onboarding/screens/profile_for_whom_screen.dart';
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

// ── Route names ───────────────────────────────────────────────

abstract final class AppRoutes {
  static const splash       = '/';
  static const legal        = '/legal';
  static const phone        = '/phone';
  static const onboarding   = '/onboarding';
  static const home         = '/home';
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
    ],
  );
}

// ── Route → Screen mapping ────────────────────────────────────

Widget _screenForStep(BuildContext context, int step) {
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
