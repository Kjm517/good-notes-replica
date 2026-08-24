import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../widgets/admin_widgets.dart';

class AdminAuditPage extends ConsumerWidget {
  const AdminAuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final auditAsync = ref.watch(adminAuditProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          auditAsync.when(
            loading: () => const AdminPageHeader(title: 'Audit log', subtitle: 'Loading…'),
            error: (_, __) => const AdminPageHeader(title: 'Audit log'),
            data: (entries) => AdminPageHeader(
              title: 'Audit log',
              subtitle: '${entries.length} recorded actions',
            ),
          ),
          const SizedBox(height: 16),
          auditAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminAuditProvider),
            ),
            data: (entries) => AdminDataTable(
              columns: const ['Action', 'Actor', 'Target', 'When'],
              emptyMessage: 'No admin actions logged yet.',
              rows: [
                for (final e in entries)
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
                      e.createdAt.length >= 16
                          ? e.createdAt.substring(0, 16).replaceFirst('T', ' ')
                          : e.createdAt,
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
