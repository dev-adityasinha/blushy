import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/state.dart';
import '../../../models/auth_models.dart';
import '../../../services/api_auth_service.dart';
import 'email_auth_flow.dart';
import '../../../services/auth_storage.dart';
import '../../legal/legal_documents_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/scale.dart';

enum AuthFormMode { login, signup }

/// The Google *web* client id, used on every platform.
///
/// On web it identifies the page; on Android and iOS it is passed as the
/// server client so the ID token is minted for the backend to verify. Client
/// ids are public by design, so this is not a secret, but it is overridable
/// for a different Google project:
///
///     flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=...
const String _googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '442211490165-7q61q8fa1i447spte47no1rhqfa9ooo3.apps.googleusercontent.com',
);

class SignupScreen extends StatefulWidget {
  final AuthFormMode initialMode;
  const SignupScreen({super.key, this.initialMode = AuthFormMode.login});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late AuthFormMode _mode;
  UserRole _selectedRole = UserRole.woman;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Whether to ask the phone's password manager to remember these details.
  ///
  /// The app never stores the password itself. Ticking this hands the pair to
  /// the keystore Android and iOS already use for every other app, which is
  /// what fills them in next time; leaving it unticked means nothing is
  /// offered for saving.
  bool _savePassword = true;

  final ApiAuthService _apiAuthService = ApiAuthService();

  bool _isTermsAccepted = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = BlushyOSProvider.of(context);
    if (state.selectedRole == 'partner') {
      _selectedRole = UserRole.partner;
    } else {
      _selectedRole = UserRole.woman;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthFormMode newMode) {
    setState(() {
      _mode = newMode;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_mode == AuthFormMode.signup && !_isTermsAccepted) {
      setState(() {
        _errorMessage = 'Please agree to the Terms & Conditions to proceed.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (_mode == AuthFormMode.signup) {
        final rawPhone = _phoneController.text.trim();
        final formattedPhone = rawPhone.isNotEmpty ? (rawPhone.startsWith('+91') ? rawPhone : '+91$rawPhone') : '';
        await _apiAuthService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          role: _selectedRole.value,
          displayName: _nameController.text.trim(),
          phoneNumber: formattedPhone,
          termsAccepted: _isTermsAccepted,
        );

        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          _offerToSaveCredentials();
          _showOtpVerificationDialog(_emailController.text.trim());
        }
      } else {
        final success = await _apiAuthService.loginWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          role: _selectedRole.value,
        );
        if (success && mounted) {
          _offerToSaveCredentials();
          final state = BlushyOSProvider.of(context);
          final onboardingCompleted = AuthStorage.isOnboardingCompleted();
          state.setAuthenticated(true, onboardingCompleted: onboardingCompleted);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = ApiAuthService.cleanErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Closes the autofill session so the phone offers to save what was typed.
  ///
  /// Only on success: offering to save a password that was just rejected would
  /// store the wrong one. Skipped entirely when the box is unticked.
  void _offerToSaveCredentials() {
    if (!_savePassword) return;
    TextInput.finishAutofillContext();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // On web the web client identifies the page. On Android and iOS it is
        // the *server* client, which is what makes Google mint an ID token at
        // all: without it `auth.idToken` comes back null and this silently
        // fell through to the access token instead.
        clientId: kIsWeb ? _googleWebClientId : null,
        serverClientId: kIsWeb ? null : _googleWebClientId,
        scopes: const ['email', 'profile'],
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _isSubmitting = false);
        return; // User cancelled
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final token = auth.idToken ?? auth.accessToken;

      if (token == null || token.isEmpty) {
        throw Exception('Failed to obtain Google authentication token.');
      }

      final success = await _apiAuthService.loginWithGoogle(token, role: _selectedRole.value);
      if (success && mounted) {
        final state = BlushyOSProvider.of(context);
        final onboardingCompleted = AuthStorage.isOnboardingCompleted();
        state.setAuthenticated(true, onboardingCompleted: onboardingCompleted);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // The Google path fails in more places than the network -- the
          // popup, Google's own checks on the client ID and origin, the
          // token exchange -- and every one of them was reported as "unable
          // to connect", which sent people to check a server that was fine.
          // The cause is named instead.
          final raw = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
          final cleaned = ApiAuthService.cleanErrorMessage(e);
          _errorMessage = cleaned.startsWith('Unable to connect')
              ? 'Google sign-in failed: $raw'
              : cleaned;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Confirms the account was created, then sends the user to the login tab.
  ///
  /// Verification returns a session token and `verifyCode` stores it, so the
  /// app could sign the user straight in. It deliberately does not: the token
  /// is cleared so that signing in is a real sign-in rather than a session the
  /// user never asked for, which also means the password they just chose gets
  /// exercised once while it is still fresh in mind.
  ///
  /// Before this, verification silently flipped the app into an authenticated
  /// state with no confirmation of any kind, so a successful signup and a
  /// failed one looked identical.
  /// Confirms the account was created, then sends the user to the login tab.
  /// Confirms the account was created, then seamlessly logs the user in.
  Future<void> _onAccountCreated(String email) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const SizedBox();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(curve),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF9), // Luxury warm background
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFECE4DC), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 36,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Success Badge with soft pulse ring
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC3E7CB), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2B7A4B).withValues(alpha: 0.15),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF2B7A4B),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Headline (Cormorant Garamond, 28px, Bold)
                      const Text(
                        'Account verified!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          letterSpacing: 0.4,
                          height: 1.15,
                          color: Color(0xFF2D2529),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle with email highlight
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.25,
                            height: 1.45,
                            color: Color(0xFF7A6B72),
                          ),
                          children: [
                            TextSpan(
                              text: email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D2529),
                              ),
                            ),
                            const TextSpan(
                              text: ' is verified and ready.\nWelcome to your wellness space.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Seamless Start Journey button (48px pill)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BlushyColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text(
                            "Start your journey",
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.normal,
                              letterSpacing: 0.35,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    // Auto-Login: User session is already saved in AuthStorage by verifyCode.
    // Seamlessly transition the user straight into the app!
    final state = BlushyOSProvider.of(context);
    final onboardingCompleted = AuthStorage.isOnboardingCompleted();
    state.setAuthenticated(true, onboardingCompleted: onboardingCompleted);
  }

  Future<void> _showOtpVerificationDialog(String email) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    String? dialogError;
    bool isVerifying = false;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const SizedBox();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(curve),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDF9),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFECE4DC), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 36,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Enter Verification Code',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'CormorantGaramond',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.normal,
                                letterSpacing: 0.4,
                                color: Color(0xFF2D2529),
                              ),
                            ),
                            const SizedBox(height: 8),

                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.25,
                                  height: 1.4,
                                  color: Color(0xFF7A6B72),
                                ),
                                children: [
                                  const TextSpan(text: 'We sent a 6-digit code to:\n'),
                                  TextSpan(
                                    text: email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D2529),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            if (dialogError != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFC0C0)),
                                ),
                                child: Text(
                                  dialogError!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.15,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (index) {
                                return SizedBox(
                                  width: 44,
                                  height: 52,
                                  child: TextField(
                                    controller: controllers[index],
                                    focusNode: focusNodes[index],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 1,
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                      color: Color(0xFF2D2529),
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                      filled: true,
                                      fillColor: Colors.white,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFFE6E0DA), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: BlushyColors.primary, width: 2.0),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      if (val.isNotEmpty && index < 5) {
                                        focusNodes[index + 1].requestFocus();
                                      } else if (val.isEmpty && index > 0) {
                                        focusNodes[index - 1].requestFocus();
                                      }
                                    },
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BlushyColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: isVerifying
                                    ? null
                                    : () async {
                                        final code = controllers.map((c) => c.text).join();
                                        if (code.length < 6) {
                                          setDialogState(() {
                                            dialogError = 'Please enter all 6 digits.';
                                          });
                                          return;
                                        }

                                        setDialogState(() {
                                          isVerifying = true;
                                          dialogError = null;
                                        });

                                        try {
                                          await _apiAuthService.verifyCode(email, code);
                                          if (context.mounted && mounted) {
                                            Navigator.of(dialogContext).pop();
                                            await _onAccountCreated(email);
                                          }
                                        } catch (e) {
                                          setDialogState(() {
                                            dialogError = ApiAuthService.cleanErrorMessage(e);
                                            isVerifying = false;
                                          });
                                        }
                                      },
                                child: isVerifying
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        AppLocalizations.of(context).sVerifyCode,
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          fontStyle: FontStyle.normal,
                                          letterSpacing: 0.35,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.25,
                                  color: Color(0xFF7A6B72),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = BlushyColors.primary;
    const bgPinkColor = BlushyColors.background;
    const borderColor = BlushyColors.border;
    const textDark = Color(0xFF2D2529);
    const textMuted = Color(0xFF7A6B72);

    return Scaffold(
      backgroundColor: bgPinkColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              // The fields have to sit in one group for the phone to
              // treat them as a single credential worth saving.
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      // Brand Logo Wordmark Header Bar (44px height stack, exact match with choose_experience_screen)
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 0,
                              child: IconButton(
                                onPressed: () {
                                  final state = BlushyOSProvider.of(context);
                                  state.resetChosenExperience();
                                },
                                icon: const Icon(Icons.arrow_back_rounded, size: 22, color: textDark),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ),
                            RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.normal,
                                  letterSpacing: 2.8,
                                  color: Color(0xFFE51937),
                                ),
                                children: [
                                  TextSpan(text: 'BLUSHY'),
                                  TextSpan(
                                    text: '.',
                                    style: TextStyle(
                                      color: Color(0xFFFF5000),
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Top Tab Switcher: Log In | Create Account
                      Container(
                        height: 44,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFE8E2),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _switchMode(AuthFormMode.login),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: _mode == AuthFormMode.login ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(19),
                                    boxShadow: _mode == AuthFormMode.login
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.25,
                                      color: _mode == AuthFormMode.login ? primaryColor : textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _switchMode(AuthFormMode.signup),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: _mode == AuthFormMode.signup ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(19),
                                    boxShadow: _mode == AuthFormMode.signup
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.25,
                                      color: _mode == AuthFormMode.signup ? primaryColor : textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Header Title (Cormorant Garamond, 32px, w700 Bold, NO Italics)
                      Text(
                        _mode == AuthFormMode.signup ? 'Create account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 32,
                          fontWeight: FontWeight.w700, // Rich Bold Cormorant Garamond
                          fontStyle: FontStyle.normal,
                          letterSpacing: 0.4,
                          height: 1.15,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _mode == AuthFormMode.signup ? 'Begin your wellness journey' : 'Sign in to your Blushy account',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.25,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            final state = BlushyOSProvider.of(context);
                            final targetRole = _selectedRole == UserRole.woman ? 'partner' : 'woman';
                            state.setSelectedRole(targetRole);
                            setState(() {
                              _selectedRole = targetRole == 'partner' ? UserRole.partner : UserRole.woman;
                              _errorMessage = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedRole == UserRole.woman ? Icons.person_outline_rounded : Icons.people_outline_rounded,
                                  size: 14,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedRole == UserRole.woman ? 'Woman Experience' : 'Partner Experience',
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.25,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.swap_horiz_rounded, size: 13, color: primaryColor.withValues(alpha: 0.6)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                    // Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFC0C0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 12,
                                      color: Color(0xFFE53935),
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_errorMessage!.contains('switch to the Woman experience') || _errorMessage!.contains('registered as a Woman')) ...[
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () {
                                  final state = BlushyOSProvider.of(context);
                                  state.setSelectedRole('woman');
                                  setState(() {
                                    _selectedRole = UserRole.woman;
                                    _errorMessage = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    '👉 Switch to Woman Experience',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      color: Color(0xFFE53935),
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (_errorMessage!.contains('switch to the Partner experience') || _errorMessage!.contains('registered as a Partner')) ...[
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () {
                                  final state = BlushyOSProvider.of(context);
                                  state.setSelectedRole('partner');
                                  setState(() {
                                    _selectedRole = UserRole.partner;
                                    _errorMessage = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    '👉 Switch to Partner Experience',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      color: Color(0xFFE53935),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Success Banner
                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FFF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFB7EB8F)),
                        ),
                        child: Text(
                          _successMessage!,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            color: Colors.green.shade800,
                            height: 1.4,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],


                    // Email Field
                    _buildFieldLabel('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13.5,
                        color: textDark,
                        letterSpacing: 0.2,
                      ),
                      decoration: _buildInputDecoration('you@example.com', Icons.mail_outline),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email is required';
                        if (!val.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number Field (Signup mode only)
                    if (_mode == AuthFormMode.signup) ...[
                      _buildFieldLabel('Phone number'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13.5,
                          color: textDark,
                          letterSpacing: 0.2,
                        ),
                        decoration: _buildInputDecoration('10-digit mobile number', Icons.phone_outlined).copyWith(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 14, right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_outlined, size: 18, color: Color(0xFFA5959C)),
                                const SizedBox(width: 6),
                                const Text(
                                  '+91',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                Container(
                                  height: 16,
                                  width: 1,
                                  color: const Color(0xFFF5D6DE),
                                  margin: const EdgeInsets.only(left: 8, right: 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (_mode == AuthFormMode.signup) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (val.trim().length != 10) {
                              return 'Phone number must be exactly 10 digits';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Password Field Header (with Forgot password? link in Login mode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFieldLabel('Password'),
                        if (_mode == AuthFormMode.login)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EmailAuthFlow(
                                    initialMode: AuthMode.forgotPassword,
                                    initialEmail:
                                        _emailController.text.trim(),
                                    onBackToWelcome: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context).sForgotPassword,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: [
                        _mode == AuthFormMode.signup
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13.5,
                        color: textDark,
                        letterSpacing: 0.2,
                      ),
                      decoration: _buildInputDecoration('Minimum 8 characters', Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 8) return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),

                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _savePassword,
                            activeColor: BlushyColors.primary,
                            onChanged: (value) =>
                                setState(() => _savePassword = value ?? false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _savePassword = !_savePassword),
                            child: const Text(
                              'Save my password on this device',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                                color: textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Terms Checkbox (Signup mode only)
                    if (_mode == AuthFormMode.signup) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _isTermsAccepted,
                              activeColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) => setState(() => _isTermsAccepted = val ?? false),
                            ),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).sIAgreeToThe,
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 12,
                                      color: textDark,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                                    child: Text(
                                      AppLocalizations.of(context).sTermsConditions,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                        color: primaryColor,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Primary Submit Button (48px height pill, matching choose_experience_screen)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE5DFD9),
                          disabledForegroundColor: const Color(0xFF9E948E),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _mode == AuthFormMode.signup
                                    ? 'Send verification link'
                                    : 'Sign in',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.normal,
                                  letterSpacing: 0.35,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Helper Info Box (Signup mode only)
                    if (_mode == AuthFormMode.signup) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "Signup requires email verification. Check your inbox. If you haven't received the email, you can verify it below.",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: textMuted,
                            height: 1.4,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // OR Divider
                    const Row(
                      children: [
                        Expanded(child: Divider(color: borderColor)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: textMuted,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: borderColor)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Continue with Google Button (48px height pill, matching premium design system)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE6E0DA), width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.login_rounded, size: 18, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.normal,
                                letterSpacing: 0.3,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Footers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'By continuing, you agree to our ',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: textMuted,
                            letterSpacing: 0.15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                          child: Text(
                            AppLocalizations.of(context).sTerms,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text(
                          ' & ',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: textMuted,
                            letterSpacing: 0.15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.privacyPolicy),
                          child: Text(
                            AppLocalizations.of(context).sPrivacyPolicy,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Toggle Link: New to Blushy? Create one / Already have an account? Log in
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _mode == AuthFormMode.login ? 'New to Blushy? ' : 'Already have an account? ',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            color: textMuted,
                            letterSpacing: 0.15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _switchMode(_mode == AuthFormMode.login ? AuthFormMode.signup : AuthFormMode.login),
                          child: Text(
                            _mode == AuthFormMode.login ? 'Create one' : 'Sign in',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: Color(0xFF2D2529),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 13,
        color: Color(0xFFA5959C),
        letterSpacing: 0.2,
      ),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFA5959C)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BlushyColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BlushyColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
