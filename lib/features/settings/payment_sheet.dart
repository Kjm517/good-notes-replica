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
import 'payment_marks.dart';
import 'paymongo_billing.dart';
import 'premium_providers.dart';
import 'qr_checkout_screen.dart';
import 'revenuecat_billing.dart';
import 'settings_widgets.dart';
import '../admin/voucher_api.dart';

enum _PayMethod { store, card, gcash, maya, qrph }

/// Channels PayMongo has not activated on this merchant account yet.
///
/// Offering them only produces "payment method is not allowed" at checkout,
/// which reads like a broken app. QR Ph covers the same payers — GCash, Maya
/// and every major bank app scan it — so nothing is lost by hiding these
/// until the dashboard enables them. Flip to false per method to restore.
const _showCardOption = false;
const _showWalletOptions = false;

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
    final applied = _appliedVoucher;
    if (applied == null || !applied.valid) return 0;
    if (!walletCheckout && _useStore) return 0;
    if (applied.discountKind == 'amount') {
      final pesos = (applied.discountAmountCentavos ?? 0) / 100.0;
      if (pesos <= 0) return 0;
      return pesos.clamp(0, _subtotal);
    }
    final rate = applied.discountRate;
    if (rate == null) return 0;
    return _subtotal * rate;
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
    if (!mounted) return;
    // Keep the code for checkout, but don't leave it sitting in the field.
    _voucher.clear();
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
      if (!result.valid ||
          (result.discountRate == null &&
              (result.discountAmountCentavos ?? 0) <= 0)) {
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
          const SnackBar(content: Text('Promo applied.')),
        );
      }
    } finally {
      if (mounted) setState(() => _validatingVoucher = false);
    }
  }

  PayMongoMethod? get _selectedPayMongo => switch (_method) {
        _PayMethod.card => PayMongoMethod.card,
        _PayMethod.gcash => PayMongoMethod.gcash,
        _PayMethod.maya => PayMongoMethod.paymaya,
        _PayMethod.qrph => PayMongoMethod.qrph,
        _ => null,
      };

  Future<void> _subscribe() async {
    setState(() => _processing = true);
    try {
      if (_method == _PayMethod.store && _useStore) {
        await _subscribeViaStore();
      } else if (_selectedPayMongo != null && _useWallets) {
        await _subscribeViaPayMongo(_selectedPayMongo!);
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
        SnackBar(
          content: Text(_readableError(e)),
          duration: const Duration(seconds: 8),
        ),
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

  Future<void> _subscribeViaPayMongo(PayMongoMethod method) async {
    final billing = ref.read(payMongoBillingServiceProvider);
    if (billing == null) {
      throw StateError('Sign in to pay with ${method.label}.');
    }

    final checkout = await billing.createCheckout(
      plan: widget.plan,
      method: method,
      voucher: _appliedVoucher?.valid == true ? _appliedVoucher!.code : null,
    );
    if (checkout.granted) {
      await ref.read(payMongoEntitlementRefreshProvider)();
      if (!mounted) return;
      _finish('Premium activated — enjoy unlimited quizzes!');
      return;
    }
    final pendingId = checkout.paymentIntentId;
    if (pendingId != null && pendingId.isNotEmpty) {
      await billing.markPendingCheckout(pendingId);
    }

    // QR Ph returns a code to display rather than a page to open.
    final qrImage = checkout.qrImageUrl;
    if (qrImage != null && qrImage.isNotEmpty) {
      if (pendingId == null || pendingId.isEmpty) {
        throw StateError('Checkout did not return a payment reference.');
      }
      if (!mounted) return;
      // The scan screen polls the worker and, on success, refreshes
      // entitlement and routes to Settings itself.
      await QrCheckoutScreen.show(
        context,
        plan: widget.plan,
        method: method,
        amountPhp: _subtotal - _discount(true),
        qrImageUrl: qrImage,
        paymentIntentId: pendingId,
      );
      return;
    }

    final redirect = checkout.redirectUrl;
    if (redirect == null || redirect.isEmpty) {
      throw StateError('Checkout did not return a payment URL.');
    }

    final uri = Uri.parse(redirect);
    final launched = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!launched) {
      throw StateError('Could not open ${method.label} checkout.');
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb
              ? 'Complete payment, then return to Notably.'
              : 'Complete payment — you\'ll be brought back to Notably automatically.',
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
        _method = _showCardOption ? _PayMethod.card : _PayMethod.qrph;
      }
    }
    final t = context.tokens;
    final walletCheckout = _selectedPayMongo != null;
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
                    label: 'Discount',
                    value: '-${formatPhp(_discount(walletCheckout))}',
                    accent: t.success,
                  ),
                if (walletCheckout || !_useStore) ...[
                  Divider(height: 20, color: t.line),
                  _PriceRow(
                    label: 'Total',
                    value: formatPhp(due),
                    bold: true,
                  ),
                ],
              ],
            ),
          ),
          if (_useWallets || (!_useStore && !_useWallets)) ...[
            const SizedBox(height: 10),
            _PromoCodeField(
              controller: _voucher,
              validating: _validatingVoucher,
              onChanged: () => setState(() => _appliedVoucher = null),
              onClear: _clearVoucher,
              onApply: () => _applyVoucher(),
            ),
          ],
          const SizedBox(height: 18),
          Text('Payment method', style: AppTokens.sectionLabel(t.textFaint)),
          const SizedBox(height: 8),
          SettingsGroupCard(
            children: [
              if (_useStore)
                _PayRow(
                  leading: SizedBox(
                    width: PaymentMark.slotWidth,
                    height: PaymentMark.size,
                    child: Center(
                      child: Icon(
                        Icons.store_rounded,
                        size: 22,
                        color: _method == _PayMethod.store
                            ? t.premiumText
                            : t.textMuted,
                      ),
                    ),
                  ),
                  label: defaultTargetPlatform == TargetPlatform.iOS
                      ? 'App Store'
                      : 'Google Play',
                  subtitle: 'Card · trial eligible',
                  selected: _method == _PayMethod.store,
                  onTap: () => setState(() => _method = _PayMethod.store),
                ),
              if (_useWallets) ...[
                if (_showCardOption)
                  _PayRow(
                    leading: const PaymentMark.card(),
                    label: 'Debit / Credit card',
                    subtitle: PayMongoMethod.card.subtitle,
                    selected: _method == _PayMethod.card,
                    onTap: () => setState(() => _method = _PayMethod.card),
                  ),
                if (_showWalletOptions) ...[
                  _PayRow(
                    leading: const PaymentMark.gcash(),
                    label: 'GCash',
                    selected: _method == _PayMethod.gcash,
                    onTap: () => setState(() => _method = _PayMethod.gcash),
                  ),
                  _PayRow(
                    leading: const PaymentMark.maya(),
                    label: 'Maya',
                    selected: _method == _PayMethod.maya,
                    onTap: () => setState(() => _method = _PayMethod.maya),
                  ),
                ],
                _PayRow(
                  leading: SizedBox(
                    width: PaymentMark.slotWidth,
                    height: PaymentMark.size,
                    child: Center(
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        size: 22,
                        color: _method == _PayMethod.qrph
                            ? t.premiumText
                            : t.textMuted,
                      ),
                    ),
                  ),
                  label: 'QR Ph',
                  subtitle: 'Scan with GCash, Maya, or any bank app',
                  selected: _method == _PayMethod.qrph,
                  onTap: () => setState(() => _method = _PayMethod.qrph),
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

  /// Turns PayMongo's wording into something the user can act on.
  ///
  /// "payment method is not allowed" means the channel is not switched on for
  /// the merchant account — nothing the payer did, and nothing retrying fixes.
  String _readableError(Object e) {
    final raw = e.toString().replaceFirst('Bad state: ', '');
    final lower = raw.toLowerCase();

    if (lower.contains('not allowed') || lower.contains('not enabled')) {
      final method = _selectedPayMongo?.label ?? 'That method';
      return '$method is not switched on for this account yet. '
          'Try another payment method.';
    }
    if (lower.contains('sign in')) {
      return 'Sign in to pay.';
    }
    if (lower.contains('not configured')) {
      return 'Payments are not set up on the server yet.';
    }
    return raw;
  }

  String _buttonLabel() {
    if (_method == _PayMethod.store && _useStore) return 'Start free trial';
    if (_method == _PayMethod.qrph) return 'Show QR code';
    if (_selectedPayMongo != null) {
      return _selectedPayMongo == PayMongoMethod.card
          ? 'Pay with card'
          : 'Pay with ${_selectedPayMongo!.label}';
    }
    return 'Activate Premium';
  }

  String _footnote() {
    if (_method == _PayMethod.qrph) {
      return 'Scan with your phone. Premium unlocks by itself once PayMongo '
          'confirms the payment.';
    }
    if (kIsWeb) {
      return 'Pay with QR Ph — scan from GCash, Maya, or your bank app.';
    }
    if (_method == _PayMethod.store && _useStore) {
      return 'Subscriptions are managed by ${defaultTargetPlatform == TargetPlatform.iOS ? 'Apple' : 'Google'}.';
    }
    if (_selectedPayMongo != null) {
      return _selectedPayMongo == PayMongoMethod.card
          ? 'You will enter card details on a secure page, then return here.'
          : 'You will complete payment in ${_selectedPayMongo!.label}, then return here.';
    }
    return 'Dev mode — no real charge.';
  }
}

class _PromoCodeField extends StatefulWidget {
  const _PromoCodeField({
    required this.controller,
    required this.validating,
    required this.onChanged,
    required this.onClear,
    required this.onApply,
  });

  final TextEditingController controller;
  final bool validating;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  State<_PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends State<_PromoCodeField> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => _open = true),
          child: const Text('Have a promo code?'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Promo code', style: AppTokens.sectionLabel(t.textFaint)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: 'Enter code',
                  suffixIcon: widget.controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: widget.onClear,
                        ),
                ),
                onChanged: (_) => widget.onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: widget.validating ? null : widget.onApply,
              child: widget.validating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply'),
            ),
          ],
        ),
      ],
    );
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
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
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
            leading,
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
                  if (subtitle != null && subtitle!.isNotEmpty)
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
