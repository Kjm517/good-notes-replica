import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_access.dart';
import '../admin_api.dart';
import '../admin_dates.dart';
import '../csv_export.dart';
import '../widgets/admin_widgets.dart';

class AdminAuditPage extends ConsumerStatefulWidget {
  const AdminAuditPage({super.key});

  @override
  ConsumerState<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends ConsumerState<AdminAuditPage> {
  var _clearing = false;

  Future<void> _clear() async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear audit log?'),
        content: const Text(
          'Removes every recorded action from this list. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Clear log'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      final cleared = await api.clearAudit();
      ref.invalidate(adminAuditProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cleared == 1
                  ? 'Cleared 1 recorded action.'
                  : 'Cleared $cleared recorded actions.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final auditAsync = ref.watch(adminAuditProvider);
    final entries = auditAsync.asData?.value ?? const <AdminAuditEntry>[];
    final canWrite = ref.watch(adminCanWriteProvider);
    final canClear = !_clearing && entries.isNotEmpty && canWrite;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          auditAsync.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const AdminPageHeader(title: 'Audit log', subtitle: 'Loading…'),
            error: (_, __) => const AdminPageHeader(title: 'Audit log'),
            data: (items) => AdminPageHeader(
              title: 'Audit log',
              subtitle: '${items.length} recorded actions',
              trailing: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: items.isEmpty
                        ? null
                        : () => exportCsv(
                              filename: 'notably-audit.csv',
                              headers: const [
                                'when',
                                'action',
                                'actor',
                                'target',
                                'detail',
                              ],
                              rows: [
                                for (final e in items)
                                  [
                                    e.createdAt,
                                    e.action,
                                    e.actorEmail ?? e.actorUid,
                                    e.target ?? '',
                                    e.detail ?? '',
                                  ],
                              ],
                            ),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: canClear ? _clear : null,
                    icon: _clearing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.pdfBadge,
                      side: BorderSide(color: t.pdfBadge.withValues(alpha: 0.45)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          auditAsync.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminAuditProvider),
            ),
            data: (items) => AdminDataTable(
              columns: const ['Action', 'Actor', 'Target', 'When'],
              emptyMessage: 'No admin actions logged yet.',
              rows: [
                for (final e in items)
                  [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.action, style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                        if (e.detail != null)
                          Text(e.detail!, style: TextStyle(fontSize: 11, color: t.textMuted)),
                      ],
                    ),
                    Text(
                      e.actorEmail ?? shortUid(e.actorUid),
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                    Text(
                      e.target != null ? shortUid(e.target!) : '—',
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                    Text(
                      formatAdminWhen(e.createdAt),
                      style: AppTokens.mono(size: 10, color: t.textMuted),
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
