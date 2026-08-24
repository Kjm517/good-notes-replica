import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/supabase_bootstrap.dart';
import 'admin_access.dart';
import 'admin_auth_providers.dart';
import 'admin_console_shell.dart';
import 'admin_section.dart';
import 'admin_sign_in_page.dart';
import 'admin_supabase.dart';

class AdminConsoleGate extends ConsumerWidget {
  const AdminConsoleGate({
    super.key,
    required this.section,
  });

  final AdminSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!supabaseReady || !adminSupabaseReady) {
      return const Scaffold(
        body: Center(child: Text('Admin console requires Supabase sign-in.')),
      );
    }

    final user = ref.watch(adminAuthStateProvider).asData?.value;
    if (user == null) {
      return AdminSignInPage(returnPath: section.location);
    }

    final remote = ref.watch(adminAccessStateProvider);
    if (remote.isLoading && !ref.watch(isAdminProvider)) {
      final t = context.tokens;
      return Scaffold(
        backgroundColor: t.canvas,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!ref.watch(isAdminProvider)) {
      final t = context.tokens;
      return Scaffold(
        backgroundColor: t.canvas,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 48, color: t.pdfBadge),
                  const SizedBox(height: 16),
                  Text(
                    'Staff access only',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Signed in as ${user.email ?? user.uid}, but this account '
                    'is not on the admin team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.textMuted, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    'uid: ${user.uid}',
                    textAlign: TextAlign.center,
                    style: AppTokens.mono(size: 11, color: t.textFaint),
                  ),
                  if (remote.asData?.value.error != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      remote.asData!.value.error!,
                      textAlign: TextAlign.center,
                      style: AppTokens.mono(size: 11, color: t.pdfBadge),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Staff sign-in is separate from the Notably app account. '
                    'Add this uid to public.admins in Supabase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: t.textFaint, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.invalidate(adminAccessStateProvider),
                    child: const Text('Recheck access'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(adminAuthRepositoryProvider)?.signOut();
                    },
                    child: const Text('Use a different staff account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AdminConsoleShell(section: section);
  }
}
