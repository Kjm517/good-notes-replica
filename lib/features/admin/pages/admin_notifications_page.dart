import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../admin_dates.dart';
import '../widgets/admin_widgets.dart';

/// Compose and send a push notification, and see what went out before.
class AdminNotificationsPage extends ConsumerStatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  ConsumerState<AdminNotificationsPage> createState() =>
      _AdminNotificationsPageState();
}

class _AdminNotificationsPageState
    extends ConsumerState<AdminNotificationsPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  var _audience = 'all';
  var _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  int _audienceSize(AdminNotificationsData data) => switch (_audience) {
        'premium' => data.audiencePremium,
        'free' => data.audienceFree,
        _ => data.audienceAll,
      };

  Future<void> _send(AdminNotificationsData data) async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;

    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    // Push cannot be recalled, so make the blast radius explicit first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send notification?'),
        content: Text(
          'This sends "$title" to ${_audienceSize(data)} '
          '${_audience == 'all' ? 'accounts' : '$_audience accounts'}. '
          'It cannot be undone or recalled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final sent = await api.sendNotification(
        title: title,
        body: body,
        audience: _audience,
      );
      _title.clear();
      _body.clear();
      ref.invalidate(adminNotificationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sent to ${sent.delivered} device(s)'
              '${sent.failed > 0 ? ' · ${sent.failed} failed' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final async = ref.watch(adminNotificationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminPageHeader(
            title: 'Notifications',
            subtitle: 'Push an announcement to signed-in devices.',
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminNotificationsProvider),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!data.configured) _NotConfiguredNotice(t: t),
                if (!data.configured) const SizedBox(height: 16),
                _Composer(
                  t: t,
                  title: _title,
                  body: _body,
                  audience: _audience,
                  audienceSize: _audienceSize(data),
                  sending: _sending,
                  enabled: data.configured,
                  onAudience: (v) => setState(() => _audience = v),
                  onSend: () => _send(data),
                ),
                const SizedBox(height: 24),
                Text('Sent', style: AppTokens.sectionLabel(t.textFaint)),
                const SizedBox(height: 8),
                AdminDataTable(
                  columns: const ['When', 'Message', 'Audience', 'Delivered'],
                  flex: const [3, 6, 2, 2],
                  emptyMessage: 'Nothing sent yet.',
                  rows: [
                    for (final n in data.sent)
                      [
                        Text(
                          formatAdminWhen(n.sentAt),
                          style:
                              AppTokens.mono(size: 11, color: t.textSecondary),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: t.text,
                              ),
                            ),
                            Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: t.textMuted,
                              ),
                            ),
                          ],
                        ),
                        AdminStatusChip(
                          label: n.audience,
                          color: n.audience == 'premium'
                              ? t.success
                              : t.textMuted,
                        ),
                        Text(
                          n.failed > 0
                              ? '${n.delivered} · ${n.failed} failed'
                              : '${n.delivered}',
                          style: AppTokens.mono(size: 11, color: t.textMuted),
                        ),
                      ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotConfiguredNotice extends StatelessWidget {
  const _NotConfiguredNotice({required this.t});

  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: t.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Push is not configured. Add the Firebase service-account JSON '
              'to the worker as FIREBASE_SERVICE_ACCOUNT, then reload.',
              style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.t,
    required this.title,
    required this.body,
    required this.audience,
    required this.audienceSize,
    required this.sending,
    required this.enabled,
    required this.onAudience,
    required this.onSend,
  });

  final AppTokens t;
  final TextEditingController title;
  final TextEditingController body;
  final String audience;
  final int audienceSize;
  final bool sending;
  final bool enabled;
  final ValueChanged<String> onAudience;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: title,
            enabled: enabled && !sending,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'New in Notably',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: body,
            enabled: enabled && !sending,
            maxLines: 3,
            maxLength: 180,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'What should people know?',
            ),
          ),
          const SizedBox(height: 12),
          Text('Audience', style: AppTokens.sectionLabel(t.textFaint)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Everyone')),
              ButtonSegment(value: 'premium', label: Text('Premium')),
              ButtonSegment(value: 'free', label: Text('Free')),
            ],
            selected: {audience},
            onSelectionChanged: enabled && !sending
                ? (sel) => onAudience(sel.first)
                : null,
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: enabled && !sending ? onSend : null,
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              sending ? 'Sending…' : 'Send to $audienceSize account(s)',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }
}
