import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design.dart';
import '../auth/providers.dart';
import 'billing_helpers.dart';
import 'billing_ladder.dart';
import 'billing_plan.dart';
import 'entitlements.dart';
import 'paymongo_billing.dart';
import 'premium_providers.dart';
import 'revenuecat_billing.dart';
import 'settings_widgets.dart';
import '../admin/voucher_api.dart';

enum _PayMethod { store, gcash, maya }

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({
    super.key,
    required this.plan,
    this.package,
  });

  final BillingPlan plan;
  final Package? package;

  static Future<void> show(
    BuildContext context, {
    required BillingPlan plan,
    Package? package,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PaymentSheet(plan: plan, package: package),
      ),
    );
  }

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  _PayMethod _method = _PayMethod.store;
  final _voucher = TextEditingController();
  VoucherValidation? _appliedVoucher;
  var _validatingVoucher = false;
  var _processing = false;
  var _defaultMethodSet = false;
  var _autoVoucherAttempted = false;

  bool get _useStore => ref.watch(revenueCatConfiguredProvider);
  bool get _useWallets => ref.watch(payMongoAvailableProvider);

  double get _subtotal {
    final price = widget.package?.storeProduct.price;
    if (price != null && price > 0) return price;
    return priceForPlan(widget.plan);
  }

  double _discount(bool walletCheckout) {
    final rate = _appliedVoucher?.discountRate;
    if (rate == null) return 0;
    if (walletCheckout || !_useStore) return _subtotal * rate;
    return 0;
  }

  String? get _appliedVoucherLabel {
    final applied = _appliedVoucher;
    if (applied == null || !applied.valid) return null;
    return applied.label ?? applied.code;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAutoApplyStudentVoucher());
    });
  }

  @override
  void dispose() {
    _voucher.dispose();
    super.dispose();
  }

  void _clearVoucher() {
    _voucher.clear();
    setState(() => _appliedVoucher = null);
  }

  Future<void> _maybeAutoApplyStudentVoucher() async {
    if (_autoVoucherAttempted || !mounted) return;
    _autoVoucherAttempted = true;
    final email = ref.read(authStateProvider).asData?.value?.email;
    if (!qualifiesForStudentPricing(email)) return;
    if (_voucher.text.trim().isNotEmpty) return;
    _voucher.text = kStudentVoucherCode;
    await _applyVoucher(silent: true);
  }

  Future<void> _applyVoucher({bool silent = false}) async {
    final code = _voucher.text.trim();
    if (code.isEmpty) return;
    setState(() => _validatingVoucher = true);
    try {
      final result = await validateVoucherCode(code);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher check unavailable — try again later.')),
        );
        setState(() => _appliedVoucher = null);
        return;
      }
      if (!result.valid || result.discountRate == null) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or expired voucher code.')),
          );
        }
        setState(() => _appliedVoucher = null);
        return;
      }
      setState(() => _appliedVoucher = result);
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applied ${result.label ?? result.code}.')),
        );
      }
    } finally {
      if (mounted) setState(() => _validatingVoucher = false);
    }
  }

  PayMongoWallet? get _selectedWallet => switch (_method) {
        _PayMethod.gcash => PayMongoWallet.gcash,
        _PayMethod.maya => PayMongoWallet.paymaya,
        _ => null,
      };

  Future<void> _subscribe() async {
    setState(() => _processing = true);
    try {
      if (_method == _PayMethod.store && _useStore) {
        await _subscribeViaStore();
      } else if (_selectedWallet != null && _useWallets) {
        await _subscribeViaWallet(_selectedWallet!);
      } else if (!_useStore && !_useWallets) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await ref.read(billingPlanProvider.notifier).activate(
              widget.plan,
              amountPhp: _subtotal - _discount(true),
            );
        ref.read(entitlementServiceProvider).refresh();
        if (!mounted) return;
        _finish('Premium activated — enjoy unlimited quizzes!');
      } else {
        throw StateError('Choose a payment method.');
      }
    } catch (e) {
      if (isPurchaseCancelled(e)) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _subscribeViaStore() async {
    Package? package = widget.package;
    if (package == null) {
      final offerings = await ref.read(offeringsProvider.future);
      package = packageForPlan(offerings, widget.plan);
    }
    if (package == null) {
      throw StateError('This plan is not available yet. Check RevenueCat offerings.');
    }
    final result = await purchasePackage(package);
    ref.read(customerInfoProvider.notifier).apply(result.customerInfo);
    await ref.read(billingPlanProvider.notifier).recordStorePurchase(
          plan: widget.plan,
          package: package,
        );
    ref.read(entitlementServiceProvider).refresh();
    if (!mounted) return;
    _finish('Premium activated — enjoy unlimited quizzes!');
  }

  Future<void> _subscribeViaWallet(PayMongoWallet wallet) async {
    final billing = ref.read(payMongoBillingServiceProvider);
    if (billing == null) {
      throw StateError('Sign in to pay with ${wallet.label}.');
    }

    final checkout = await billing.createCheckout(
      plan: widget.plan,
      wallet: wallet,
      voucher: _appliedVoucher?.valid == true ? _voucher.text : null,
    );
    await billing.markPendingCheckout(checkout.paymentIntentId);

    final uri = Uri.parse(checkout.redirectUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Could not open ${wallet.label} checkout.');
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Complete payment in ${wallet.label}, then return to Notably.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _finish(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_defaultMethodSet) {
      _defaultMethodSet = true;
      if (!_useStore && _useWallets) {
        _method = _PayMethod.gcash;
      }
    }
    final t = context.tokens;
    final walletCheckout = _selectedWallet != null;
    final planLabel = widget.plan == BillingPlan.yearly
        ? 'Premium — Yearly'
        : 'Premium — Monthly';
    final priceLabel = priceLabelForPackage(widget.package, widget.plan);
    final due = _subtotal - _discount(walletCheckout);

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: const Text('Subscribe'),
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
                    Icon(Icons.workspace_premium_rounded,
                        color: t.premiumText, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                          Text(
                            _method == _PayMethod.store && _useStore
                                ? '7-day free trial via app store'
                                : 'One-time period · renew manually',
                            style: AppTokens.mono(size: 10, color: t.textFaint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _PriceRow(
                  label: 'Price',
                  value: walletCheckout || !_useStore
                      ? formatPhp(_subtotal)
                      : priceLabel,
                ),
                if (_discount(walletCheckout) > 0)
                  _PriceRow(
                    label: _appliedVoucherLabel ?? 'Discount',
                    value: '-${formatPhp(_discount(walletCheckout))}',
                    accent: t.success,
                  ),
                if (walletCheckout || !_useStore) ...[
                  Divider(height: 20, color: t.line),
                  _PriceRow(
                    label: 'Due today',
                    value: formatPhp(due),
                    bold: true,
                  ),
                ],
              ],
            ),
          ),
          if (_useWallets || (!_useStore && !_useWallets)) ...[
            const SizedBox(height: 18),
            Text('Voucher code', style: AppTokens.sectionLabel(t.textFaint)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voucher,
                    decoration: InputDecoration(
                      hintText: kStudentVoucherCode,
                      suffixIcon: _voucher.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: _clearVoucher,
                            ),
                    ),
                    onChanged: (_) => setState(() => _appliedVoucher = null),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _validatingVoucher ? null : () => _applyVoucher(),
                  child: _validatingVoucher
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${studentPricingHint()} ${launchPricingHint()}',
              style: TextStyle(fontSize: 11, color: t.textMuted, height: 1.35),
            ),
          ],
          const SizedBox(height: 18),
          Text('Payment method', style: AppTokens.sectionLabel(t.textFaint)),
          const SizedBox(height: 8),
          SettingsGroupCard(
            children: [
              if (_useStore)
                _PayRow(
                  icon: Icons.store_rounded,
                  label: defaultTargetPlatform == TargetPlatform.iOS
                      ? 'App Store'
                      : 'Google Play',
                  subtitle: 'Card · trial eligible',
                  selected: _method == _PayMethod.store,
                  onTap: () => setState(() => _method = _PayMethod.store),
                ),
              if (_useWallets) ...[
                _PayRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'GCash',
                  subtitle: 'PayMongo · instant redirect',
                  selected: _method == _PayMethod.gcash,
                  onTap: () => setState(() => _method = _PayMethod.gcash),
                ),
                _PayRow(
                  icon: Icons.payments_outlined,
                  label: 'Maya',
                  subtitle: 'PayMongo · instant redirect',
                  selected: _method == _PayMethod.maya,
                  onTap: () => setState(() => _method = _PayMethod.maya),
                ),
              ],
              if (!_useStore && !_useWallets)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Simulated checkout — add RevenueCat or PayMongo keys to enable real billing.',
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _processing ? null : _subscribe,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: t.premium,
              foregroundColor: t.premiumOn,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _processing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_buttonLabel()),
          ),
          const SizedBox(height: 10),
          Text(
            _footnote(),
            textAlign: TextAlign.center,
            style: AppTokens.mono(size: 10, color: t.textFaint),
          ),
        ],
      ),
    );
  }

  String _buttonLabel() {
    if (_method == _PayMethod.store && _useStore) return 'Start free trial';
    if (_selectedWallet != null) return 'Pay with ${_selectedWallet!.label}';
    return 'Activate Premium';
  }

  String _footnote() {
    if (_method == _PayMethod.store && _useStore) {
      return 'Subscriptions are managed by ${defaultTargetPlatform == TargetPlatform.iOS ? 'Apple' : 'Google'}.';
    }
    if (_selectedWallet != null) {
      return 'You will complete payment in ${_selectedWallet!.label}, then return here.';
    }
    return 'Dev mode — no real charge.';
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.accent,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = TextStyle(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: accent ?? t.text,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? t.premiumText : t.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18, color: t.premiumText),
          ],
        ),
      ),
    );
  }
}
