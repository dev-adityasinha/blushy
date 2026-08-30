import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/state.dart';
import '../../../models/auth_models.dart';
import '../../../services/api_auth_service.dart';
import '../../../services/auth_storage.dart';
import '../../legal/legal_documents_screen.dart';

enum AuthFormMode { login, signup }

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
          _showOtpVerificationDialog(_emailController.text.trim());
        }
      } else {
        final success = await _apiAuthService.loginWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          role: _selectedRole.value,
        );
        if (success && mounted) {
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? '1026935398251-f1uvakds07sran9i87kgq1oon3vu4uo4.apps.googleusercontent.com' : null,
        scopes: ['email', 'profile'],
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: const Color(0xFFFAF6F0),
              title: Text(
                'Enter Verification Code',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
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
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF7A6B72)),
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
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade800),
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
                            style: GoogleFonts.poppins(
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
                                borderSide: const BorderSide(color: Color(0xFFEFEAE2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFDD0D22), width: 2),
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
                          backgroundColor: const Color(0xFFDD0D22),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                                    final state = BlushyOSProvider.of(this.context);
                                    final onboardingCompleted = AuthStorage.isOnboardingCompleted();
                                    state.setAuthenticated(true, onboardingCompleted: onboardingCompleted);
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
                                'Verify Code',
                                style: GoogleFonts.poppins(
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
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF7A6B72)),
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
    const primaryColor = Color(0xFFDD0D22);
    const bgPinkColor = Color(0xFFFAF6F0);
    const cardSelectedBg = Color(0xFFFDF2F2);
    const borderColor = Color(0xFFEFEAE2);
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
                          style: GoogleFonts.poppins(fontSize: 12, color: textMuted),
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
                        color: const Color(0xFFEFEAE2),
                        borderRadius: BorderRadius.circular(24),
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
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _mode == AuthFormMode.login
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Log In',
                                  style: GoogleFonts.poppins(
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
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _mode == AuthFormMode.signup
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Create Account',
                                  style: GoogleFonts.poppins(
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
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mode == AuthFormMode.signup ? 'Create an account in seconds' : 'Sign in to continue your journey',
                      style: GoogleFonts.poppins(
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
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
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
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: primaryColor),
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
                                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFE53935), height: 1.4, fontWeight: FontWeight.w500),
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
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE53935)),
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
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE53935)),
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
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800, height: 1.4),
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
                        style: GoogleFonts.poppins(fontSize: 14, color: textDark),
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
                      style: GoogleFonts.poppins(fontSize: 14, color: textDark),
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
                        style: GoogleFonts.poppins(fontSize: 14, color: textDark),
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
                                  style: GoogleFonts.poppins(
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
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password reset link sent to your email.')),
                              );
                            },
                            child: Text(
                              'Forgot password?',
                              style: GoogleFonts.poppins(
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
                      style: GoogleFonts.poppins(fontSize: 14, color: textDark),
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
                    const SizedBox(height: 20),

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
                                  Text('I agree to the ', style: GoogleFonts.poppins(fontSize: 12, color: textDark)),
                                  GestureDetector(
                                    onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                                    child: Text(
                                      'Terms & Conditions',
                                      style: GoogleFonts.poppins(
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
                          colors: [Color(0xFFDD0D22), Color(0xFFE52035)],
                        ),
                        borderRadius: BorderRadius.circular(28),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _mode == AuthFormMode.signup ? 'Send verification link' : 'Sign in',
                                style: GoogleFonts.poppins(
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
                          style: GoogleFonts.poppins(fontSize: 11, color: textMuted, height: 1.4),
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
                          child: Text('OR', style: GoogleFonts.poppins(fontSize: 11, color: textMuted)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        backgroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.login, size: 18, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Continue with Google',
                            style: GoogleFonts.poppins(
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
                        Text('By continuing, you agree to our ', style: GoogleFonts.poppins(fontSize: 11, color: textMuted)),
                        GestureDetector(
                          onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.termsAndConditions),
                          child: Text(
                            'Terms',
                            style: GoogleFonts.poppins(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                          ),
                        ),
                        Text(' & ', style: GoogleFonts.poppins(fontSize: 11, color: textMuted)),
                        GestureDetector(
                          onTap: () => LegalDocumentsScreen.show(context, initialTab: LegalTab.privacyPolicy),
                          child: Text(
                            'Privacy Policy',
                            style: GoogleFonts.poppins(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
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
                          style: GoogleFonts.poppins(fontSize: 13, color: textMuted),
                        ),
                        GestureDetector(
                          onTap: () => _switchMode(_mode == AuthFormMode.login ? AuthFormMode.signup : AuthFormMode.login),
                          child: Text(
                            _mode == AuthFormMode.login ? 'Create one' : 'Log in',
                            style: GoogleFonts.poppins(
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
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF2D2529),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFA5959C)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFA5959C)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Color(0xFFEFEAE2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Color(0xFFDD0D22), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
