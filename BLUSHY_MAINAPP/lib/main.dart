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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolves the writable directory before anything reads or writes. Without
  // it every file write on Android fails against a read-only path.
  await BlushyStorage.init();
  // Restores the language Dr. Docsy replies in before the first screen renders.
  LanguagePreference.load();
  // Wakes the API while the first screen builds, so a cold start is not paid
  // for under a card the user is waiting on.
  ApiWarmup.ping();
  runApp(const BlushyApp());
}

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
        builder: (context, languageCode, _) => MaterialApp(
        title: 'blushy.life',
        debugShowCheckedModeBanner: false,
        locale: Locale(languageCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeResolutionCallback: LanguagePreference.resolveLocale,
        theme: ThemeData(
          scaffoldBackgroundColor: BlushyColors.background,
          useMaterial3: true,
        ),
        home: const AppRouter(),
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
