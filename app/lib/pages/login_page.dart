import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth/auth_action_runner.dart';
import 'auth/google_sign_in_web_button_stub.dart'
    if (dart.library.js_interop) 'auth/google_sign_in_web_button_web.dart'
    as google_sign_in_web_button;
import 'auth/login_page_support.dart';
import '../services/auth_service.dart';
import '../services/premium_service.dart';
import '../l10n/app_localizations.dart';
import 'business_signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _signInEmailCtrl = TextEditingController();
  final _signInPasswordCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPasswordCtrl = TextEditingController();
  final _signUpConfirmPasswordCtrl = TextEditingController();

  LoginPageMode _mode = LoginPageMode.signIn;
  bool _obscureSignInPassword = true;
  bool _obscureSignUpPassword = true;
  bool _obscureSignUpConfirmPassword = true;
  bool _loading = false;
  String? _error;
  LoginValidationCode? _signInEmailError;
  LoginValidationCode? _signInPasswordError;
  LoginValidationCode? _signUpEmailError;
  LoginValidationCode? _signUpPasswordError;
  LoginValidationCode? _signUpConfirmPasswordError;
  bool _googleWebReady = false;
  bool _googleWebLoading = false;
  bool _handlingGoogleWebSignIn = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSub;

  bool get _supportsAppleSignInUi => AuthService.instance.supportsAppleSignInUi;

  bool get _isBusy => _loading || _handlingGoogleWebSignIn;

  Future<void> _submitPrimaryAction() async {
    if (_mode == LoginPageMode.signIn) {
      await _submitSignIn();
      return;
    }
    await _submitSignUp();
  }

  Future<void> _submitSignIn() async {
    final email = _signInEmailCtrl.text.trim();
    final password = _signInPasswordCtrl.text;
    final emailError = validateLoginEmail(email);
    final passwordError = validateLoginPassword(
      password,
      requireMinimumLength: false,
    );

    setState(() {
      _signInEmailError = emailError;
      _signInPasswordError = passwordError;
    });

    if (emailError != null || passwordError != null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.signInWithEmailPassword(
        email: email,
        password: password,
      );
      await _syncPremiumAfterLogin();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/account-ui');
    } catch (e) {
      _setPageError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitSignUp() async {
    final email = _signUpEmailCtrl.text.trim();
    final password = _signUpPasswordCtrl.text;
    final confirmation = _signUpConfirmPasswordCtrl.text;
    final emailError = validateLoginEmail(email);
    final passwordError = validateLoginPassword(
      password,
      requireMinimumLength: true,
    );
    final confirmPasswordError = validatePasswordConfirmation(
      password: password,
      confirmation: confirmation,
    );

    setState(() {
      _signUpEmailError = emailError;
      _signUpPasswordError = passwordError;
      _signUpConfirmPasswordError = confirmPasswordError;
    });

    if (emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.createUserWithEmailPassword(
        email: email,
        password: password,
      );
      await _syncPremiumAfterLogin();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/account-ui');
    } catch (e) {
      _setPageError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runProvider(AuthAction action) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => AuthActionRunner(action: action)),
      );

      if (!mounted) return;

      if (result != true) {
        return;
      }

      Navigator.of(context).pushReplacementNamed('/account-ui');
    } catch (e) {
      _setPageError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _prepareGoogleWeb() async {
    if (!kIsWeb) return;

    setState(() {
      _googleWebLoading = true;
      _googleWebReady = false;
      _error = null;
    });

    try {
      await AuthService.instance.ensureGoogleSignInInitialized();
      await _googleAuthSub?.cancel();
      _googleAuthSub = GoogleSignIn.instance.authenticationEvents.listen(
        (event) async {
          switch (event) {
            case GoogleSignInAuthenticationEventSignIn():
              await _completeGoogleWebSignIn(event.user);
            case GoogleSignInAuthenticationEventSignOut():
              break;
          }
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _error = _friendlyAuthMessage(error);
            _googleWebLoading = false;
            _googleWebReady = false;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _googleWebLoading = false;
        _googleWebReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyAuthMessage(e);
        _googleWebLoading = false;
        _googleWebReady = false;
      });
    }
  }

  Future<void> _completeGoogleWebSignIn(GoogleSignInAccount googleUser) async {
    if (_handlingGoogleWebSignIn) return;

    setState(() {
      _loading = true;
      _error = null;
      _handlingGoogleWebSignIn = true;
    });

    var navigated = false;
    try {
      await AuthService.instance.signInWithGoogleAccount(googleUser);
      await _syncPremiumAfterLogin();

      if (!mounted) return;
      navigated = true;
      Navigator.of(context).pushReplacementNamed('/account-ui');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyAuthMessage(e);
      });
    } finally {
      if (mounted && !navigated) {
        setState(() {
          _loading = false;
          _handlingGoogleWebSignIn = false;
        });
      }
    }
  }

  Future<void> _syncPremiumAfterLogin() async {
    if (kIsWeb) return;

    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      await PremiumService.instance.logIn(uid);
    }
  }

  @override
  void dispose() {
    _googleAuthSub?.cancel();
    _signInEmailCtrl.dispose();
    _signInPasswordCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _signUpConfirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _signInEmailCtrl.addListener(() {
      if (_signInEmailError != null ||
          (_mode == LoginPageMode.signIn && _error != null)) {
        setState(() {
          _signInEmailError = null;
          if (_mode == LoginPageMode.signIn) _error = null;
        });
      }
    });
    _signInPasswordCtrl.addListener(() {
      if (_signInPasswordError != null ||
          (_mode == LoginPageMode.signIn && _error != null)) {
        setState(() {
          _signInPasswordError = null;
          if (_mode == LoginPageMode.signIn) _error = null;
        });
      }
    });
    _signUpEmailCtrl.addListener(() {
      if (_signUpEmailError != null ||
          (_mode == LoginPageMode.signUp && _error != null)) {
        setState(() {
          _signUpEmailError = null;
          if (_mode == LoginPageMode.signUp) _error = null;
        });
      }
    });
    _signUpPasswordCtrl.addListener(() {
      if (_signUpPasswordError != null ||
          _signUpConfirmPasswordError != null ||
          (_mode == LoginPageMode.signUp && _error != null)) {
        setState(() {
          _signUpPasswordError = null;
          _signUpConfirmPasswordError = null;
          if (_mode == LoginPageMode.signUp) _error = null;
        });
      }
    });
    _signUpConfirmPasswordCtrl.addListener(() {
      if (_signUpConfirmPasswordError != null ||
          (_mode == LoginPageMode.signUp && _error != null)) {
        setState(() {
          _signUpConfirmPasswordError = null;
          if (_mode == LoginPageMode.signUp) _error = null;
        });
      }
    });

    if (kIsWeb) {
      unawaited(_prepareGoogleWeb());
    }
  }

  void _setMode(LoginPageMode mode) {
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
      _error = null;
      _clearAllFieldErrors();

      if (mode == LoginPageMode.signUp &&
          _signUpEmailCtrl.text.trim().isEmpty) {
        _signUpEmailCtrl.text = _signInEmailCtrl.text.trim();
      }
      if (mode == LoginPageMode.signIn &&
          _signInEmailCtrl.text.trim().isEmpty) {
        _signInEmailCtrl.text = _signUpEmailCtrl.text.trim();
      }
    });
  }

  void _clearAllFieldErrors() {
    _signInEmailError = null;
    _signInPasswordError = null;
    _signUpEmailError = null;
    _signUpPasswordError = null;
    _signUpConfirmPasswordError = null;
  }

  void _setPageError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = _friendlyAuthMessage(error);
    });
  }

  String _validationMessage(LoginValidationCode code) {
    final l10n = AppLocalizations.of(context)!;

    switch (code) {
      case LoginValidationCode.emailRequired:
        return l10n.loginValidationEmailRequired;
      case LoginValidationCode.invalidEmail:
        return l10n.loginValidationInvalidEmail;
      case LoginValidationCode.passwordRequired:
        return l10n.loginValidationPasswordRequired;
      case LoginValidationCode.passwordTooShort:
        return l10n.loginValidationPasswordTooShort(
          minimumSignUpPasswordLength,
        );
      case LoginValidationCode.confirmPasswordRequired:
        return l10n.loginValidationConfirmPasswordRequired;
      case LoginValidationCode.passwordMismatch:
        return l10n.loginValidationPasswordMismatch;
    }
  }

  String _feedbackMessage(LoginFeedbackCode code) {
    final l10n = AppLocalizations.of(context)!;

    switch (code) {
      case LoginFeedbackCode.actionCancelled:
        return l10n.loginFeedbackActionCancelled;
      case LoginFeedbackCode.networkIssue:
        return l10n.loginFeedbackNetworkIssue;
      case LoginFeedbackCode.invalidCredentials:
        return l10n.loginFeedbackInvalidCredentials;
      case LoginFeedbackCode.emailAlreadyInUse:
        return l10n.loginFeedbackEmailAlreadyInUse;
      case LoginFeedbackCode.accountExistsDifferentCredential:
        return l10n.loginFeedbackAccountExistsDifferentMethod;
      case LoginFeedbackCode.tooManyAttempts:
        return l10n.loginFeedbackTooManyAttempts;
      case LoginFeedbackCode.googleConfiguration:
        return l10n.loginFeedbackGoogleConfiguration;
      case LoginFeedbackCode.generic:
        return l10n.loginFeedbackGeneric;
    }
  }

  String _friendlyAuthMessage(Object error) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    final looksTechnical =
        lower.contains('firebaseauthexception') ||
        lower.contains('exception:') ||
        lower.contains('type ') ||
        lower.contains('package:') ||
        lower.contains('stack') ||
        raw.length > 180;

    if (!looksTechnical && raw.isNotEmpty) {
      return raw;
    }

    return _feedbackMessage(classifyLoginFeedback(error));
  }

  Future<void> _openResetPasswordDialog() async {
    final pageL10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(
      text: _signInEmailCtrl.text.trim(),
    );
    LoginValidationCode? emailError;
    var submitting = false;

    Future<void> submitReset(
      StateSetter setLocalState,
      BuildContext dialogContext,
    ) async {
      if (submitting) return;
      final validation = validateLoginEmail(controller.text.trim());
      if (validation != null) {
        setLocalState(() => emailError = validation);
        return;
      }

      setLocalState(() {
        emailError = null;
        submitting = true;
      });

      try {
        await AuthService.instance.resetPassword(controller.text.trim());
        if (!mounted || !dialogContext.mounted) return;
        Navigator.of(dialogContext).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(pageL10n.loginResetPasswordEmailSent)),
        );
      } catch (e) {
        if (!mounted) return;
        setLocalState(() {
          submitting = false;
        });
        _setPageError(e);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.forgotPassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.loginResetPasswordDescription),
              const SizedBox(height: 14),
              _PremiumField(
                controller: controller,
                hintText: AppLocalizations.of(context)!.email,
                prefixIcon: Icons.mail_outline_rounded,
                borderColor: const Color(0x1A111827),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                enabled: !submitting,
                errorText: emailError == null
                    ? null
                    : _validationMessage(emailError!),
                onSubmitted: (_) => submitReset(setLocalState, dialogContext),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () => submitReset(setLocalState, dialogContext),
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(AppLocalizations.of(context)!.confirm),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  Widget _buildPrimaryCard(
    BuildContext context,
    Color border,
    Gradient gradient,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isSignIn = _mode == LoginPageMode.signIn;

    return _GlassCard(
      borderColor: border,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSignIn ? l10n.connection : l10n.createAccountWithEmail,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSignIn ? l10n.accessYourSpace : l10n.loginSignUpDescription,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _PremiumField(
              controller: isSignIn ? _signInEmailCtrl : _signUpEmailCtrl,
              hintText: l10n.email,
              prefixIcon: Icons.mail_outline_rounded,
              borderColor: border,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              enabled: !_isBusy,
              errorText: (() {
                final code = isSignIn ? _signInEmailError : _signUpEmailError;
                return code == null ? null : _validationMessage(code);
              })(),
            ),
            const SizedBox(height: 12),
            _PremiumField(
              controller: isSignIn ? _signInPasswordCtrl : _signUpPasswordCtrl,
              hintText: l10n.password,
              prefixIcon: Icons.lock_outline_rounded,
              borderColor: border,
              obscureText: isSignIn
                  ? _obscureSignInPassword
                  : _obscureSignUpPassword,
              autofillHints: [
                isSignIn ? AutofillHints.password : AutofillHints.newPassword,
              ],
              textInputAction: isSignIn
                  ? TextInputAction.done
                  : TextInputAction.next,
              enabled: !_isBusy,
              errorText: (() {
                final code = isSignIn
                    ? _signInPasswordError
                    : _signUpPasswordError;
                return code == null ? null : _validationMessage(code);
              })(),
              onSubmitted: isSignIn ? (_) => _submitPrimaryAction() : null,
              suffix: IconButton(
                onPressed: _isBusy
                    ? null
                    : () => setState(() {
                        if (isSignIn) {
                          _obscureSignInPassword = !_obscureSignInPassword;
                        } else {
                          _obscureSignUpPassword = !_obscureSignUpPassword;
                        }
                      }),
                icon: Icon(
                  (isSignIn ? _obscureSignInPassword : _obscureSignUpPassword)
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            if (!isSignIn) ...[
              const SizedBox(height: 12),
              _PremiumField(
                controller: _signUpConfirmPasswordCtrl,
                hintText: l10n.confirmPassword,
                prefixIcon: Icons.verified_user_outlined,
                borderColor: border,
                obscureText: _obscureSignUpConfirmPassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                enabled: !_isBusy,
                errorText: _signUpConfirmPasswordError == null
                    ? null
                    : _validationMessage(_signUpConfirmPasswordError!),
                onSubmitted: (_) => _submitPrimaryAction(),
                suffix: IconButton(
                  onPressed: _isBusy
                      ? null
                      : () => setState(() {
                          _obscureSignUpConfirmPassword =
                              !_obscureSignUpConfirmPassword;
                        }),
                  icon: Icon(
                    _obscureSignUpConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (isSignIn)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isBusy ? null : _openResetPasswordDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    l10n.forgotPassword,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            _GradientButton(
              gradient: gradient,
              text: _loading
                  ? (isSignIn ? l10n.signingIn : l10n.creating)
                  : (isSignIn ? l10n.signIn : l10n.createAccountWithEmail),
              onPressed: _isBusy ? () {} : _submitPrimaryAction,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    isSignIn ? l10n.dontHaveAccount : l10n.alreadyHaveAccount,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isBusy
                      ? null
                      : () => _setMode(
                          isSignIn
                              ? LoginPageMode.signUp
                              : LoginPageMode.signIn,
                        ),
                  child: Text(
                    isSignIn ? l10n.createAccount : l10n.signIn,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryCard(BuildContext context, Color border) {
    final l10n = AppLocalizations.of(context)!;

    return _GlassCard(
      borderColor: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.loginOtherOptionsTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.loginOtherOptionsDescription,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          if (kIsWeb)
            _GoogleWebButtonSlot(
              isReady: _googleWebReady,
              isLoading: _googleWebLoading,
              isBusy: _isBusy,
              onRetry: _prepareGoogleWeb,
            )
          else
            _SocialButton(
              label: l10n.continueWithGoogle,
              leading: const _GLogo(),
              onPressed: _isBusy
                  ? () {}
                  : () => _runProvider(AuthAction.google),
            ),
          if (_supportsAppleSignInUi) ...[
            const SizedBox(height: 10),
            _SocialButton(
              label: l10n.continueWithApple,
              leading: const Icon(
                Icons.apple,
                size: 22,
                color: Color(0xFF111827),
              ),
              onPressed: _isBusy ? () {} : () => _runProvider(AuthAction.apple),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isBusy
                  ? null
                  : () => Navigator.of(context).pushReplacementNamed('/'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0x1A111827)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                l10n.continueAsGuest,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.loginBusinessPrompt,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.loginBusinessDescription,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isBusy
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BusinessSignupPage(),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.loginBusinessCreateAccount,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bg = Color(0xFFFFFFFF);
    const text = Color(0xFF1A1A1A);
    const subText = Color(0xFF6B7280);
    const border = Color(0x1A111827);

    const masliveGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFE08A),
        Color(0xFFFFB067),
        Color(0xFFFF6FAE),
        Color(0xFF9B7BFF),
        Color(0xFF4FD8FF),
      ],
    );
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Header avec flèche retour vers la home
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: text,
                      tooltip: 'Retour à l\'accueil',
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MasliveGlowPainter(gradient: masliveGradient),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.06,
                child: CustomPaint(painter: _HexPatternPainter()),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      _mode == LoginPageMode.signIn
                          ? l10n.connection
                          : l10n.createAccount,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: text,
                            letterSpacing: 0.2,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _mode == LoginPageMode.signIn
                          ? l10n.accessYourSpace
                          : l10n.loginSignUpIntro,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: subText,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SegmentedButton<LoginPageMode>(
                              segments: [
                                ButtonSegment<LoginPageMode>(
                                  value: LoginPageMode.signIn,
                                  label: Text(l10n.signIn),
                                ),
                                ButtonSegment<LoginPageMode>(
                                  value: LoginPageMode.signUp,
                                  label: Text(l10n.createAccount),
                                ),
                              ],
                              selected: {_mode},
                              showSelectedIcon: false,
                              onSelectionChanged: _isBusy
                                  ? null
                                  : (selection) => _setMode(selection.first),
                            ),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 760;
                              final spacing = isWide ? 18.0 : 0.0;
                              final primaryWidth = isWide
                                  ? (constraints.maxWidth - spacing) * 0.55
                                  : constraints.maxWidth;
                              final secondaryWidth = isWide
                                  ? (constraints.maxWidth - spacing) * 0.45
                                  : constraints.maxWidth;

                              return Wrap(
                                alignment: WrapAlignment.center,
                                spacing: spacing,
                                runSpacing: 18,
                                children: [
                                  SizedBox(
                                    width: primaryWidth,
                                    child: _buildPrimaryCard(
                                      context,
                                      border,
                                      masliveGradient,
                                    ),
                                  ),
                                  SizedBox(
                                    width: secondaryWidth,
                                    child: _buildSecondaryCard(context, border),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _GlassCard({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.62 * 255).round()),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 18),
                color: Colors.black.withAlpha((0.10 * 255).round()),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final Color borderColor;
  final bool obscureText;
  final Widget? suffix;
  final String? errorText;
  final TextInputType keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const _PremiumField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.borderColor,
    this.obscureText = false,
    this.suffix,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: enabled ? 0.72 : 0.54),
            border: Border.all(
              color: hasError ? Colors.red : borderColor,
              width: hasError ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            enabled: enabled,
            enableSuggestions: !obscureText,
            autocorrect: false,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(prefixIcon, color: const Color(0xFF6B7280)),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Gradient gradient;

  const _GradientButton({
    required this.text,
    required this.onPressed,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 10),
              color: Colors.black.withAlpha((0.10 * 255).round()),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withAlpha((0.70 * 255).round()),
          foregroundColor: const Color(0xFF111827),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0x1A111827)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleWebButtonSlot extends StatelessWidget {
  const _GoogleWebButtonSlot({
    required this.isReady,
    required this.isLoading,
    required this.isBusy,
    required this.onRetry,
  });

  final bool isReady;
  final bool isLoading;
  final bool isBusy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.70 * 255).round()),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x1A111827)),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (!isReady) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            side: const BorderSide(color: Color(0x1A111827)),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: const Text(
            'Réessayer Google',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return IgnorePointer(
      ignoring: isBusy,
      child: Opacity(
        opacity: isBusy ? 0.64 : 1,
        child: SizedBox(
          width: double.infinity,
          child: Center(
            child: google_sign_in_web_button.buildGoogleSignInButton(),
          ),
        ),
      ),
    );
  }
}

class _GLogo extends StatelessWidget {
  const _GLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final strokeWidth = size.shortestSide * 0.18;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, _deg(205), _deg(105), false, arcPaint(_blue));
    canvas.drawArc(rect, _deg(310), _deg(78), false, arcPaint(_red));
    canvas.drawArc(rect, _deg(28), _deg(86), false, arcPaint(_yellow));
    canvas.drawArc(rect, _deg(116), _deg(88), false, arcPaint(_green));

    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + strokeWidth * 0.25,
        center.dy - strokeWidth * 1.05,
        size.width - (center.dx + strokeWidth * 0.25),
        strokeWidth * 2.1,
      ),
      Paint()..color = Colors.white,
    );

    canvas.drawLine(
      Offset(center.dx - strokeWidth * 0.10, center.dy),
      Offset(size.width - strokeWidth * 0.15, center.dy),
      Paint()
        ..color = _blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );
  }

  double _deg(double degrees) => degrees * math.pi / 180.0;

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

class _MasliveGlowPainter extends CustomPainter {
  final Gradient gradient;
  _MasliveGlowPainter({required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);

    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.18),
      size.width * 0.55,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.45, size.height * 0.78),
      size.width * 0.60,
      paint,
    );

    final veil = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawRect(Offset.zero & size, veil);
  }

  @override
  bool shouldRepaint(covariant _MasliveGlowPainter oldDelegate) => false;
}

class _HexPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const step = 34.0;
    final r = step / 2;

    for (double y = -step; y < size.height + step; y += step * 0.86) {
      final odd = ((y / (step * 0.86)).round() % 2) == 1;
      for (double x = -step; x < size.width + step; x += step) {
        final cx = x + (odd ? r : 0);
        final cy = y;
        _drawHex(canvas, Offset(cx, cy), r, p);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset c, double r, Paint p) {
    p.color = const Color(0xFF111827).withValues(alpha: 0.35);

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60.0 * i - 30.0) * math.pi / 180.0;
      final pt = Offset(
        c.dx + r * 0.95 * math.cos(angle),
        c.dy + r * 0.95 * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
