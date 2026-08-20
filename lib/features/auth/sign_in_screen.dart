import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/firebase_bootstrap.dart';
import '../../app/page_routes.dart';
import 'data/auth_repository.dart';
import 'providers.dart';

/// Sign in or create an account. When Firebase is configured, signing in is
/// required to enter the app — it also enables syncing your notes across
/// devices. Without Firebase the app runs local-only and skips this gate
/// entirely, so sign-in here is only a path to cross-device sync.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _creatingAccount = false;
  bool _busy = false;
  bool _obscure = true;
  bool _acceptedTerms = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
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
      // Has to precede the sign-in call to govern the session it creates.
      await auth.applyPersistence(
        keepSignedIn: ref.read(keepSignedInProvider),
      );
      await action(auth);
      // On success the router's auth gate observes the resulting sign-in
      // state and redirects to the home route — no manual navigation needed.
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
    // Terms are only required when creating an account; the button is disabled
    // until then, but guard here too in case of an Enter-key submit.
    if (_creatingAccount && !_acceptedTerms) {
      setState(() => _error = 'Please accept the Terms and Privacy Policy.');
      return;
    }
    await _run((auth) => _creatingAccount
        ? auth.signUpWithEmail(
            _email.text,
            _password.text,
            displayName: _name.text,
          )
        : auth.signInWithEmail(_email.text, _password.text));
  }

  /// Asks which address to send the reset link to, prefilled with whatever is
  /// already typed, so a forgotten password never depends on having filled the
  /// form in the right order first.
  Future<void> _resetPassword() async {
    final email = await _ResetPasswordDialog.show(context, initial: _email.text);
    if (email == null || !mounted) return;

    await _run((auth) async {
      await auth.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset link sent to $email.')),
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
                  // As the launch gate this is the root route, so the back
                  // arrow is a dead control — hide it. Reserve its slot
                  // either way so the hero below doesn't shift.
                  if (Navigator.of(context).canPop())
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(notablyBackIcon),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
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
                          if (_creatingAccount) ...[
                            TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                hintText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline_rounded,
                                    size: 20),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Enter your name'
                                      : null,
                            ),
                            const SizedBox(height: 11),
                          ],
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
                    _SessionRow(
                      keepSignedIn: ref.watch(keepSignedInProvider),
                      onKeepSignedIn: _busy
                          ? null
                          : (v) => ref
                              .read(keepSignedInProvider.notifier)
                              .set(v),
                      onForgotPassword:
                          _creatingAccount || _busy ? null : _resetPassword,
                    ),
                    if (_creatingAccount)
                      _TermsRow(
                        accepted: _acceptedTerms,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                  _acceptedTerms = v;
                                  if (v) _error = null;
                                }),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ||
                                (_creatingAccount && !_acceptedTerms)
                            ? null
                            : _submitEmail,
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
                    const SizedBox(height: 14),
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
        const AppMark(),
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

/// "Keep me signed in" beside the password-reset link — the two session
/// controls that belong with the password field rather than below the button.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.keepSignedIn,
    required this.onKeepSignedIn,
    required this.onForgotPassword,
  });

  final bool keepSignedIn;
  final ValueChanged<bool>? onKeepSignedIn;

  /// Null while creating an account, where there is no password to recover.
  final VoidCallback? onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onKeepSignedIn != null;
    return Row(
      children: [
        // The label is part of the target: a bare checkbox is a small hit area.
        InkWell(
          onTap: enabled ? () => onKeepSignedIn!(!keepSignedIn) : null,
          borderRadius: BorderRadius.circular(Radii.inner),
          child: Padding(
            padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: keepSignedIn,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged:
                        enabled ? (v) => onKeepSignedIn!(v ?? false) : null,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'Keep me signed in',
                  style: TextStyle(fontSize: 13, color: t.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (onForgotPassword != null)
          TextButton(
            onPressed: onForgotPassword,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot password?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.accentText,
              ),
            ),
          ),
      ],
    );
  }
}

/// "I agree to the Terms and Privacy Policy" — gates the Create account
/// button, shown only while signing up.
class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: enabled ? () => onChanged!(!accepted) : null,
        borderRadius: BorderRadius.circular(Radii.inner),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: accepted,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: enabled ? (v) => onChanged!(v ?? false) : null,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 12.5, height: 1.45, color: t.textMuted),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms the address a reset link should go to.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initial});
  final String initial;

  /// Resolves to the address to send to, or null if dismissed.
  static Future<String?> show(BuildContext context, {required String initial}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(initial: initial),
    );
  }

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final _field = TextEditingController(text: widget.initial.trim());
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _send() {
    final email = _field.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      title: const Text('Reset your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We\'ll email you a link to choose a new password.',
            style: TextStyle(fontSize: 13, height: 1.5, color: t.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              hintText: 'Email address',
              errorText: _error,
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _send(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _send, child: const Text('Send link')),
      ],
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
