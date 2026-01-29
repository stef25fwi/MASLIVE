import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../session/session_scope.dart';
import 'auth/auth_action_runner.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';
import 'business_signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _emailError = false;
  bool _passwordError = false;

  Future<void> _run(Future<void> Function() fn) async {
    // Validation
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    setState(() {
      _emailError = email.isEmpty;
      _passwordError = password.isEmpty;
    });

    if (_emailError || _passwordError) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await fn();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/account-ui');
    } catch (e) {
      setState(() => _error = e.toString());
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
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AuthActionRunner(action: action)),
      );

      if (!mounted) return;

      final session = SessionScope.of(context);
      if (session.isSignedIn) {
        Navigator.of(context).pushReplacementNamed('/account-ui');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Réinitialiser les erreurs quand l'utilisateur tape
    _emailCtrl.addListener(() {
      if (_emailError && _emailCtrl.text.trim().isNotEmpty) {
        setState(() => _emailError = false);
      }
    });
    _passCtrl.addListener(() {
      if (_passwordError && _passCtrl.text.isNotEmpty) {
        setState(() => _passwordError = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      AppLocalizations.of(context)!.connection,
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
                      AppLocalizations.of(context)!.accessYourSpace,
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 700;
                        final sectionWidth = isWide
                            ? (constraints.maxWidth - 14) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: sectionWidth,
                              child: _GlassCard(
                                borderColor: border,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 6),
                                    _PremiumField(
                                      controller: _emailCtrl,
                                      hintText: AppLocalizations.of(
                                        context,
                                      )!.email,
                                      prefixIcon: Icons.mail_outline_rounded,
                                      borderColor: border,
                                      hasError: _emailError,
                                    ),
                                    const SizedBox(height: 12),
                                    _PremiumField(
                                      controller: _passCtrl,
                                      hintText: AppLocalizations.of(
                                        context,
                                      )!.password,
                                      prefixIcon: Icons.lock_outline_rounded,
                                      borderColor: border,
                                      obscureText: _obscure,
                                      hasError: _passwordError,
                                      suffix: IconButton(
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _GradientButton(
                                      gradient: masliveGradient,
                                      text: _loading
                                          ? AppLocalizations.of(
                                              context,
                                            )!.signingIn
                                          : AppLocalizations.of(
                                              context,
                                            )!.signIn,
                                      onPressed: _loading
                                          ? () {}
                                          : () => _run(
                                              () => AuthService.instance
                                                  .signInWithEmailPassword(
                                                    email: _emailCtrl.text
                                                        .trim(),
                                                    password: _passCtrl.text,
                                                  ),
                                            ),
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => Navigator.of(
                                          context,
                                        ).pushReplacementNamed('/'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: subText,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.continueAsGuest,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: sectionWidth,
                              child: _GlassCard(
                                borderColor: border,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 6),
                                    _GradientButton(
                                      gradient: masliveGradient,
                                      text: _loading
                                          ? AppLocalizations.of(
                                              context,
                                            )!.creating
                                          : AppLocalizations.of(
                                              context,
                                            )!.createAccountWithEmail,
                                      onPressed: _loading
                                          ? () {}
                                          : () => _run(
                                              () => AuthService.instance
                                                  .createUserWithEmailPassword(
                                                    email: _emailCtrl.text
                                                        .trim(),
                                                    password: _passCtrl.text,
                                                  ),
                                            ),
                                    ),
                                    const SizedBox(height: 12),
                                    _SocialButton(
                                      label: AppLocalizations.of(
                                        context,
                                      )!.continueWithGoogle,
                                      leading: const _GLogo(),
                                      onPressed: _loading
                                          ? () {}
                                          : () =>
                                                _runProvider(AuthAction.google),
                                    ),
                                    const SizedBox(height: 10),
                                    _SocialButton(
                                      label: AppLocalizations.of(
                                        context,
                                      )!.continueWithApple,
                                      leading: const Icon(
                                        Icons.apple,
                                        size: 22,
                                        color: Color(0xFF111827),
                                      ),
                                      onPressed: _loading
                                          ? () {}
                                          : () =>
                                                _runProvider(AuthAction.apple),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Bouton Compte Professionnel
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6FAE), Color(0xFF9B7BFF)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9B7BFF).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vous êtes un professionnel ?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Créez votre compte entreprise',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BusinessSignupPage(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF9B7BFF),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Créer un compte professionnel',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
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
  final bool hasError;

  const _PremiumField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.borderColor,
    this.obscureText = false,
    this.suffix,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.72),
        border: Border.all(
          color: hasError ? Colors.red : borderColor,
          width: hasError ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: hintText.toLowerCase().contains("email")
            ? TextInputType.emailAddress
            : TextInputType.text,
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _GLogo extends StatelessWidget {
  const _GLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        "G",
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }
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
