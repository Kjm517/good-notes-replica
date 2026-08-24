import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../voucher_api.dart';

class AdminVouchersPage extends ConsumerStatefulWidget {
  const AdminVouchersPage({super.key});

  @override
  ConsumerState<AdminVouchersPage> createState() => _AdminVouchersPageState();
}

class _AdminVouchersPageState extends ConsumerState<AdminVouchersPage> {
  final _search = TextEditingController();
  final _code = TextEditingController();
  final _label = TextEditingController();
  final _discount = TextEditingController(text: '20');
  final _maxUses = TextEditingController();
  var _active = true;
  var _hasExpiry = false;
  DateTime? _expiresAt;
  var _saving = false;
  var _showEditor = false;
  /// Null = creating; non-null = editing that code.
  String? _editingCode;
  String _filter = '';

  bool get _isEditing => _editingCode != null;

  @override
  void dispose() {
    _search.dispose();
    _code.dispose();
    _label.dispose();
    _discount.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  void _openCreate() {
    setState(() {
      _showEditor = true;
      _editingCode = null;
      _code.clear();
      _label.clear();
      _discount.text = '20';
      _maxUses.clear();
      _active = true;
      _hasExpiry = false;
      _expiresAt = null;
    });
  }

  void _openEdit(AdminVoucherRow row) {
    final parsed = row.expiresAt == null ? null : DateTime.tryParse(row.expiresAt!);
    setState(() {
      _showEditor = true;
      _editingCode = row.code;
      _code.text = row.code;
      _label.text = row.label ?? '';
      _discount.text = '${row.discountPercent}';
      _maxUses.text = row.maxUses?.toString() ?? '';
      _active = row.active;
      _hasExpiry = parsed != null;
      _expiresAt = parsed?.toLocal();
    });
  }

  void _closeEditor() {
    setState(() {
      _showEditor = false;
      _editingCode = null;
    });
  }

  Future<void> _save() async {
    final service = ref.read(voucherAdminServiceProvider);
    if (service == null) {
      _snack('Configure NOTABLY_FILE_ENDPOINT and sign in.');
      return;
    }
    final code = (_editingCode ?? _code.text).trim();
    final percent = int.tryParse(_discount.text.trim());
    if (code.isEmpty || percent == null || percent < 1 || percent > 100) {
      _snack('Enter a code and discount between 1–100%.');
      return;
    }
    final maxRaw = _maxUses.text.trim();
    final maxUses = maxRaw.isEmpty ? null : int.tryParse(maxRaw);
    if (maxRaw.isNotEmpty && (maxUses == null || maxUses < 1)) {
      _snack('Redemption limit must be a positive number.');
      return;
    }
    if (_hasExpiry && _expiresAt == null) {
      _snack('Pick an expiry date, or turn off Expiry date.');
      return;
    }

    setState(() => _saving = true);
    try {
      final wasEditing = _isEditing;
      final expiryIso = _hasExpiry && _expiresAt != null
          ? DateTime(
              _expiresAt!.year,
              _expiresAt!.month,
              _expiresAt!.day,
              23,
              59,
              59,
            ).toUtc().toIso8601String()
          : null;
      await service.upsertVoucher(
        code: code,
        discountPercent: percent,
        label: _label.text,
        active: _active,
        maxUses: maxUses,
        clearMaxUses: wasEditing && maxRaw.isEmpty,
        expiresAt: expiryIso,
        clearExpiresAt: !_hasExpiry,
      );
      ref.invalidate(adminVouchersProvider);
      ref.invalidate(adminBadgeCountsProvider);
      _closeEditor();
      _snack(
        wasEditing
            ? 'Updated ${code.toUpperCase()}.'
            : 'Created ${code.toUpperCase()}.',
      );
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive(AdminVoucherRow row) async {
    final service = ref.read(voucherAdminServiceProvider);
    if (service == null) return;
    try {
      await service.upsertVoucher(
        code: row.code,
        discountPercent: row.discountPercent,
        label: row.label,
        active: !row.active,
        expiresAt: row.expiresAt,
        maxUses: row.maxUses,
      );
      ref.invalidate(adminVouchersProvider);
      ref.invalidate(adminBadgeCountsProvider);
      _snack(
        !row.active
            ? '${row.code} is now active.'
            : '${row.code} is now inactive.',
      );
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _delete(String code) async {
    final service = ref.read(voucherAdminServiceProvider);
    if (service == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $code?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await service.deleteVoucher(code);
      if (_editingCode == code) _closeEditor();
      ref.invalidate(adminVouchersProvider);
      ref.invalidate(adminBadgeCountsProvider);
      _snack('Deleted $code.');
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final vouchersAsync = ref.watch(adminVouchersProvider);
    final narrow = MediaQuery.sizeOf(context).width < 960;

    return vouchersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        final q = _filter.trim().toLowerCase();
        final filtered = q.isEmpty
            ? rows
            : rows.where((r) {
                return r.code.toLowerCase().contains(q) ||
                    (r.label?.toLowerCase().contains(q) ?? false);
              }).toList();
        final activeCount = rows.where((r) => r.active).length;
        final redemptions = rows.fold<int>(0, (s, r) => s + r.usedCount);

        final list = SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voucher codes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: t.text,
                          ),
                        ),
                        Text(
                          '${rows.length} codes · $redemptions redemptions',
                          style: AppTokens.mono(size: 11, color: t.textFaint),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New voucher'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  hintText: 'Search codes',
                  prefixIcon: Icon(Icons.search_rounded, color: t.textFaint),
                  filled: true,
                  fillColor: t.fill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.control),
                    borderSide: BorderSide(color: t.lineStrong),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth > 900 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _MiniStat(label: 'Active codes', value: '$activeCount', t: t),
                      _MiniStat(label: 'Redemptions', value: '$redemptions', t: t),
                      _MiniStat(label: 'GCash & Maya', value: 'PayMongo', t: t),
                      _MiniStat(label: 'Store IAP', value: 'Unchanged', t: t),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              _VoucherTable(
                rows: filtered,
                onEdit: _openEdit,
                onToggleActive: _toggleActive,
                onDelete: _delete,
              ),
            ],
          ),
        );

        final editor = _VoucherEditorPage(
          isEditing: _isEditing,
          code: _code,
          label: _label,
          discount: _discount,
          maxUses: _maxUses,
          active: _active,
          hasExpiry: _hasExpiry,
          expiresAt: _expiresAt,
          saving: _saving,
          codeLocked: _isEditing,
          onActive: (v) => setState(() => _active = v),
          onHasExpiry: (v) => setState(() {
            _hasExpiry = v;
            if (v && _expiresAt == null) {
              _expiresAt = DateTime.now().add(const Duration(days: 30));
            }
            if (!v) _expiresAt = null;
          }),
          onPickExpiry: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: DateTime(now.year + 10),
            );
            if (picked != null && mounted) {
              setState(() {
                _hasExpiry = true;
                _expiresAt = picked;
              });
            }
          },
          onClose: _closeEditor,
          onSave: _save,
        );

        if (narrow) {
          if (_showEditor) {
            return editor;
          }
          return list;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            if (_showEditor)
              Container(
                width: 400,
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(left: BorderSide(color: t.line)),
                  boxShadow: AppTokens.elevation(t.shadow, y: 0, blur: 24, opacity: 0.08),
                ),
                child: editor,
              ),
          ],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.t});

  final String label;
  final String value;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTokens.mono(size: 10, color: t.textFaint)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.text),
          ),
        ],
      ),
    );
  }
}

class _VoucherTable extends StatelessWidget {
  const _VoucherTable({
    required this.rows,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final List<AdminVoucherRow> rows;
  final ValueChanged<AdminVoucherRow> onEdit;
  final ValueChanged<AdminVoucherRow> onToggleActive;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (rows.isEmpty) {
      return Text('No vouchers match.', style: TextStyle(color: t.textMuted));
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 2, child: _head('Code', t)),
                Expanded(child: _head('Discount', t)),
                Expanded(child: _head('Redemptions', t)),
                Expanded(child: _head('Expires', t)),
                Expanded(child: _head('Status', t)),
                const SizedBox(width: 96),
              ],
            ),
          ),
          for (final row in rows) ...[
            Divider(height: 1, color: t.line),
            _TableRow(
              row: row,
              onEdit: () => onEdit(row),
              onToggleActive: () => onToggleActive(row),
              onDelete: () => onDelete(row.code),
            ),
          ],
        ],
      ),
    );
  }

  Widget _head(String label, AppTokens t) =>
      Text(label, style: AppTokens.mono(size: 10, color: t.textFaint));
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.row,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminVoucherRow row;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final exhausted = row.maxUses != null && row.usedCount >= row.maxUses!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.local_activity_outlined, size: 18, color: t.accentText),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.code, style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                      if (row.label != null)
                        Text(row.label!, style: TextStyle(fontSize: 11, color: t.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text('${row.discountPercent}%', style: AppTokens.mono(size: 12, color: t.text)),
          ),
          Expanded(
            child: Text(
              row.maxUses != null ? '${row.usedCount} / ${row.maxUses}' : '${row.usedCount}',
              style: AppTokens.mono(size: 11, color: t.textSecondary),
            ),
          ),
            Expanded(
              child: Text(
                _formatExpiry(row.expiresAt),
                style: AppTokens.mono(size: 10, color: t.textFaint),
              ),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _ActiveToggle(
                active: row.active && !exhausted,
                label: exhausted
                    ? 'Exhausted'
                    : row.active
                        ? 'Active'
                        : 'Inactive',
                onTap: exhausted ? null : onToggleActive,
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: Icon(Icons.edit_outlined, color: t.accentText, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline_rounded, color: t.pdfBadge, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveToggle extends StatelessWidget {
  const _ActiveToggle({
    required this.active,
    required this.label,
    this.onTap,
  });

  final bool active;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = onTap == null
        ? t.textFaint
        : active
            ? t.success
            : t.textMuted;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.check_circle_outline : Icons.pause_circle_outline,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTokens.mono(size: 10, weight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create / edit voucher form (side panel on desktop, full page on narrow).
class _VoucherEditorPage extends StatelessWidget {
  const _VoucherEditorPage({
    required this.isEditing,
    required this.code,
    required this.label,
    required this.discount,
    required this.maxUses,
    required this.active,
    required this.hasExpiry,
    required this.expiresAt,
    required this.saving,
    required this.codeLocked,
    required this.onActive,
    required this.onHasExpiry,
    required this.onPickExpiry,
    required this.onClose,
    required this.onSave,
  });

  final bool isEditing;
  final TextEditingController code;
  final TextEditingController label;
  final TextEditingController discount;
  final TextEditingController maxUses;
  final bool active;
  final bool hasExpiry;
  final DateTime? expiresAt;
  final bool saving;
  final bool codeLocked;
  final ValueChanged<bool> onActive;
  final ValueChanged<bool> onHasExpiry;
  final VoidCallback onPickExpiry;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              if (MediaQuery.sizeOf(context).width < 960)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(
                  isEditing ? 'Edit voucher' : 'New voucher',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.text),
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 960)
                IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Text('Code', style: AppTokens.sectionLabel(t.textFaint)),
              const SizedBox(height: 6),
              TextField(
                controller: code,
                enabled: !codeLocked && !saving,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'STUDENT20',
                  helperText: codeLocked ? 'Code cannot be changed when editing.' : null,
                ),
              ),
              const SizedBox(height: 14),
              Text('Label', style: AppTokens.sectionLabel(t.textFaint)),
              const SizedBox(height: 6),
              TextField(
                controller: label,
                enabled: !saving,
                decoration: const InputDecoration(hintText: 'Student discount'),
              ),
              const SizedBox(height: 14),
              Text('Discount (%)', style: AppTokens.sectionLabel(t.textFaint)),
              const SizedBox(height: 6),
              TextField(
                controller: discount,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '20'),
              ),
              const SizedBox(height: 14),
              Text('Redemption limit', style: AppTokens.sectionLabel(t.textFaint)),
              const SizedBox(height: 6),
              TextField(
                controller: maxUses,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Optional max uses'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expiry date'),
                subtitle: Text(
                  hasExpiry
                      ? 'Code stops working after the chosen day.'
                      : 'No expiry — code works until deactivated.',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                value: hasExpiry,
                onChanged: saving ? null : onHasExpiry,
              ),
              if (hasExpiry) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: saving ? null : onPickExpiry,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    expiresAt == null
                        ? 'Pick expiry date'
                        : 'Expires ${_formatExpiryDate(expiresAt!)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text(
                  active
                      ? 'Redeemable at GCash & Maya checkout.'
                      : 'Paused — code will be rejected at checkout.',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                value: active,
                onChanged: saving ? null : onActive,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? 'Save changes' : 'Create voucher'),
          ),
        ),
      ],
    );
  }
}

String _formatExpiry(String? raw) {
  if (raw == null || raw.isEmpty) return 'No expiry';
  final dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return raw;
  return _formatExpiryDate(dt);
}

String _formatExpiryDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
