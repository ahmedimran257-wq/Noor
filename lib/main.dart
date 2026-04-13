// lib/main.dart
// ============================================================
// NOOR — Entry Point
// "Begin with bismillah"
// Step 4: GoRouter + MultiBlocProvider wired up.
//         Auth-gated routing with mock OTP flow.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/cubits/auth/auth_cubit.dart';
import 'core/cubits/auth/auth_state.dart';
import 'core/cubits/onboarding/onboarding_cubit.dart';
import 'core/cubits/interests/interests_cubit.dart';
import 'core/router/app_router.dart';

/// Supported locales.
/// Adding a locale here activates it in the language picker.
const _supportedLocales = [
  Locale('en'),   // English
  Locale('ar'),   // Arabic  (RTL)
  Locale('ur'),   // Urdu    (RTL)
  Locale('ms'),   // Malay
  Locale('id'),   // Indonesian
  Locale('tr'),   // Turkish
  Locale('de'),   // German
  Locale('fr'),   // French
];

/// RTL locales — drives WidgetsApp directionality.
const _rtlLocales = {'ar', 'ur'};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const NoorApp());
}

class NoorApp extends StatelessWidget {
  const NoorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create cubits at the top level so they outlive any individual screen.
    final authCubit        = AuthCubit();
    final onboardingCubit  = OnboardingCubit(authCubit: authCubit);
    final interestsCubit   = InterestsCubit();

    // Kick off session check immediately.
    authCubit.checkSession();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<OnboardingCubit>.value(value: onboardingCubit),
        BlocProvider<InterestsCubit>.value(value: interestsCubit),
      ],
      child: Builder(
        builder: (context) {
          // Build router after providers are available in context.
          final router = buildAppRouter(context);

          return BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              // When the user authenticates for the first time, initialize
              // the onboarding cubit from the correct step.
              if (state is AuthAuthenticated && !state.isOnboardingComplete) {
                onboardingCubit.initialize(startStep: state.onboardingStep);
              }
            },
            child: MaterialApp.router(
              title:        'NOOR',
              debugShowCheckedModeBanner: false,
              theme:        AppTheme.darkTheme,
              darkTheme:    AppTheme.darkTheme,
              themeMode:    ThemeMode.dark,

              // ── Router ───────────────────────────────────
              routerConfig: router,

              // ── Localizations ─────────────────────────────
              supportedLocales: _supportedLocales,
              localizationsDelegates: const [
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
                final locale  = Localizations.localeOf(context);
                final isRtl   = _rtlLocales.contains(locale.languageCode);
                final textDir = isRtl ? TextDirection.rtl : TextDirection.ltr;

                return Directionality(
                  textDirection: textDir,
                  child: child!,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
