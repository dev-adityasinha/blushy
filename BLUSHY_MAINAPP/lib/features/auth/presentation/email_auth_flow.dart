import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../theme/colors.dart';
import '../../../theme/spacing.dart';
import 'auth_service.dart';
import '../../../services/api_auth_service.dart';
import '../../../services/auth_storage.dart';
import '../../../l10n/app_localizations.dart';

enum AuthMode { signupEmail, signupPassword, signupVerify, login, forgotPassword, resetPassword }

class EmailAuthFlow extends StatefulWidget {
  final AuthMode initialMode;
  final VoidCallback onBackToWelcome;

  const EmailAuthFlow({
    super.key,
    required this.initialMode,
    required this.onBackToWelcome,
  });

  @override
  State<EmailAuthFlow> createState() => _EmailAuthFlowState();
}

class _EmailAuthFlowState extends State<EmailAuthFlow> {
  late AuthMode _currentMode;
  final AuthService _authService = ApiAuthService();

  // Inputs
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());

  // Error & Loading States
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _codeError;
  String? _generalError;
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _codeResending = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _codeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _codeError = null;
      _generalError = null;
    });
  }

  bool _validateEmail(String email) {
    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email.');
      return false;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address.');
      return false;
    }
    return true;
  }

  Future<void> _handleEmailSubmit() async {
    _clearErrors();
    final email = _emailController.text.trim();
    if (!_validateEmail(email)) return;

    setState(() => _isLoading = true);
    try {
      // For email signup, we call signUpWithEmail.
      // If it throws an exception that account already exists, we handle it.
      await _authService.signUpWithEmail(email, 'temp_password_check');
      setState(() {
        _currentMode = AuthMode.signupPassword;
      });
    } catch (e) {
      final msg = ApiAuthService.cleanErrorMessage(e);
      if (msg.contains('already have a Blushy account')) {
        setState(() {
          _emailError = msg;
        });
      } else {
        setState(() {
          _generalError = msg;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordSubmit() async {
    _clearErrors();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    bool hasError = false;
    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter a password.');
      hasError = true;
    } else if (password.length < 8) {
      setState(() => _passwordError = 'Your password must be at least 8 characters.');
      hasError = true;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password.');
      hasError = true;
    } else if (password != confirmPassword) {
      setState(() => _confirmPasswordError = "Passwords don't match.");
      hasError = true;
    }

    if (hasError) return;

    // Proceed to verification step
    setState(() {
      _currentMode = AuthMode.signupVerify;
    });
  }

  Future<void> _handleVerifySubmit() async {
    _clearErrors();
    final code = _codeControllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _codeError = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.verifyCode(_emailController.text.trim(), code);
      // Success! Proceed to authenticated state, which triggers OnboardingWizard
      if (mounted) {
        final state = BlushyOSProvider.of(context);
        state.setAuthenticated(true, onboardingCompleted: AuthStorage.isOnboardingCompleted());
      }
    } catch (e) {
      setState(() {
        _codeError = ApiAuthService.cleanErrorMessage(e);
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLoginSubmit() async {
    _clearErrors();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    bool hasError = false;
    if (!_validateEmail(email)) hasError = true;
    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter a password.');
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isLoading = true);
    try {
      final state = BlushyOSProvider.of(context);
      await _authService.loginWithEmail(email, password, role: state.selectedRole);
      if (mounted) {
        state.setAuthenticated(true, onboardingCompleted: AuthStorage.isOnboardingCompleted());
      }
    } catch (e) {
      setState(() {
        _generalError = ApiAuthService.cleanErrorMessage(e);
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPasswordSubmit() async {
    _clearErrors();
    final email = _emailController.text.trim();
    if (!_validateEmail(email)) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await _authService.requestPasswordResetCode(email);
      messenger.showSnackBar(
        const SnackBar(content: Text('If an account exists for that email, a code is on its way.')),
      );
      for (final controller in _codeControllers) {
        controller.clear();
      }
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _currentMode = AuthMode.resetPassword;
      });
    } catch (e) {
      setState(() {
        _generalError = ApiAuthService.cleanErrorMessage(e);
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPasswordSubmit() async {
    _clearErrors();
    final email = _emailController.text.trim();
    final code = _codeControllers.map((c) => c.text).join();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (code.length != 6) {
      setState(() => _codeError = 'Enter the 6-digit code from your email.');
      return;
    }
    if (password.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _confirmPasswordError = 'Passwords do not match.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(
        email: email,
        code: code,
        newPassword: password,
        confirmPassword: confirm,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Password updated. Please sign in.')),
      );
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _currentMode = AuthMode.login;
      });
    } catch (e) {
      setState(() {
        _generalError = ApiAuthService.cleanErrorMessage(e);
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _codeResending = true);
    try {
      // Mock code resend
      await Future.delayed(const Duration(seconds: 1));
      messenger.showSnackBar(
        const SnackBar(content: Text('A new code has been sent.')),
      );
    } catch (_) {}
    setState(() => _codeResending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: BlushyColors.text, size: 20),
          onPressed: () {
            if (_currentMode == AuthMode.signupPassword) {
              setState(() => _currentMode = AuthMode.signupEmail);
            } else if (_currentMode == AuthMode.signupVerify) {
              setState(() => _currentMode = AuthMode.signupPassword);
            } else if (_currentMode == AuthMode.forgotPassword) {
              setState(() => _currentMode = AuthMode.login);
            } else if (_currentMode == AuthMode.resetPassword) {
              setState(() => _currentMode = AuthMode.forgotPassword);
            } else {
              widget.onBackToWelcome();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: BlushySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              if (_generalError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
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
                          const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _generalError!,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE53935),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_generalError!.contains('switch to the Woman experience') || _generalError!.contains('registered as a Woman')) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () {
                            final state = BlushyOSProvider.of(context);
                            state.setSelectedRole('woman');
                            setState(() {
                              _generalError = null;
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
                      ] else if (_generalError!.contains('switch to the Partner experience') || _generalError!.contains('registered as a Partner')) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () {
                            final state = BlushyOSProvider.of(context);
                            state.setSelectedRole('partner');
                            setState(() {
                              _generalError = null;
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
                const SizedBox(height: 20),
              ],
              _buildFlowScreen(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlowScreen() {
    switch (_currentMode) {
      case AuthMode.signupEmail:
        return _buildEmailInputScreen(isSignup: true);
      case AuthMode.signupPassword:
        return _buildPasswordCreationScreen();
      case AuthMode.signupVerify:
        return _buildVerificationScreen();
      case AuthMode.login:
        return _buildLoginScreen();
      case AuthMode.forgotPassword:
        return _buildForgotPasswordScreen();
      case AuthMode.resetPassword:
        return _buildResetPasswordScreen();
    }
  }

  Widget _buildEmailInputScreen({required bool isSignup}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).eafWhatSYourEmail,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We'll use this to secure your private wellness space.",
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _emailController,
          labelText: 'Email Address',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
        ),
        if (_emailError != null && _emailError!.contains('already have a Blushy account')) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentMode = AuthMode.login;
                      _clearErrors();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BlushyColors.primary,
                    side: const BorderSide(color: BlushyColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Log in instead?'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _emailController.clear();
                    _clearErrors();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: BlushyColors.secondaryText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Use another email'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 40),
        _buildButton(
          label: 'Continue',
          onPressed: _handleEmailSubmit,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildPasswordCreationScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).eafCreateYourPassword,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Ensure your space is private and secure.",
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _passwordController,
          labelText: 'Password',
          obscureText: !_isPasswordVisible,
          errorText: _passwordError,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: BlushyColors.secondaryText,
            ),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPasswordController,
          labelText: 'Confirm Password',
          obscureText: !_isConfirmPasswordVisible,
          errorText: _confirmPasswordError,
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: BlushyColors.secondaryText,
            ),
            onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
          ),
        ),
        const SizedBox(height: 40),
        _buildButton(
          label: 'Continue',
          onPressed: _handlePasswordSubmit,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildVerificationScreen() {
    final obscuredEmail = (() {
      final email = _emailController.text.trim();
      final parts = email.split('@');
      if (parts.length < 2) return email;
      final name = parts[0];
      final domain = parts[1];
      if (name.length <= 2) return '$name••••@$domain';
      return '${name.substring(0, 1)}••••${name.substring(name.length - 1)}@$domain';
    })();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).eafCheckYourEmail,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We sent a verification code to $obscuredEmail",
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 32),
        _buildCodeBoxes(),
        if (_codeError != null) ...[
          const SizedBox(height: 16),
          Text(
            _codeError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: BlushyColors.primary, fontSize: 14),
          ),
        ],
        const SizedBox(height: 32),
        _buildButton(
          label: 'Verify',
          onPressed: _handleVerifySubmit,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _codeResending ? null : _resendCode,
              child: _codeResending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: BlushyColors.primary),
                    )
                  : Text(
                      'Resend code',
                      style: GoogleFonts.poppins(color: BlushyColors.primary, fontWeight: FontWeight.bold),
                    ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentMode = AuthMode.signupEmail;
                  _clearErrors();
                });
              },
              child: Text(
                AppLocalizations.of(context).eafChangeEmail,
                style: GoogleFonts.poppins(color: BlushyColors.secondaryText),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildLoginScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).eafWelcomeBack,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Log in to retrieve your personalized health workspace.",
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _emailController,
          labelText: 'Email Address',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          labelText: 'Password',
          obscureText: !_isPasswordVisible,
          errorText: _passwordError,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: BlushyColors.secondaryText,
            ),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _currentMode = AuthMode.forgotPassword;
                _clearErrors();
              });
            },
            child: Text(
              AppLocalizations.of(context).eafForgotPassword,
              style: GoogleFonts.poppins(color: BlushyColors.secondaryText),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildButton(
          label: 'Log in',
          onPressed: _handleLoginSubmit,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildForgotPasswordScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).eafResetPassword,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email to receive recovery instructions.",
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 32),
        _buildTextField(
          controller: _emailController,
          labelText: 'Email Address',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
        ),
        const SizedBox(height: 40),
        _buildButton(
          label: 'Send Recovery Code',
          onPressed: _handleForgotPasswordSubmit,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  /// The six single-character boxes, shared by signup verification and the
  /// password reset step so the two stay consistent.
  Widget _buildCodeBoxes() {
    return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _codeControllers[index],
                focusNode: _codeFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: BlushyColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: BlushyColors.primary, width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _codeFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _codeFocusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
    );
  }

  Widget _buildResetPasswordScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocalizations.of(context).eafChooseANewPassword,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: BlushyColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter the 6-digit code we emailed you, then pick a new password.",
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: BlushyColors.secondaryText,
          ),
        ),
        const SizedBox(height: 32),
        _buildCodeBoxes(),
        if (_codeError != null) ...[
          const SizedBox(height: 16),
          Text(
            _codeError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: BlushyColors.primary, fontSize: 14),
          ),
        ],
        const SizedBox(height: 24),
        _buildTextField(
          controller: _passwordController,
          labelText: 'New Password',
          obscureText: !_isPasswordVisible,
          errorText: _passwordError,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: BlushyColors.secondaryText,
            ),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPasswordController,
          labelText: 'Confirm New Password',
          obscureText: !_isConfirmPasswordVisible,
          errorText: _confirmPasswordError,
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: BlushyColors.secondaryText,
            ),
            onPressed: () =>
                setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
          ),
        ),
        const SizedBox(height: 32),
        _buildButton(
          label: 'Update Password',
          onPressed: _handleResetPasswordSubmit,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : _handleForgotPasswordSubmit,
          child: Text(
            'Send a new code',
            style: GoogleFonts.poppins(color: BlushyColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    String? errorText,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: BlushyColors.text),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: BlushyColors.secondaryText),
        errorText: errorText,
        errorStyle: GoogleFonts.poppins(color: BlushyColors.primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: BlushyColors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BlushyColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BlushyColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: BlushyColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
