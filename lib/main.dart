// lib/main.dart
// ============================================================
// Mithaq — Entry Point
// "Begin with bismillah"
// Step 4: GoRouter + MultiBlocProvider wired up.
//         Auth-gated routing with mock OTP flow.
// ============================================================

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';

import 'core/theme/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/subscription_service.dart';
import 'core/services/wali_mode_service.dart';
import 'core/services/fcm_service.dart';
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
/// Only list locales that have complete .arb translations.
/// Phase 2+ expansion — add .arb file first, then uncomment here.
const _supportedLocales = [
  Locale('en'), // English
  Locale('ar'), // Arabic  (RTL)
  // Locale('ur'),   // Urdu    (RTL)
  // Locale('ms'),   // Malay
  // Locale('id'),   // Indonesian
  // Locale('tr'),   // Turkish
  // Locale('fr'),   // French
  // Locale('de'),   // German
];

/// RTL locales — drives WidgetsApp directionality.
const _rtlLocales = {'ar'};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Initialization ─────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Supabase Initialization ─────────────────────────────────
  // Initialize Supabase client if configured (non-mock mode)
  await SupabaseService.initialize();

  // ── Global Error Handling + Crashlytics ────────────────────

  // Catch Flutter framework errors → forward to Crashlytics
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
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

  // Catch async errors not caught by Flutter framework → forward to Crashlytics
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error\n$stack');
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true; // Prevent app crash
  };

  // Status bar: transparent, light icons (dark background)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0A0A0F),
  ));

  // Portrait-only for Phase 1. Do not block the first frame on this.
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]));

  // ── SharedPreferences check for returning users ──────────────
  final prefs = await SharedPreferences.getInstance();
  final introCompleted = prefs.getBool('mithaq_intro_completed') ?? false;
  runApp(MithaqApp(
    initialLocation: introCompleted ? AppRoutes.splash : AppRoutes.assalam,
  ));
}

Future<void> _configureRevenueCat() async {
  final rcKey = Platform.isIOS
      ? AppConfig.revenueCatIosKey
      : AppConfig.revenueCatAndroidKey;
  if (rcKey.isEmpty) return;
  try {
    await Purchases.configure(PurchasesConfiguration(rcKey));
  } catch (e) {
    debugPrint('[main] RevenueCat configure skipped: $e');
  }
}

class MithaqApp extends StatefulWidget {
  const MithaqApp({super.key, required this.initialLocation});

  final String initialLocation;

  @override
  State<MithaqApp> createState() => _MithaqAppState();
}

class _MithaqAppState extends State<MithaqApp> {
  /// Guard: ensures onboarding cubit is initialized only once per auth session.
  /// Without this, every updateOnboardingStep() call re-triggers the
  /// BlocListener which calls initialize() and wipes all accumulated form data.
  bool _onboardingInitialized = false;

  // Create cubits at the top level so they outlive any individual screen.
  late final AuthCubit _authCubit;
  late final OnboardingCubit _onboardingCubit;
  late final InterestsCubit _interestsCubit;
  late final BlockReportCubit _blockReportCubit;
  late final DiscoveryFeedCubit _discoveryFeedCubit;
  late final ChatCubit _chatCubit;
  late final SubscriptionCubit _subscriptionCubit;
  late final NotificationPrefsCubit _notificationPrefsCubit;
  late final NotificationsCubit _notificationsCubit;
  late final LocaleCubit _localeCubit;

  late final GoRouter _router;
  late final Future<void> _revenueCatReady;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit();
    _onboardingCubit = OnboardingCubit(authCubit: _authCubit);
    _interestsCubit = InterestsCubit();
    _blockReportCubit = BlockReportCubit();
    _discoveryFeedCubit = DiscoveryFeedCubit();
    _chatCubit = ChatCubit();
    _subscriptionCubit = SubscriptionCubit();
    _notificationPrefsCubit = NotificationPrefsCubit();
    _notificationsCubit = NotificationsCubit();
    _localeCubit = LocaleCubit();

    _router =
        buildAppRouter(_authCubit, initialLocation: widget.initialLocation);

    // Wire up FCM tap navigation callback
    FcmService.instance.onNotificationTap = (path) {
      _router.push(path);
    };

    _revenueCatReady = _configureRevenueCat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPostFirstFrameWork();
    });
  }

  void _startPostFirstFrameWork() {
    _authCubit.checkSession();
    ConnectivityService.initialize();
    unawaited(_revenueCatReady.then((_) => _subscriptionCubit.initialize()));
    unawaited(FcmService.instance.initialize());
  }

  Future<void> _loginSubscriptionUser(String userId) async {
    await _revenueCatReady;
    if (!mounted) return;
    await _subscriptionCubit.loginUser(userId);
  }

  @override
  void dispose() {
    // ── Dispose Cubits ─────────────────────────────────────────
    _authCubit.close();
    _onboardingCubit.close();
    _interestsCubit.close();
    _blockReportCubit.close();
    _discoveryFeedCubit.close();
    _chatCubit.close();
    _subscriptionCubit.close();
    _notificationPrefsCubit.close();
    _notificationsCubit.close();
    _localeCubit.close();

    // ── Dispose Services ───────────────────────────────────────
    ConnectivityService.instance.dispose();
    SubscriptionService.instance.dispose();
    WaliModeService.instance.dispose();
    FcmService.instance.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<OnboardingCubit>.value(value: _onboardingCubit),
        BlocProvider<InterestsCubit>.value(value: _interestsCubit),
        BlocProvider<DiscoveryFeedCubit>.value(value: _discoveryFeedCubit),
        BlocProvider<ChatCubit>.value(value: _chatCubit),
        BlocProvider<SubscriptionCubit>.value(value: _subscriptionCubit),
        BlocProvider<NotificationPrefsCubit>.value(
            value: _notificationPrefsCubit),
        BlocProvider<BlockReportCubit>.value(value: _blockReportCubit),
        BlocProvider<NotificationsCubit>.value(value: _notificationsCubit),
        BlocProvider<LocaleCubit>.value(value: _localeCubit),
      ],
      child: Builder(
        builder: (context) {
          return BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              // Reset the guard when user signs out so re-login triggers
              // a fresh initialization of the onboarding cubit.
              if (state is AuthUnauthenticated) {
                _onboardingInitialized = false;
                _chatCubit.loadConversations();
                _notificationsCubit.loadNotifications();
              }
              // Initialize the onboarding cubit ONCE when the user first
              // authenticates. Without the _onboardingInitialized guard,
              // every saveAndAdvance() → updateOnboardingStep() call
              // re-triggers this listener and wipes accumulated form data.
              if (state is AuthAuthenticated && !_onboardingInitialized) {
                _onboardingInitialized = true;
                _onboardingCubit.initialize(startStep: state.onboardingStep);
              }
              // Set the daily interest limit based on gender + subscription status.
              if (state is AuthAuthenticated) {
                unawaited(_loginSubscriptionUser(state.userId));
                _interestsCubit.setDailyLimitForGender(
                  gender: state.gender ?? 'male',
                  isSubscribed:
                      context.read<SubscriptionCubit>().state.isSubscribed,
                );
                _chatCubit.loadConversations();
                _notificationsCubit.loadNotifications();
              }
            },
            child: BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) => MaterialApp.router(
                title: 'Mithaq',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.darkTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ThemeMode.dark,
                locale: locale,

                // ── Router ───────────────────────────────────
                routerConfig: _router,

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
                  final loc = Localizations.localeOf(context);
                  final isRtl = _rtlLocales.contains(loc.languageCode);
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
