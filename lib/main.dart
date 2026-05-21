// lib/main.dart
// ============================================================
// NOOR — Entry Point
// "Begin with bismillah"
// Step 4: GoRouter + MultiBlocProvider wired up.
//         Auth-gated routing with mock OTP flow.
// ============================================================

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/cubits/auth/auth_cubit.dart';
import 'core/cubits/auth/auth_state.dart';
import 'core/cubits/onboarding/onboarding_cubit.dart';
import 'core/cubits/interests/interests_cubit.dart';
import 'core/cubits/discovery/discovery_feed_cubit.dart';
import 'core/cubits/chat/chat_cubit.dart';
import 'core/cubits/subscription/subscription_cubit.dart';
import 'core/cubits/notification_prefs/notification_prefs_cubit.dart';
import 'core/cubits/block_report/block_report_cubit.dart';
import 'core/cubits/notifications/notifications_cubit.dart';
import 'core/cubits/locale/locale_cubit.dart';
import 'core/router/app_router.dart';
import 'l10n/generated/app_localizations.dart';

/// Supported locales.
/// Adding a locale here activates it in the language picker.
const _supportedLocales = [
  Locale('en'),   // English
  Locale('ar'),   // Arabic  (RTL)
  Locale('ur'),   // Urdu    (RTL)
  Locale('ms'),   // Malay
  Locale('id'),   // Indonesian
  Locale('tr'),   // Turkish
  Locale('bn'),   // Bengali
  Locale('fr'),   // French
];

/// RTL locales — drives WidgetsApp directionality.
const _rtlLocales = {'ar', 'ur'};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase Initialization ─────────────────────────────────
  // Initialize Supabase client if configured (non-mock mode)
  await SupabaseService.initialize();

  // ── Global Error Handling ──────────────────────────────────

  // Catch Flutter framework errors (layout, painting, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  // Replace the ugly red error screen with a styled fallback
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0A0A0F), // AppColors.obsidianNight
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFE67E7E), size: 48),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Color(0xFFF5F5F7),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode
                    ? details.exception.toString()
                    : 'Please restart the app.',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Catch async errors not caught by Flutter framework
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error\n$stack');
    return true; // Prevent app crash
  };

  // Status bar: transparent, light icons (dark background)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:           Colors.transparent,
    statusBarIconBrightness:  Brightness.light,
    statusBarBrightness:      Brightness.dark,
    systemNavigationBarColor: Color(0xFF0A0A0F),
  ));

  // Portrait-only for Phase 1
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ── Determine initial route ──────────────────────────────────
  // Use a dedicated key (not 'app_locale') to track whether the
  // first-install intro has been completed. app_locale may exist
  // from the settings screen or previous dev sessions.
  final prefs       = await SharedPreferences.getInstance();
  final introSeen   = prefs.getBool('noor_intro_completed') ?? false;
  final initialLoc  = introSeen ? AppRoutes.splash : AppRoutes.assalam;

  runApp(NoorApp(initialLocation: initialLoc));
}

class NoorApp extends StatelessWidget {
  const NoorApp({super.key, required this.initialLocation});

  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    // Create cubits at the top level so they outlive any individual screen.
    final authCubit              = AuthCubit();
    final onboardingCubit        = OnboardingCubit(authCubit: authCubit);
    final interestsCubit         = InterestsCubit();
    final blockReportCubit       = BlockReportCubit();
    final discoveryFeedCubit     = DiscoveryFeedCubit(blockReportCubit: blockReportCubit);
    final chatCubit              = ChatCubit();
    final subscriptionCubit      = SubscriptionCubit();
    final notificationPrefsCubit = NotificationPrefsCubit();
    final notificationsCubit     = NotificationsCubit();
    final localeCubit            = LocaleCubit();

    // Kick off session check + subscription init immediately.
    authCubit.checkSession();
    subscriptionCubit.initialize();

    // TD5: Start connectivity monitoring
    ConnectivityService.initialize();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<OnboardingCubit>.value(value: onboardingCubit),
        BlocProvider<InterestsCubit>.value(value: interestsCubit),
        BlocProvider<DiscoveryFeedCubit>.value(value: discoveryFeedCubit),
        BlocProvider<ChatCubit>.value(value: chatCubit),
        BlocProvider<SubscriptionCubit>.value(value: subscriptionCubit),
        BlocProvider<NotificationPrefsCubit>.value(value: notificationPrefsCubit),
        BlocProvider<BlockReportCubit>.value(value: blockReportCubit),
        BlocProvider<NotificationsCubit>.value(value: notificationsCubit),
        BlocProvider<LocaleCubit>.value(value: localeCubit),
      ],
      child: Builder(
        builder: (context) {
          // Build router after providers are available in context.
          final router = buildAppRouter(context, initialLocation: initialLocation);

          return BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              // When the user authenticates for the first time, initialize
              // the onboarding cubit from the correct step.
              if (state is AuthAuthenticated && !state.isOnboardingComplete) {
                onboardingCubit.initialize(startStep: state.onboardingStep);
              }
              // Set the daily interest limit based on gender + subscription status.
              if (state is AuthAuthenticated) {
                interestsCubit.setDailyLimitForGender(
                  gender: state.gender ?? 'male',
                  isSubscribed: context.read<SubscriptionCubit>().state.isSubscribed,
                );
              }
            },
            child: BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) => MaterialApp.router(
              title:        'NOOR',
              debugShowCheckedModeBanner: false,
              theme:        AppTheme.darkTheme,
              darkTheme:    AppTheme.darkTheme,
              themeMode:    ThemeMode.dark,
              locale:       locale,

              // ── Router ───────────────────────────────────
              routerConfig: router,

              // ── Localizations ─────────────────────────────
              supportedLocales: _supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              localeResolutionCallback: (deviceLocale, supportedLocales) {
                for (final supported in supportedLocales) {
                  if (deviceLocale?.languageCode == supported.languageCode) {
                    return supported;
                  }
                }
                return const Locale('en');
              },

              // ── RTL-aware directionality ──────────────────
              builder: (context, child) {
                final loc    = Localizations.localeOf(context);
                final isRtl  = _rtlLocales.contains(loc.languageCode);
                final textDir = isRtl ? TextDirection.rtl : TextDirection.ltr;

                return Directionality(
                  textDirection: textDir,
                  child: child!,
                );
              },
            ),
          ),
        );
        },
      ),
    );
  }
}
