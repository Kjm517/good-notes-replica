import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../widgets/admin_widgets.dart';

enum _UserType { free, monthly, yearly }

_UserType _typeFromUser(AdminUserRow u) {
  if (!u.isPremium) return _UserType.free;
  if (u.plan == 'yearly') return _UserType.yearly;
  return _UserType.monthly;
}

String _typeLabel(_UserType type) => switch (type) {
      _UserType.free => 'Free',
      _UserType.monthly => 'Monthly',
      _UserType.yearly => 'Yearly',
    };

String _formatDay(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _search = TextEditingController();
  var _query = '';
  final _busyUids = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _invalidateUserLists() {
    ref.invalidate(adminUsersProvider(_query));
    ref.invalidate(adminUsersProvider(''));
    ref.invalidate(adminSubscriptionsProvider);
    ref.invalidate(adminOverviewProvider(30));
    ref.invalidate(adminBadgeCountsProvider);
  }

  Future<void> _setType(AdminUserRow user, _UserType type) async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    if (_typeFromUser(user) == type) return;

    setState(() => _busyUids.add(user.uid));
    try {
      await api.updateSubscription(
        user.uid,
        isPremium: type != _UserType.free,
        plan: type == _UserType.free
            ? null
            : (type == _UserType.yearly ? 'yearly' : 'monthly'),
      );
      _invalidateUserLists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Set ${user.email ?? shortUid(user.uid)} → ${_typeLabel(type)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busyUids.remove(user.uid));
    }
  }

  Future<void> _openEditor(AdminUserRow user) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _UserEditorSheet(user: user),
    );
    if (changed == true) _invalidateUserLists();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final usersAsync = ref.watch(adminUsersProvider(_query));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminPageHeader(
            title: 'Users',
            subtitle:
                'Edit a user for name, membership, and expiry — or tap the type chip for a quick plan change.',
          ),
          const SizedBox(height: 16),
          AdminSearchField(
            controller: _search,
            hint: 'Search email, name, or UID',
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 16),
          usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminUsersProvider(_query)),
            ),
            data: (users) => AdminDataTable(
              columns: const ['Account', 'Storage', 'User type', 'Last seen', ''],
              flex: const [5, 2, 2, 2],
              emptyMessage:
                  'No users yet — open the app signed in to register a heartbeat.',
              rows: [
                for (final u in users)
                  [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.email ?? u.displayName ?? shortUid(u.uid),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t.text,
                          ),
                        ),
                        if (u.displayName != null &&
                            u.displayName!.isNotEmpty &&
                            u.email != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            u.displayName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: t.textMuted),
                          ),
                        ],
                        Text(
                          shortUid(u.uid),
                          style: AppTokens.mono(size: 10, color: t.textFaint),
                        ),
                      ],
                    ),
                    Text(
                      formatStorageBytes(u.storageBytes),
                      style: TextStyle(color: t.textSecondary),
                    ),
                    _busyUids.contains(u.uid)
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _UserTypeMenu(
                            current: _typeFromUser(u),
                            onSelected: (type) => _setType(u, type),
                          ),
                    Text(
                      u.lastSeenAt != null && u.lastSeenAt!.isNotEmpty
                          ? u.lastSeenAt!.substring(0, 10)
                          : '—',
                      style: AppTokens.mono(size: 11, color: t.textMuted),
                    ),
                    IconButton(
                      tooltip: 'Edit user',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openEditor(u),
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

class _UserTypeMenu extends StatelessWidget {
  const _UserTypeMenu({
    required this.current,
    required this.onSelected,
  });

  final _UserType current;
  final ValueChanged<_UserType> onSelected;

  Color _color(AppTokens t) => switch (current) {
        _UserType.free => t.textMuted,
        _UserType.monthly => t.success,
        _UserType.yearly => t.accentText,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopupMenuButton<_UserType>(
      tooltip: 'Change user type',
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final type in _UserType.values)
          PopupMenuItem(
            value: type,
            child: Row(
              children: [
                Icon(
                  type == current ? Icons.check_rounded : Icons.circle_outlined,
                  size: 16,
                  color: type == current ? t.accentText : t.textFaint,
                ),
                const SizedBox(width: 10),
                Text(_typeLabel(type)),
              ],
            ),
          ),
      ],
      child: AdminStatusChip(
        label: _typeLabel(current),
        color: _color(t),
      ),
    );
  }
}

class _UserEditorSheet extends ConsumerStatefulWidget {
  const _UserEditorSheet({required this.user});

  final AdminUserRow user;

  @override
  ConsumerState<_UserEditorSheet> createState() => _UserEditorSheetState();
}

class _UserEditorSheetState extends ConsumerState<_UserEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late _UserType _type;
  DateTime? _expiresAt;
  var _saving = false;
  var _deleting = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u.displayName ?? '');
    _email = TextEditingController(text: u.email ?? '');
    _type = _typeFromUser(u);
    if (u.premiumExpiresAt != null) {
      _expiresAt = DateTime.tryParse(u.premiumExpiresAt!)?.toLocal();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    if (_type != _UserType.free && _expiresAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a membership expiry date.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final expiryIso = _type == _UserType.free || _expiresAt == null
          ? null
          : DateTime(
              _expiresAt!.year,
              _expiresAt!.month,
              _expiresAt!.day,
              23,
              59,
              59,
            ).toUtc().toIso8601String();
      await api.updateUser(
        widget.user.uid,
        email: _email.text.trim(),
        displayName: _name.text.trim(),
        isPremium: _type != _UserType.free,
        plan: _type == _UserType.free
            ? null
            : (_type == _UserType.yearly ? 'yearly' : 'monthly'),
        expiresAt: expiryIso,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    final label = widget.user.email ?? shortUid(widget.user.uid);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label?'),
        content: const Text(
          'Removes their files from R2 and drops them from this list. '
          'If SUPABASE_SERVICE_ROLE_KEY is set on the worker, their Auth login '
          'is deleted too. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await api.deleteUser(widget.user.uid);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final busy = _saving || _deleting;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit user',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.text),
            ),
            const SizedBox(height: 4),
            Text(
              shortUid(widget.user.uid),
              style: AppTokens.mono(size: 11, color: t.textFaint),
            ),
            const SizedBox(height: 16),
            Text('Display name', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              enabled: !busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Optional name'),
            ),
            const SizedBox(height: 14),
            Text('Email (admin label)', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 6),
            TextField(
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Shown in admin lists',
                helperText: 'Does not change their Supabase login email.',
              ),
            ),
            const SizedBox(height: 14),
            Text('Membership', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 8),
            SegmentedButton<_UserType>(
              segments: [
                for (final type in _UserType.values)
                  ButtonSegment(value: type, label: Text(_typeLabel(type))),
              ],
              selected: {_type},
              onSelectionChanged: busy
                  ? null
                  : (s) => setState(() {
                        _type = s.first;
                        if (_type != _UserType.free && _expiresAt == null) {
                          _expiresAt = DateTime.now().add(
                            Duration(days: _type == _UserType.yearly ? 365 : 30),
                          );
                        }
                      }),
            ),
            if (_type != _UserType.free) ...[
              const SizedBox(height: 14),
              Text('Expires', style: AppTokens.sectionLabel(t.textFaint)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: busy ? null : _pickExpiry,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  _expiresAt == null
                      ? 'Pick expiry date'
                      : 'Expires ${_formatDay(_expiresAt!)}',
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: t.pdfBadge),
              child: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete user'),
            ),
          ],
        ),
      ),
    );
  }
}
