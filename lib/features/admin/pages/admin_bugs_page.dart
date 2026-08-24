import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design.dart';
import '../admin_access.dart';
import '../admin_api.dart';
import '../admin_dates.dart';
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
      await api.updateBug(report.id, status: status);
      ref.invalidate(adminBugsProvider);
      ref.invalidate(adminOverviewProvider(30));
      ref.invalidate(adminBadgeCountsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _reply(
    WidgetRef ref,
    BuildContext context,
    AdminBugReport report,
  ) async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    final controller = TextEditingController(text: report.adminReply ?? '');
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'What should we tell the user?',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (sent != true || text.isEmpty) return;
    try {
      await api.updateBug(report.id, reply: text, status: 'triaged');
      ref.invalidate(adminBugsProvider);
      if (report.email != null && context.mounted) {
        final uri = Uri(
          scheme: 'mailto',
          path: report.email,
          queryParameters: {
            'subject': 'Re: ${report.subject}',
            'body': text,
          },
        );
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply saved. This report has no email to notify.')),
        );
      }
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
    final canWrite = ref.watch(adminCanWriteProvider);

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
                            '${bug.category} · ${bug.device} · ${formatAdminWhen(bug.createdAt)}',
                            style: AppTokens.mono(size: 10, color: t.textFaint),
                          ),
                          if (bug.email != null) ...[
                            const SizedBox(height: 4),
                            Text(bug.email!, style: TextStyle(fontSize: 12, color: t.textMuted)),
                          ],
                          const SizedBox(height: 10),
                          Text(bug.description, style: TextStyle(color: t.textSecondary, height: 1.45)),
                          if (bug.attachments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < bug.attachments.length; i++)
                                  _BugThumb(reportId: bug.id, index: i, name: bug.attachments[i].name),
                              ],
                            ),
                          ],
                          if (bug.adminReply != null && bug.adminReply!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Reply', style: AppTokens.sectionLabel(t.textFaint)),
                            const SizedBox(height: 4),
                            Text(bug.adminReply!, style: TextStyle(color: t.text, height: 1.4)),
                          ],
                          if (canWrite) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _reply(ref, context, bug),
                                  icon: const Icon(Icons.reply_outlined, size: 16),
                                  label: const Text('Reply'),
                                ),
                                for (final status in ['triaged', 'resolved', 'closed'])
                                  if (bug.status != status)
                                    OutlinedButton(
                                      onPressed: () => _setStatus(ref, context, bug, status),
                                      child: Text(status),
                                    ),
                              ],
                            ),
                          ],
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

class _BugThumb extends ConsumerWidget {
  const _BugThumb({
    required this.reportId,
    required this.index,
    required this.name,
  });

  final String reportId;
  final int index;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final api = ref.watch(adminApiServiceProvider);
    if (api == null) return const SizedBox.shrink();
    return FutureBuilder<List<int>>(
      future: api.fetchBugAttachment(reportId, index),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            width: 96,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.fill,
              borderRadius: BorderRadius.circular(Radii.inner),
            ),
            child: snap.hasError
                ? Icon(Icons.broken_image_outlined, color: t.textFaint)
                : const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(Radii.inner),
          child: Image.memory(
            Uint8List.fromList(snap.data!),
            width: 120,
            height: 80,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
