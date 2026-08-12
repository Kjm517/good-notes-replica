import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/firebase_bootstrap.dart';
import 'data/auth_repository.dart';
import 'providers.dart';

/// Sign in / sign up. Signing in is optional — it enables syncing your notes
/// across devices; everything works locally without it.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _creatingAccount = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  AuthRepository? get _auth => ref.read(authRepositoryProvider);

  Future<void> _run(Future<void> Function(AuthRepository auth) action) async {
    final auth = _auth;
    if (auth == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(auth);
      if (mounted) Navigator.of(context).maybePop();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    await _run((auth) => _creatingAccount
        ? auth.signUpWithEmail(_email.text, _password.text)
        : auth.signInWithEmail(_email.text, _password.text));
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first, then tap Reset.');
      return;
    }
    await _run((auth) async {
      await auth.sendPasswordReset(_email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final configured = firebaseReady;

    return Scaffold(
      backgroundColor: t.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Hero(creatingAccount: _creatingAccount),
                  const SizedBox(height: 28),
                  if (!configured)
                    _NotConfiguredCard()
                  else ...[
                    _GoogleButton(
                      label: _creatingAccount
                          ? 'Sign up with Google'
                          : 'Continue with Google',
                      onPressed: _busy
                          ? null
                          : () => _run((auth) => auth.signInWithGoogle()),
                    ),
                    const _OrDivider(),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              hintText: 'Email address',
                              prefixIcon: Icon(Icons.mail_outline_rounded,
                                  size: 20),
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 11),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded,
                                      size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'At least 6 characters'
                                : null,
                            onFieldSubmitted: (_) => _submitEmail(),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ? null : _submitEmail,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_creatingAccount
                                ? 'Create account'
                                : 'Continue'),
                      ),
                    ),
                    if (!_creatingAccount) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('Forgot your password?'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _FooterSwitch(
                      creatingAccount: _creatingAccount,
                      onTap: _busy
                          ? null
                          : () => setState(() {
                                _creatingAccount = !_creatingAccount;
                                _error = null;
                              }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App mark, headline and one line of promise — the top of the design's
/// onboarding screens.
class _Hero extends StatelessWidget {
  const _Hero({required this.creatingAccount});
  final bool creatingAccount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: t.accent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: t.accent.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 14),
                spreadRadius: -10,
              ),
            ],
          ),
          child: const Icon(Icons.draw_rounded, size: 34, color: Colors.white),
        ),
        const SizedBox(height: 22),
        Text(
          creatingAccount ? 'Create your account' : 'Welcome to Notably',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: t.text,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            creatingAccount
                ? 'Your notebooks, PDFs and highlights, on every device.'
                : 'Read, mark up and think — the same notes on every device.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: t.textMuted),
          ),
        ),
      ],
    );
  }
}

/// White pill with the Google wordmark colour, as in the design.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 52,
      child: Material(
        color: dark ? Colors.white : t.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dark ? Colors.transparent : t.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google's own mark can't be redrawn faithfully in an icon
                // font, so this is a plain letterform in their blue.
                Text('G',
                    style: AppTokens.mono(
                      size: 19,
                      weight: FontWeight.w700,
                      color: const Color(0xFF4285F4),
                    )),
                const SizedBox(width: 12),
                Text(label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1E26),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: t.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or',
                style: TextStyle(fontSize: 12, color: t.textMuted)),
          ),
          Expanded(child: Container(height: 1, color: t.line)),
        ],
      ),
    );
  }
}

class _FooterSwitch extends StatelessWidget {
  const _FooterSwitch({required this.creatingAccount, required this.onTap});

  final bool creatingAccount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: creatingAccount
                  ? 'Already have an account? '
                  : 'New here? ',
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
            TextSpan(
              text: creatingAccount ? 'Sign in' : 'Create account',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.accentText,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// Shown when Firebase hasn't been wired up — the app is still fully usable,
/// so this explains rather than blocks.
class _NotConfiguredCard extends StatelessWidget {
  const _NotConfiguredCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 19, color: t.textMuted),
              const SizedBox(width: 9),
              Text('Sync not set up yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            firebaseError ??
                'Firebase has not been configured for this app yet.',
            style: TextStyle(fontSize: 13, height: 1.5, color: t.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Your notes are safe on this device. Run `flutterfire configure` '
            'to connect a Firebase project and accounts will become '
            'available.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}
