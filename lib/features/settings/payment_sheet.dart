import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/design.dart';
import '../../app/pricing.dart';
import 'premium_plan_sheet.dart';
import 'premium_providers.dart';
import 'settings_widgets.dart';

enum _PayMethod { card, wallet, paypal }

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key, required this.plan});

  final BillingPlan plan;

  static Future<void> show(BuildContext context, {required BillingPlan plan}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PaymentSheet(plan: plan),
      ),
    );
  }

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  _PayMethod _method = _PayMethod.card;
  final _voucher = TextEditingController(text: 'STUDENT20');
  var _voucherApplied = true;
  var _processing = false;

  double get _subtotal => widget.plan == BillingPlan.yearly
      ? AppPricing.yearlyAmount.toDouble()
      : AppPricing.monthlyAmount.toDouble();

  double get _discount =>
      _voucherApplied && _voucher.text.trim().toUpperCase() == 'STUDENT20'
          ? (_subtotal * 0.2)
          : 0;

  double get _dueToday => (_subtotal - _discount).clamp(0, _subtotal);

  @override
  void dispose() {
    _voucher.dispose();
    super.dispose();
  }

  Future<void> _startTrial() async {
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await ref.read(billingPlanProvider.notifier).activate(widget.plan);
    if (!mounted) return;
    setState(() => _processing = false);
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Premium activated — enjoy unlimited quizzes!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final renew = DateTime.now().add(const Duration(days: 7));
    final planLabel =
        widget.plan == BillingPlan.yearly ? 'Premium — Yearly' : 'Premium — Monthly';
    final period = widget.plan == BillingPlan.yearly ? '/yr' : '/mo';
    final trialNote = widget.plan == BillingPlan.yearly
        ? 'Then ${AppPricing.formatAmount(_subtotal - _discount)}$period on ${DateFormat.yMMMd().format(renew.add(const Duration(days: 358)))}'
        : 'Then ${AppPricing.formatAmount(_subtotal - _discount)}$period on ${DateFormat.yMMMd().format(renew.add(const Duration(days: 23)))}';

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: const Text('Payment'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.lock_rounded, color: t.success, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          PremiumGradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: t.premiumText, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planLabel,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: t.premiumText,
                            ),
                          ),
                          Text(
                            '7-day free trial, then ${AppPricing.formatAmount(_subtotal)}$period',
                            style: TextStyle(fontSize: 10.5, color: t.premiumText.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        PremiumPlanSheet.show(context);
                      },
                      child: Text('Change', style: TextStyle(color: t.premiumText)),
                    ),
                  ],
                ),
                Divider(color: t.premium.withValues(alpha: 0.24), height: 20),
                _SummaryRow(label: 'Subtotal', value: AppPricing.formatAmount(_subtotal)),
                if (_discount > 0)
                  _SummaryRow(
                    label: 'Voucher STUDENT20',
                    value: '−${AppPricing.formatAmount(_discount)}',
                    valueColor: t.success,
                  ),
                if (_dueToday < _subtotal)
                  _SummaryRow(
                    label: 'Trial credit',
                    value: '−${AppPricing.formatAmount(_dueToday)}',
                    valueColor: t.success,
                  ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Due today',
                  value: AppPricing.formatPeso(0),
                  bold: true,
                  valueColor: t.premiumText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Voucher code', style: _label(t)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucher,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.local_activity_outlined, color: t.success),
                    filled: true,
                    fillColor: t.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.control),
                      borderSide: BorderSide(color: t.success.withValues(alpha: 0.4)),
                    ),
                  ),
                  onChanged: (_) => setState(() {
                    _voucherApplied =
                        _voucher.text.trim().toUpperCase() == 'STUDENT20';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _voucher.clear();
                  _voucherApplied = false;
                }),
                child: const Text('Remove'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Payment method', style: _label(t)),
          const SizedBox(height: 9),
          Row(
            children: [
              for (final m in [
                (_PayMethod.card, Icons.credit_card_rounded, 'Card'),
                (_PayMethod.wallet, Icons.account_balance_wallet_outlined, 'Wallet'),
                (_PayMethod.paypal, Icons.payments_outlined, 'PayPal'),
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: m.$1 != _PayMethod.paypal ? 8 : 0),
                    child: _MethodChip(
                      icon: m.$2,
                      label: m.$3,
                      selected: _method == m.$1,
                      onTap: () => setState(() => _method = m.$1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_method == _PayMethod.card) ...[
            _FakeField(icon: Icons.credit_card_outlined, value: '4242 4242 4242 4242'),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: _FakeField(value: '09 / 28')),
                const SizedBox(width: 9),
                Expanded(child: _FakeField(value: '•••', trailing: Icons.help_outline_rounded)),
              ],
            ),
            const SizedBox(height: 9),
            _FakeField(icon: Icons.person_outline_rounded, value: 'Cardholder name'),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: t.line),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: t.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payments are encrypted. Cancel before ${DateFormat.MMMd().format(renew)} and you won\'t be charged.',
                    style: TextStyle(fontSize: 11.5, height: 1.45, color: t.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _processing ? null : _startTrial,
            icon: _processing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.premiumOn),
                  )
                : Icon(Icons.lock_rounded, color: t.premiumOn),
            label: Text(
              'Start free trial',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
                color: t.premiumOn,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: t.premium,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            trialNote,
            textAlign: TextAlign.center,
            style: AppTokens.mono(size: 11, color: t.textFaint),
          ),
        ],
      ),
    );
  }

  TextStyle _label(AppTokens t) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary);
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 14 : 12, color: t.textMuted)),
          Text(
            value,
            style: AppTokens.mono(
              size: bold ? 14 : 12,
              color: valueColor ?? t.textMuted,
            ).copyWith(fontWeight: bold ? FontWeight.w700 : null),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 41,
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(t.accent.withValues(alpha: 0.22), t.surface)
              : t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? t.accent : t.lineStrong,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? t.accentText : t.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? t.accentText : t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeField extends StatelessWidget {
  const _FakeField({this.icon, required this.value, this.trailing});

  final IconData? icon;
  final String value;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.lineStrong),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: t.textFaint),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Text(value, style: AppTokens.mono(size: 13, color: t.text)),
          ),
          if (trailing != null) Icon(trailing, size: 16, color: t.textFaint),
        ],
      ),
    );
  }
}
