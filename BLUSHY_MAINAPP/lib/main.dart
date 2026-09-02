import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'features/home/blushy_shell.dart';
import 'features/home/presentation/partner_shell.dart';
import 'core/state.dart';
import 'core/storage.dart';
import 'services/language_preference.dart';
import 'features/admin/content_review_screen.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/onboarding_wizard.dart';
import 'features/auth/presentation/partner_onboarding_wizard.dart';
import 'features/auth/presentation/choose_experience_screen.dart';
import 'features/dev/developer_playground.dart';
import 'services/auth_storage.dart';
import 'services/api_warmup.dart';
import 'shared/splash_gate.dart';
import 'shared/scroll_feel.dart';
import 'core/theme.dart' hide BlushyColors;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolves the writable directory before anything reads or writes. Without
  // it every file write on Android fails against a read-only path.
  await BlushyStorage.init();
  // Restores the language Docsy replies in before the first screen renders.
  LanguagePreference.load();
  // Wakes the API while the first screen builds, so a cold start is not paid
  // for under a card the user is waiting on.
  ApiWarmup.ping();
  runApp(const BlushyApp());
}

/// The colour scheme every Material widget resolves against.
///
/// Lifted out of the theme so it can be asserted on directly: the failure it
/// guards is silent, because a wrong scheme still renders a perfectly
/// good-looking screen -- just in somebody else's colours.
final ColorScheme blushyColorScheme = ColorScheme.fromSeed(
  seedColor: BlushyColors.primary,
).copyWith(
  primary: BlushyColors.primary,
  onPrimary: Colors.white,
  error: BlushyColors.danger,
  onError: Colors.white,
  surface: BlushyColors.surface,
  onSurface: BlushyColors.text,
  onSurfaceVariant: BlushyColors.secondaryText,
  outline: BlushyColors.border,
  // Dialogs and menus default to surfaceContainerHigh; the app draws its
  // cards on plain white, so these follow.
  surfaceContainerHigh: BlushyColors.surface,
  surfaceContainerLow: BlushyColors.surface,
);

class BlushyApp extends StatelessWidget {
  const BlushyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlushyOSProvider(
      notifier: BlushyOSState(),
      // Rebuilds the whole app when the language changes, so the chrome
      // switches immediately rather than on next launch.
      child: ValueListenableBuilder<String>(
        valueListenable: LanguagePreference.current,
        // Above MaterialApp: scroll notifications bubble, so one listener
        // here covers every list in the app.
        builder: (context, languageCode, _) => ScrollEndHaptic(
          child: MaterialApp(
        title: 'blushy.life',
        debugShowCheckedModeBanner: false,
        locale: Locale(languageCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeResolutionCallback: LanguagePreference.resolveLocale,
        // Bouncing physics on every platform; see BlushyScrollBehavior.
        scrollBehavior: const BlushyScrollBehavior(),
        theme: ThemeData(
          scaffoldBackgroundColor: BlushyColors.background,
          useMaterial3: true,
          // The app never told Material what its colours were. With
          // useMaterial3 and no scheme, ThemeData falls back to the baseline
          // M3 palette -- primary 0xFF6750A4, Material's purple -- and every
          // widget that reads the scheme rather than being painted by hand
          // took its colour from there: dialogs, switches, sliders, progress
          // indicators, the text cursor and selection handles, snackbars, the
          // tint an AppBar lays over its background. That is why some screens
          // looked like they were following a different scheme; they were.
          //
          // Seeded from the brand red so the tonal roles stay internally
          // consistent, then the roles the palette actually names are pinned
          // to it rather than left to the generated approximations.
          colorScheme: blushyColorScheme,
          // Belt and braces over the scheme above: these three read their
          // background from surface roles, and pinning them means a future
          // change to those roles cannot quietly repaint every dialog. The
          // transparent tints matter most on AppBar-adjacent surfaces, where
          // M3 does still wash the primary over the background by elevation.
          dialogTheme: DialogThemeData(
            shape: BlushyTheme.shape,
            backgroundColor: BlushyColors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: BlushyColors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          popupMenuTheme: const PopupMenuThemeData(
            color: BlushyColors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          // Rectangles with the corners taken off, for anything that does not
          // set its own shape. Built inline rather than by adopting
          // BlushyTheme.lightTheme wholesale, which would also swap the type.
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(shape: BlushyTheme.shape),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(shape: BlushyTheme.shape),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(shape: BlushyTheme.shape),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(shape: BlushyTheme.shape),
          ),
          floatingActionButtonTheme:
              FloatingActionButtonThemeData(shape: BlushyTheme.shape),
          chipTheme: ChipThemeData(shape: BlushyTheme.shape),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BlushyTheme.radius),
            ),
          ),
        ),
        // The red field and the circle that opens onto whatever the router
        // decides to show -- sign-in, onboarding or the app itself.
        home: const SplashGate(child: AppRouter()),
        routes: {
          '/login': (context) => const AppRouter(),
          '/dev': (context) => const DeveloperPlaygroundScreen(),
          // Clinical reviewers approve health content here. The backend has
          // had the whole review API from the start with nothing calling it.
          '/admin/content-review': (context) => const ContentReviewScreen(),
          '/onboarding/choose': (context) => ChooseExperienceScreen(
                onSelectForMe: () {
                  Navigator.of(context).pushReplacementNamed('/onboarding/women');
                },
                onSelectPartner: () {
                  Navigator.of(context).pushReplacementNamed('/onboarding/partner');
                },
              ),
          '/onboarding/women': (context) => const OnboardingWizard(),
          '/onboarding/partner': (context) => const PartnerOnboardingWizard(),
          '/home': (context) => const AppRouter(),
        },
          ),
        ),
      ),
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    if (!state.isAuthenticated) {
      return const UnauthenticatedAuthFlow();
    }

    final role = AuthStorage.getRole() ?? state.selectedRole;

    if (!state.onboardingCompleted && !AuthStorage.isOnboardingCompleted()) {
      if (role == 'partner' || role == 'man') {
        return const PartnerOnboardingWizard();
      }
      return const OnboardingWizard();
    }

    // Direct partner users to PartnerShell, female users to BlushyOSShell
    final profile = BlushyStorage.read('user_profile.json');
    String resolvedRole = role;
    if (profile.isNotEmpty) {
      if (profile['role'] != null) {
        resolvedRole = profile['role'].toString();
      } else if (profile['profile'] is Map && profile['profile']['role'] != null) {
        resolvedRole = profile['profile']['role'].toString();
      }
    }

    if (resolvedRole == 'partner' || resolvedRole == 'man') {
      return const PartnerShell();
    }

    return const BlushyOSShell();
  }
}

class UnauthenticatedAuthFlow extends StatefulWidget {
  const UnauthenticatedAuthFlow({super.key});

  @override
  State<UnauthenticatedAuthFlow> createState() => _UnauthenticatedAuthFlowState();
}

class _UnauthenticatedAuthFlowState extends State<UnauthenticatedAuthFlow> {
  @override
  Widget build(BuildContext context) {
    final state = BlushyOSProvider.of(context);
    if (!state.hasChosenExperience) {
      return ChooseExperienceScreen(
        onSelectForMe: () {
          state.setSelectedRole('woman');
        },
        onSelectPartner: () {
          state.setSelectedRole('partner');
        },
      );
    }

    return const AuthScreen();
  }
}
