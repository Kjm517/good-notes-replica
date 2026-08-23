import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design.dart';
import '../auth/data/auth_repository.dart';
import 'admin_auth_providers.dart';

/// Split-screen staff sign-in from design §13.
class AdminSignInPage extends ConsumerStatefulWidget {
  const AdminSignInPage({super.key, required this.returnPath});

  final String returnPath;

  @override
  ConsumerState<AdminSignInPage> createState() => _AdminSignInPageState();
}

class _AdminSignInPageState extends ConsumerState<AdminSignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;
  var _busy = false;
  var _keepSignedIn = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(adminAuthRepositoryProvider);
    if (auth == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.applyPersistence(keepSignedIn: _keepSignedIn);
      await auth.signInWithEmail(_email.text.trim(), _password.text);
      if (!mounted) return;
      context.go(widget.returnPath);
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final stacked = width < 880;

    final hero = _AdminHeroPanel(stacked: stacked);
    final form = _AdminSignInForm(
      email: _email,
      password: _password,
      obscure: _obscure,
      busy: _busy,
      error: _error,
      keepSignedIn: _keepSignedIn,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onKeepSignedIn: (v) => setState(() => _keepSignedIn = v),
      onSubmit: _submit,
    );

    return Scaffold(
      backgroundColor: t.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: stacked
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      hero,
                      form,
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.card),
                  child: SizedBox(
                    height: 580,
                    child: Row(
                      children: [
                        SizedBox(width: 330, child: hero),
                        Expanded(child: form),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _AdminHeroPanel extends StatelessWidget {
  const _AdminHeroPanel({required this.stacked});

  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: stacked ? double.infinity : 330,
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5257D4), Color(0xFF3D41A8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.draw_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 11),
              const Text(
                'Notably',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'ADMIN',
                  style: AppTokens.mono(
                    size: 9.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: stacked ? 28 : 120),
          const Text(
            'Operations console',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Accounts, subscriptions, AI spend and incoming bug reports — in one place.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 26),
          _heroRow(Icons.shield_outlined, 'Staff accounts only'),
          const SizedBox(height: 11),
          _heroRow(Icons.history_rounded, 'Every action is logged'),
        ],
      ),
    );
  }

  Widget _heroRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.6)),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _AdminSignInForm extends StatelessWidget {
  const _AdminSignInForm({
    required this.email,
    required this.password,
    required this.obscure,
    required this.busy,
    required this.error,
    required this.keepSignedIn,
    required this.onToggleObscure,
    required this.onKeepSignedIn,
    required this.onSubmit,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool busy;
  final String? error;
  final bool keepSignedIn;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onKeepSignedIn;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ColoredBox(
      color: t.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Use your staff account — separate from the Notably app login.',
              style: TextStyle(fontSize: 13.5, color: t.textMuted),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: t.pdfBadge.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: t.pdfBadge.withValues(alpha: 0.28)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: t.pdfBadge, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(error!, style: TextStyle(color: t.text, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            _field(
              t,
              icon: Icons.mail_outline_rounded,
              controller: email,
              hint: 'you@notably.app',
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 11),
            _field(
              t,
              icon: Icons.lock_outline_rounded,
              controller: password,
              hint: 'Password',
              obscure: obscure,
              suffix: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: t.textFaint,
                ),
                onPressed: onToggleObscure,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                InkWell(
                  onTap: () => onKeepSignedIn(!keepSignedIn),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          color: keepSignedIn ? t.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: keepSignedIn ? t.accent : t.lineStrong,
                          ),
                        ),
                        child: keepSignedIn
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 9),
                      Text('Keep me signed in', style: TextStyle(fontSize: 13, color: t.textSecondary)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Forgot password?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.accentText),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: t.textFaint),
                const SizedBox(width: 9),
                Text(
                  'Protected by Supabase authentication',
                  style: TextStyle(fontSize: 12, color: t.textFaint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    AppTokens t, {
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.lineStrong),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: t.textMuted),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboard,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }
}
