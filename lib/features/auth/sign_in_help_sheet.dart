import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design.dart';
import '../legal/legal_copy.dart';

/// Help for someone who cannot get past the sign-in screen.
///
/// The in-app bug reporter cannot serve these people: it reads the signed-in
/// user to stamp the report, and the Worker route it posts to requires a
/// token. Anyone locked out has neither. So this is deliberately self-serve
/// first — the fixes below cover the failures that actually happen — with a
/// plain email address as the way out when none of them work.
class SignInHelpSheet extends StatelessWidget {
  const SignInHelpSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const SignInHelpSheet(),
    );
  }

  /// Opens the user's mail app with as much already filled in as we can.
  ///
  /// The platform line matters: nearly every sign-in report comes down to the
  /// device or the network, and asking for it afterwards costs a round trip
  /// with someone who is already frustrated.
  Future<void> _email(BuildContext context) async {
    final platform = kIsWeb
        ? 'Web'
        : defaultTargetPlatform.name[0].toUpperCase() +
            defaultTargetPlatform.name.substring(1);
    final uri = Uri(
      scheme: 'mailto',
      path: kLegalContactEmail,
      queryParameters: {
        'subject': 'Navie — trouble signing in',
        'body': '\n\n---\nPlatform: $platform\n'
            'Please describe what happens when you try to sign in, and the '
            'exact message you see.',
      },
    );
    final messenger = ScaffoldMessenger.of(context);
    // A device with no mail app configured opens nothing at all, which looks
    // like the button is broken. Fall back to handing over the address.
    if (!await launchUrl(uri)) {
      await Clipboard.setData(const ClipboardData(text: kLegalContactEmail));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Email address copied: $kLegalContactEmail'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trouble signing in?',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 4),
              Text(
                'Most sign-in problems are one of these.',
                style: TextStyle(fontSize: 13.5, color: t.textMuted),
              ),
              const SizedBox(height: 18),
              const _Tip(
                icon: Icons.wifi_off_rounded,
                title: '“Network error. Check your connection.”',
                body: 'Your connection reached us but could not look up the '
                    'server. Try mobile data instead of Wi-Fi — if that works, '
                    'the Wi-Fi network’s DNS is the problem. Setting the '
                    'device’s DNS to 1.1.1.1 fixes it.',
              ),
              const _Tip(
                icon: Icons.password_rounded,
                title: '“Wrong email or password.”',
                body: 'Use “Forgot password?” above to set a new one. If you '
                    'first joined with Google, use “Continue with Google” — '
                    'that account has no password.',
              ),
              const _Tip(
                icon: Icons.mark_email_unread_outlined,
                title: 'No confirmation email',
                body: 'Check spam. The message can take a few minutes. Make '
                    'sure the address has no typo — a wrong address is the '
                    'usual cause.',
              ),
              const _Tip(
                icon: Icons.person_search_rounded,
                title: 'Google sign-in does nothing',
                body: 'A blocked pop-up is the usual cause on the web. Allow '
                    'pop-ups for this site, or sign in with an email address '
                    'and password instead.',
              ),
              const SizedBox(height: 8),
              Text(
                'Still stuck?',
                style: AppTokens.sectionLabel(t.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us what happens and the exact message you see, and we '
                'will get you in.',
                style: TextStyle(fontSize: 13.5, color: t.textSecondary),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _email(context),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Email support'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  kLegalContactEmail,
                  style: AppTokens.mono(size: 12, color: t.textFaint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: t.fill,
              borderRadius: BorderRadius.circular(Radii.inner),
            ),
            child: Icon(icon, size: 18, color: t.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
