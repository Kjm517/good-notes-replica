import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../widgets/admin_widgets.dart';

class AdminTeamPage extends ConsumerStatefulWidget {
  const AdminTeamPage({super.key});

  @override
  ConsumerState<AdminTeamPage> createState() => _AdminTeamPageState();
}

class _AdminTeamPageState extends ConsumerState<AdminTeamPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  var _busy = false;
  var _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await api.createAdminAccount(
        email: email,
        password: password,
        name: _name.text,
      );
      _email.clear();
      _password.clear();
      _name.clear();
      ref.invalidate(adminTeamProvider);
      ref.invalidate(adminAuditProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin account created in Supabase. They can sign in now.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(AdminTeamMember member) async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.email ?? member.uid}?'),
        content: const Text(
          'They lose admin console access. Their Supabase login still exists.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.removeTeamMember(member.uid);
      ref.invalidate(adminTeamProvider);
      ref.invalidate(adminAuditProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final teamAsync = ref.watch(adminTeamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminPageHeader(
            title: 'Team',
            subtitle:
                'Staff in the Supabase public.admins table. Create an account '
                'here to add Auth + admin access in one step.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create admin account', style: AppTokens.sectionLabel(t.textFaint)),
                const SizedBox(height: 10),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Display name (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create admin in Supabase'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          teamAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminTeamProvider),
            ),
            data: (members) => AdminDataTable(
              columns: const ['Member', 'Role', 'Added', ''],
              // Member holds an email address and a uid; Role is one short
              // word and Added is a date, so an even split spends the width
              // where there is nothing to show and starves the one column
              // that has something to say.
              flex: const [5, 2, 2],
              emptyMessage: 'No team members configured.',
              rows: [
                for (final m in members)
                  [
                    // Tooltipped because both lines are abbreviated: the uid
                    // always, the email whenever the column is too narrow for
                    // it. Truncation with no way to read the full value makes
                    // a member list you cannot actually check against Supabase.
                    Tooltip(
                      message: [
                        if (m.email != null) m.email!,
                        m.uid,
                      ].join('\n'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.email ?? shortUid(m.uid),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shortUid(m.uid),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTokens.mono(size: 10, color: t.textFaint),
                          ),
                        ],
                      ),
                    ),
                    AdminStatusChip(
                      label: m.role,
                      color: m.role == 'admin' ? t.accentText : t.textMuted,
                    ),
                    Text(
                      m.addedAt.length >= 10 ? m.addedAt.substring(0, 10) : m.addedAt,
                      style: AppTokens.mono(size: 11, color: t.textMuted),
                    ),
                    IconButton(
                      tooltip: 'Remove ${m.email ?? shortUid(m.uid)}',
                      icon: Icon(Icons.person_remove_outlined, color: t.pdfBadge),
                      onPressed: () => _remove(m),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
