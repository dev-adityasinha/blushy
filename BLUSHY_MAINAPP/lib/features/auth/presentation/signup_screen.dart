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
      '1026935398251-f1uvakds07sran9i87kgq1oon3vu4uo4.apps.googleusercontent.com',
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
          _errorMessage = ApiAuthService.cleanErrorMessage(e);
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
  Future<void> _onAccountCreated(String email) async {
    AuthStorage.clearSession();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: BlushyColors.background,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF7EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF2E7D4F), size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Account created',
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSerif(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D2529),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$email is verified and ready.\n'
                  'Sign in to start your journey.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF7A6B72)),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BlushyColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  AppLocalizations.of(context).sGoToSignIn,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    // The email carries over so the only thing left to type is the password.
    setState(() {
      _mode = AuthFormMode.login;
      _emailController.text = email;
      _passwordController.clear();
      _errorMessage = null;
      _successMessage = 'Account created. Sign in to continue.';
    });
  }

  Future<void> _showOtpVerificationDialog(String email) async {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());
    String? dialogError;
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: BlushyColors.background,
              title: Text(
                'Enter Verification Code',
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSerif(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D2529),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'We sent a 6-digit code to:\n$email',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF7A6B72)),
                    ),
                    const SizedBox(height: 20),
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dialogError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(fontSize: 12, color: Colors.red.shade800),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 40,
                          height: 48,
                          child: TextField(
                            controller: controllers[index],
                            focusNode: focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D2529),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: BlushyColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: BlushyColors.primary, width: 2),
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BlushyColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                  // `mounted` covers this.context, which the
                                  // dialog's own context.mounted does not.
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
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                AppLocalizations.of(context).sVerifyCode,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFF7A6B72)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = BlushyColors.primary;
    const bgPinkColor = BlushyColors.background;
    const cardSelectedBg = Color(0xFFFDF2F2);
    const borderColor = BlushyColors.border;
    const textDark = Color(0xFF2D2529);
    const textMuted = Color(0xFF7A6B72);

    return Scaffold(
      backgroundColor: bgPinkColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              // The fields have to sit in one group for the phone to
              // treat them as a single credential worth saving.
              child: AutofillGroup(
                child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button to return to Choose Experience screen
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          final state = BlushyOSProvider.of(context);
                          state.resetChosenExperience();
                        },
                        icon: const Icon(Icons.arrow_back, size: 18, color: textMuted),
                        label: Text(
                          'Back to experience choice',
                          style: GoogleFonts.manrope(fontSize: 12, color: textMuted),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Top Tab Switcher: Log In | Create Account
                    Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: BlushyColors.border,
                        borderRadius: BorderRadius.circular(12),
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
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _mode == AuthFormMode.login
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Log In',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
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
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _mode == AuthFormMode.signup
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Create Account',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _mode == AuthFormMode.signup ? primaryColor : textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Header Title
                    Text(
                      _mode == AuthFormMode.signup ? 'Join the Blushy family' : 'Welcome back, lovely',
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mode == AuthFormMode.signup ? 'Create an account in seconds' : 'Sign in to continue your journey',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardSelectedBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedRole == UserRole.woman ? Icons.favorite : Icons.handshake,
                                size: 14,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedRole == UserRole.woman ? 'Primary Account (Woman)' : 'Support Account (Man)',
                                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final state = BlushyOSProvider.of(context);
                            final targetRole = _selectedRole == UserRole.woman ? 'partner' : 'woman';
                            state.setSelectedRole(targetRole);
                            setState(() {
                              _selectedRole = targetRole == 'partner' ? UserRole.partner : UserRole.woman;
                              _errorMessage = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _selectedRole == UserRole.woman ? 'Switch to Partner' : 'Switch to Woman',
                            style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                                    style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFFE53935), height: 1.4, fontWeight: FontWeight.w500),
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
                                  child: Text(
                                    '👉 Switch to Woman Experience',
                                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE53935)),
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
                                  child: Text(
                                    '👉 Switch to Partner Experience',
                                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE53935)),
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
                          style: GoogleFonts.manrope(fontSize: 12, color: Colors.green.shade800, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Display Name (Signup mode only)
                    if (_mode == AuthFormMode.signup) ...[
                      _buildFieldLabel('Display name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.manrope(fontSize: 14, color: textDark),
                        decoration: _buildInputDecoration('Your name', Icons.person_outline),
                        validator: (val) {
                          if (_mode == AuthFormMode.signup && (val == null || val.trim().isEmpty)) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
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
                      style: GoogleFonts.manrope(fontSize: 14, color: textDark),
                      decoration: _buildInputDecoration('you@example.com', Icons.mail_outline),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email is required';
                        if (!val.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

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
                        style: GoogleFonts.manrope(fontSize: 14, color: textDark),
                        decoration: _buildInputDecoration('10-digit mobile number', Icons.phone_outlined).copyWith(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 14, right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_outlined, size: 18, color: Color(0xFFA5959C)),
                                const SizedBox(width: 6),
                                Text(
                                  '+91',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
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
                      const SizedBox(height: 18),
                    ],

                    // Password Field Header (with Forgot password? link in Login mode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFieldLabel('Password'),
                        if (_mode == AuthFormMode.login)
                          GestureDetector(
                            // This used to show "Password reset link sent to
                            // your email." and send nothing at all, so the
                            // wait was for an email that was never coming.
                            // It opens the flow that actually requests one.
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
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
                      // newPassword on signup, so the manager offers to
                      // generate and save one rather than filling an old one.
                      autofillHints: [
                        _mode == AuthFormMode.signup
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      style: GoogleFonts.manrope(fontSize: 14, color: textDark),
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

                    // Handing the pair to the phone's password manager, which
                    // is what fills them in next time. The app itself never
                    // keeps the password.
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
                            child: Text(
                              'Save my password on this device',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
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
                                  Text(AppLocalizations.of(context).sIAgreeToThe, style: GoogleFonts.manrope(fontSize: 12, color: textDark)),
                                  GestureDetector(
                                    onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                                    child: Text(
                                      AppLocalizations.of(context).sTermsConditions,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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

                    // Primary Submit Button: Sign in ✨ / Send verification link
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [BlushyColors.primary, Color(0xFFE52035)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _mode == AuthFormMode.signup ? 'Send verification link' : 'Sign in',
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
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
                        child: Text(
                          "Signup requires email verification. Check your inbox. If you haven't received the email, you can verify it below.",
                          style: GoogleFonts.manrope(fontSize: 11, color: textMuted, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // OR Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: borderColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR', style: GoogleFonts.manrope(fontSize: 11, color: textMuted)),
                        ),
                        const Expanded(child: Divider(color: borderColor)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Continue with Google Button
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.login, size: 18, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Continue with Google',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('By continuing, you agree to our ', style: GoogleFonts.manrope(fontSize: 11, color: textMuted)),
                        GestureDetector(
                          onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                          child: Text(
                            AppLocalizations.of(context).sTerms,
                            style: GoogleFonts.manrope(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                          ),
                        ),
                        Text(' & ', style: GoogleFonts.manrope(fontSize: 11, color: textMuted)),
                        GestureDetector(
                          onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.privacyPolicy),
                          child: Text(
                            AppLocalizations.of(context).sPrivacyPolicy,
                            style: GoogleFonts.manrope(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
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
                          style: GoogleFonts.manrope(fontSize: 13, color: textMuted),
                        ),
                        GestureDetector(
                          onTap: () => _switchMode(_mode == AuthFormMode.login ? AuthFormMode.signup : AuthFormMode.login),
                          child: Text(
                            _mode == AuthFormMode.login ? 'Create one' : 'Log in',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
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
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF2D2529),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(fontSize: 13, color: const Color(0xFFA5959C)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFA5959C)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
