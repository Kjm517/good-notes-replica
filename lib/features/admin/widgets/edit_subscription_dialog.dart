import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/design.dart';
import '../admin_api.dart';

/// Edits one account's entitlement: premium on/off, plan, and exactly when it
/// expires — down to the minute, since support fixes often hinge on "give them
/// until Friday evening" rather than a whole extra month.
class EditSubscriptionDialog extends ConsumerStatefulWidget {
  const EditSubscriptionDialog({super.key, required this.row});

  final AdminSubscriptionRow row;

  static Future<bool?> show(BuildContext context, AdminSubscriptionRow row) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditSubscriptionDialog(row: row),
    );
  }

  @override
  ConsumerState<EditSubscriptionDialog> createState() =>
      _EditSubscriptionDialogState();
}

class _EditSubscriptionDialogState
    extends ConsumerState<EditSubscriptionDialog> {
  late bool _isPremium;
  late String _plan;
  DateTime? _expiresAt;
  var _saving = false;
  String? _error;

  bool get _lifetime => _plan == 'lifetime';

  @override
  void initState() {
    super.initState();
    _isPremium = widget.row.isPremium;
    _plan = widget.row.plan ?? 'monthly';
    final raw = widget.row.expiresAt;
    _expiresAt = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _expiresAt ?? now.add(const Duration(days: 30));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      // Backdating is allowed on purpose: expiring someone immediately is a
      // legitimate correction.
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;

    setState(() {
      _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? initial.hour,
        time?.minute ?? initial.minute,
      );
    });
  }

  Future<void> _save() async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.updateSubscription(
        widget.row.uid,
        isPremium: _isPremium,
        plan: _isPremium ? _plan : null,
        // Lifetime ignores any date; the worker substitutes its own sentinel.
        expiresAt: _isPremium && !_lifetime
            ? _expiresAt?.toUtc().toIso8601String()
            : null,
      );
      ref.invalidate(adminSubscriptionsProvider);
      ref.invalidate(adminPaymentsProvider);
      ref.invalidate(adminOverviewProvider(30));
      ref.invalidate(adminBadgeCountsProvider);
      ref.invalidate(adminUsersProvider(''));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = widget.row.email ?? shortUid(widget.row.uid);

    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      title: const Text('Edit subscription'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: t.textSecondary)),
            Text(
              widget.row.uid,
              style: AppTokens.mono(size: 10, color: t.textFaint),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _isPremium,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _isPremium = v),
              title: const Text('Premium', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _isPremium ? 'Entitled' : 'Free tier',
                style: AppTokens.mono(size: 10, color: t.textFaint),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isPremium) ...[
              const SizedBox(height: 8),
              Text('Plan', style: AppTokens.sectionLabel(t.textFaint)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ButtonSegment(value: 'yearly', label: Text('Yearly')),
                  ButtonSegment(value: 'lifetime', label: Text('Lifetime')),
                ],
                selected: {_plan},
                onSelectionChanged: _saving
                    ? null
                    : (sel) => setState(() => _plan = sel.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              Text('Expires', style: AppTokens.sectionLabel(t.textFaint)),
              const SizedBox(height: 6),
              if (_lifetime)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive_rounded,
                          size: 18, color: t.textMuted),
                      const SizedBox(width: 10),
                      Text(
                        'Never expires',
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    _expiresAt == null
                        ? 'Pick a date and time'
                        : DateFormat('MMM d, y · h:mm a').format(_expiresAt!),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              if (!_lifetime && _expiresAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  _expiryHint(_expiresAt!),
                  style: AppTokens.mono(size: 10, color: t.textFaint),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  /// Spells out the consequence, since a backdated expiry revokes access.
  String _expiryHint(DateTime at) {
    final left = at.difference(DateTime.now());
    if (left.isNegative) return 'In the past — this revokes Premium now.';
    if (left.inDays >= 1) return '${left.inDays} days from now.';
    if (left.inHours >= 1) return '${left.inHours} hours from now.';
    return 'Less than an hour from now.';
  }
}
