import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../widgets/admin_widgets.dart';

class AdminBugsPage extends ConsumerWidget {
  const AdminBugsPage({super.key});

  Color _statusColor(AppTokens t, String status) => switch (status) {
        'open' => t.pdfBadge,
        'triaged' => t.accentText,
        'resolved' => t.success,
        _ => t.textMuted,
      };

  Future<void> _setStatus(
    WidgetRef ref,
    BuildContext context,
    AdminBugReport report,
    String status,
  ) async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    try {
      await api.updateBugStatus(report.id, status);
      ref.invalidate(adminBugsProvider);
      ref.invalidate(adminOverviewProvider(30));
      ref.invalidate(adminBadgeCountsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final bugsAsync = ref.watch(adminBugsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bugsAsync.when(
            loading: () => const AdminPageHeader(title: 'Bug reports', subtitle: 'Loading…'),
            error: (_, __) => const AdminPageHeader(title: 'Bug reports'),
            data: (bugs) {
              final open = bugs.where((b) => b.status == 'open' || b.status == 'triaged').length;
              return AdminPageHeader(
                title: 'Bug reports',
                subtitle: '$open open · ${bugs.length} total',
              );
            },
          ),
          const SizedBox(height: 16),
          bugsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminBugsProvider),
            ),
            data: (bugs) {
              if (bugs.isEmpty) {
                return Text(
                  'No reports yet. Users can submit from Settings → Report a bug.',
                  style: TextStyle(color: t.textMuted),
                );
              }
              return Column(
                children: [
                  for (final bug in bugs)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(Radii.card),
                        border: Border.all(color: t.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bug.subject,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: t.text,
                                  ),
                                ),
                              ),
                              AdminStatusChip(
                                label: bug.status,
                                color: _statusColor(t, bug.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${bug.category} · ${bug.device} · ${bug.createdAt.substring(0, 10)}',
                            style: AppTokens.mono(size: 10, color: t.textFaint),
                          ),
                          if (bug.email != null) ...[
                            const SizedBox(height: 4),
                            Text(bug.email!, style: TextStyle(fontSize: 12, color: t.textMuted)),
                          ],
                          const SizedBox(height: 10),
                          Text(bug.description, style: TextStyle(color: t.textSecondary, height: 1.45)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final status in ['triaged', 'resolved', 'closed'])
                                if (bug.status != status)
                                  OutlinedButton(
                                    onPressed: () => _setStatus(ref, context, bug, status),
                                    child: Text(status),
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
