// lib/main.dart
// ============================================================
// Silarah — Entry Point
// "Begin with bismillah"
// Step 4: GoRouter + MultiBlocProvider wired up.
//         Auth-gated routing with Supabase email OTP.
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
import 'core/theme/app_dimensions.dart';
import 'core/services/supabase_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/subscription_service.dart';
import 'core/services/wali_mode_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/presence_service.dart';
import 'core/services/bookmark_service.dart';
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
import 'core/cubits/theme/theme_cubit.dart';
import 'core/theme/app_colors.dart';
import 'core/cubits/account_standing/account_standing_cubit.dart';
import 'core/router/app_router.dart';
import 'core/widgets/in_app_notification_banner.dart';
import 'core/widgets/startup_offline_screen.dart';
import 'l10n/generated/app_localizations.dart';

const _rtlLocales = {'ar', 'ur'};

enum _StartupNetworkState { checking, offline, ready }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Initialization ─────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── Supabase Initialization ─────────────────────────────────
    // Initialize Supabase client
    await SupabaseService.initialize();
  } catch (error, stack) {
    debugPrint('[main] Critical startup configuration error: $error\n$stack');
    runApp(const _StartupFailureApp());
    return;
  }

  // ── Global Error Handling + Crashlytics ────────────────────

  // Catch Flutter framework errors → forward to Crashlytics
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final exceptionText = details.exceptionAsString();
    final isLayoutOverflow = exceptionText.contains('RenderFlex overflowed');
    debugPrint('Flutter Error: $exceptionText');
    FirebaseCrashlytics.instance.recordFlutterError(
      details,
      fatal: !isLayoutOverflow,
    );
  };

  // Replace the ugly red error screen with a styled fallback
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 160 || constraints.maxWidth < 160;
        if (compact) {
          return const ColoredBox(
            color: Color(0xFF0A0A0F),
            child: Center(
              child: Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE67E7E),
                size: 20,
              ),
            ),
          );
        }

        return const Material(
          color: Color(0xFF0A0A0F), // AppColors.obsidianNight
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: Color(0xFFE67E7E), size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      color: Color(0xFFF5F5F7),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This screen update was interrupted. Go back once and reopen it.',
                    style: TextStyle(
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
      },
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
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  // Portrait-only for Phase 1. Do not block the first frame on this.
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]));

  // ── SharedPreferences check for returning users ──────────────
  final prefs = await SharedPreferences.getInstance();
  final introCompleted = prefs.getBool('silarah_intro_completed') ?? false;
  final initialTheme = SilarahThemeMode.fromStorage(
    prefs.getString(ThemeCubit.preferenceKey),
  );
  runApp(SilarahApp(
    initialLocation: introCompleted ? AppRoutes.boot : AppRoutes.assalam,
    initialTheme: initialTheme,
  ));
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_rounded,
                    color: Color(0xFFC5A059),
                    size: 52,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Silarah could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF5F5F7),
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'This build is missing required service configuration. '
                    'Please reinstall it using the approved build script.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _configureRevenueCat() async {
  // Test Store is deliberately restricted to debug builds. Release builds
  // always use the platform store key and can never grant test entitlements.
  final platformKey = Platform.isIOS
      ? AppConfig.revenueCatIosKey
      : AppConfig.revenueCatAndroidKey;
  final rcKey = kDebugMode && AppConfig.revenueCatTestKey.isNotEmpty
      ? AppConfig.revenueCatTestKey
      : platformKey;
  if (rcKey.isEmpty) return;
  try {
    if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(rcKey));
  } catch (e) {
    debugPrint('[main] RevenueCat configure skipped: $e');
  }
}

class SilarahApp extends StatefulWidget {
  const SilarahApp({
    super.key,
    required this.initialLocation,
    this.initialTheme = SilarahThemeMode.obsidian,
  });

  final String initialLocation;
  final SilarahThemeMode initialTheme;

  @override
  State<SilarahApp> createState() => _SilarahAppState();
}

class _SilarahAppState extends State<SilarahApp> with WidgetsBindingObserver {
  /// Guard: ensures onboarding cubit is initialized only once per auth session.
  /// Without this, every updateOnboardingStep() call re-triggers the
  /// BlocListener which calls initialize() and wipes all accumulated form data.
  bool _onboardingInitialized = false;
  String? _activeSessionUserId;

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
  late final ThemeCubit _themeCubit;
  late final AccountStandingCubit _accountStandingCubit;

  late final GoRouter _router;
  late final Future<void> _revenueCatReady;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<NotificationItem>? _notificationRefreshSubscription;
  ConnectivityService? _connectivityService;
  _StartupNetworkState _startupNetworkState = _StartupNetworkState.checking;
  Future<bool>? _startupRecoveryInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _themeCubit = ThemeCubit(initialMode: widget.initialTheme);
    _accountStandingCubit = AccountStandingCubit();

    _notificationRefreshSubscription =
        _notificationsCubit.inAppNotifications.listen((item) {
      if (item.type == 'new_message') {
        unawaited(
          _chatCubit.loadConversations(showLoading: false, force: true),
        );
      }
    });

    _router =
        buildAppRouter(_authCubit, initialLocation: widget.initialLocation);

    // Wire up FCM tap navigation callback
    FcmService.instance.onNotificationTap = (path) {
      _router.push(path);
    };
    FcmService.instance.onForegroundMessage = (message) {
      if (message.data['type'] == 'account_suspended' ||
          message.data['type'] == 'account_banned' ||
          message.data['type'] == 'account_restored') {
        unawaited(_accountStandingCubit.refresh());
      }
      if (message.data['type'] == 'new_message') {
        unawaited(_chatCubit.loadConversations(force: true));
      }
      if (message.data['type'] == 'interest_received' ||
          message.data['type'] == 'interest_accepted' ||
          message.data['type'] == 'match' ||
          message.data['type'] == 'match_accepted') {
        unawaited(_interestsCubit.loadData(force: true));
      }
    };

    _revenueCatReady = _configureRevenueCat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPostFirstFrameWork();
    });
  }

  void _startPostFirstFrameWork() {
    final connectivity = ConnectivityService.initialize(
      checkInterval: const Duration(minutes: 5),
    );
    _connectivityService = connectivity;
    _connectivitySubscription = connectivity.connectivityStream.listen(
      _handleConnectivityChange,
    );
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_recoverStartupIdentity());
    } else {
      unawaited(_resolveStartupConnectivity());
    }
    unawaited(_revenueCatReady.then((_) => _subscriptionCubit.initialize()));
    // Widget tests run without a native Firebase app. Production still
    // initializes FCM here after Firebase.initializeApp() in main().
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(FcmService.instance.initialize());
    }
  }

  Future<void> _resolveStartupConnectivity() async {
    final online = await _connectivityService!.checkNow();
    if (!mounted) return;
    if (online) {
      await _recoverStartupIdentity();
    } else if (_startupNetworkState != _StartupNetworkState.ready) {
      setState(() => _startupNetworkState = _StartupNetworkState.offline);
    }
  }

  void _handleConnectivityChange(bool online) {
    if (!mounted || _startupNetworkState == _StartupNetworkState.ready) {
      return;
    }
    if (online) {
      unawaited(_recoverStartupIdentity());
    } else if (_startupNetworkState != _StartupNetworkState.offline) {
      setState(() => _startupNetworkState = _StartupNetworkState.offline);
    }
  }

  Future<bool> _recoverStartupIdentity() {
    final activeRecovery = _startupRecoveryInFlight;
    if (activeRecovery != null) return activeRecovery;
    final recovery = _performStartupIdentityRecovery();
    _startupRecoveryInFlight = recovery;
    return recovery.whenComplete(() {
      if (identical(_startupRecoveryInFlight, recovery)) {
        _startupRecoveryInFlight = null;
      }
    });
  }

  Future<bool> _performStartupIdentityRecovery() async {
    if (!mounted) return false;
    if (_startupNetworkState != _StartupNetworkState.checking) {
      setState(() => _startupNetworkState = _StartupNetworkState.checking);
    }

    final result = await _authCubit.checkSession();
    if (!mounted) return false;
    if (result == AuthSessionCheckResult.authenticated ||
        result == AuthSessionCheckResult.signedOut) {
      setState(() => _startupNetworkState = _StartupNetworkState.ready);
      return true;
    }
    // The device is online but session/profile hydration is not yet
    // authoritative. Keep protected routing covered and let retry perform the
    // complete transaction again instead of exposing sign-up/onboarding.
    setState(() => _startupNetworkState = _StartupNetworkState.offline);
    return false;
  }

  Future<bool> _retryStartupConnectivity() async {
    final online = await _connectivityService!.checkNow();
    if (!online || !mounted) return false;
    return _recoverStartupIdentity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    PresenceService.instance.handleLifecycle(state);
    if (state == AppLifecycleState.resumed &&
        SupabaseService.currentUserId != null) {
      unawaited(_accountStandingCubit.refresh());
      unawaited(_notificationsCubit.loadNotifications());
      unawaited(_discoveryFeedCubit.loadInitial());
      unawaited(_interestsCubit.loadData(force: true));
      unawaited(_onboardingCubit.refreshProfileFromDb());
      unawaited(
        _chatCubit.loadConversations(showLoading: false, force: true),
      );
    }
  }

  Future<void> _loginSubscriptionUser(String userId) async {
    await _revenueCatReady;
    if (!mounted) return;
    await _subscriptionCubit.loginUser(userId);
  }

  void _clearUserScopedState() {
    BookmarkService.clearCache();
    _chatCubit.clear();
    _notificationsCubit.clear();
    _notificationPrefsCubit.clear();
    _discoveryFeedCubit.clear();
    _interestsCubit.clear();
    _blockReportCubit.clear();
    unawaited(_accountStandingCubit.stop());
  }

  void _openInAppNotification(NotificationItem item) {
    unawaited(_notificationsCubit.markRead(item.id));
    final path = notificationPathFor(item);
    if (path != null) _router.push(path);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_notificationRefreshSubscription?.cancel());
    PresenceService.instance.stop();
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
    _themeCubit.close();
    _accountStandingCubit.close();

    // ── Dispose Services ───────────────────────────────────────
    _connectivityService?.dispose();
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
        BlocProvider<ThemeCubit>.value(value: _themeCubit),
        BlocProvider<AccountStandingCubit>.value(
          value: _accountStandingCubit,
        ),
      ],
      child: Builder(
        builder: (context) {
          return BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              // Reset the guard when user signs out so re-login triggers
              // a fresh initialization of the onboarding cubit.
              if (state is AuthUnauthenticated) {
                _onboardingInitialized = false;
                _activeSessionUserId = null;
                PresenceService.instance.stop();
                _clearUserScopedState();
              }
              if (state is AuthAuthenticated &&
                  _activeSessionUserId != null &&
                  _activeSessionUserId != state.userId) {
                _clearUserScopedState();
                _onboardingInitialized = false;
              }
              final isNewAuthenticatedSession = state is AuthAuthenticated &&
                  _activeSessionUserId != state.userId;
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
                _activeSessionUserId = state.userId;
                PresenceService.instance.start(state.userId);
                if (isNewAuthenticatedSession) {
                  unawaited(_accountStandingCubit.start(state.userId));
                  unawaited(_loginSubscriptionUser(state.userId));
                  unawaited(FcmService.instance.onUserLogin());
                  unawaited(_notificationPrefsCubit.loadPrefs());
                  _chatCubit.loadConversations();
                  _notificationsCubit.loadNotifications();
                  _interestsCubit.loadData();
                }
                _interestsCubit.setDailyLimitForGender(
                  gender: state.gender ?? 'male',
                  isSubscribed:
                      context.read<SubscriptionCubit>().state.isSubscribed,
                );
              }
            },
            child: BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) =>
                  BlocBuilder<ThemeCubit, ThemeSelectionState>(
                builder: (context, themeState) => MaterialApp.router(
                  title: 'Silarah',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.forMode(themeState.activeMode),
                  themeMode: ThemeMode.light,
                  themeAnimationDuration: const Duration(milliseconds: 420),
                  themeAnimationCurve: Curves.easeOutCubic,
                  locale: locale,

                  // ── Router ───────────────────────────────────
                  routerConfig: _router,

                  // ── Localizations ─────────────────────────────
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  localeResolutionCallback: (deviceLocale, supportedLocales) {
                    for (final supported in supportedLocales) {
                      if (deviceLocale?.languageCode ==
                          supported.languageCode) {
                        return supported;
                      }
                    }
                    return const Locale('en');
                  },

                  // ── RTL-aware directionality ──────────────────
                  builder: (context, child) {
                    final loc = Localizations.localeOf(context);
                    final isRtl = _rtlLocales.contains(loc.languageCode);
                    final textDir =
                        isRtl ? TextDirection.rtl : TextDirection.ltr;

                    final routedApp = Directionality(
                      textDirection: textDir,
                      child: InAppNotificationBannerHost(
                        notifications: _notificationsCubit.inAppNotifications,
                        onTap: _openInAppNotification,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
                    return AnimatedSwitcher(
                      duration: AppDimensions.durationReveal,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: switch (_startupNetworkState) {
                        _StartupNetworkState.checking =>
                          const StartupOfflineScreen(
                            key: ValueKey('startup-connectivity-checking'),
                            checking: true,
                          ),
                        _StartupNetworkState.offline => StartupOfflineScreen(
                            key: const ValueKey('startup-connectivity-offline'),
                            onRetry: _retryStartupConnectivity,
                          ),
                        _StartupNetworkState.ready => KeyedSubtree(
                            key: const ValueKey('startup-connectivity-ready'),
                            child: routedApp,
                          ),
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
