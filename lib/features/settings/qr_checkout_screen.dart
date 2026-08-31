import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/design.dart';
import 'billing_plan.dart';
import 'paymongo_billing.dart';

/// How often we ask the worker whether the intent has been paid.
///
/// The global entitlement poll ([payMongoSyncProvider]) runs every 12s, which
/// is fine in the background but feels broken while someone is staring at a
/// QR code waiting for it to clear.
const _pollInterval = Duration(seconds: 3);

/// How long the QR stays live before we stop polling and offer a retry.
const _window = Duration(minutes: 15);

/// Full-screen "scan this to pay" step.
///
/// Nothing here asks the user to confirm anything: the screen polls
/// `GET /billing/status`, and the worker decides — from PayMongo — whether the
/// intent is paid. When it is, premium is already granted server-side and this
/// screen refreshes entitlement and lands the user on Settings.
class QrCheckoutScreen extends ConsumerStatefulWidget {
  const QrCheckoutScreen({
    super.key,
    required this.plan,
    required this.method,
    required this.amountPhp,
    required this.paymentIntentId,
    this.redirectUrl,
    this.qrImageUrl,
  }) : assert(
          redirectUrl != null || qrImageUrl != null,
          'Need something to show: a URL to encode or a QR image.',
        );

  final BillingPlan plan;
  final PayMongoMethod method;
  final double amountPhp;

  /// Wallet methods: PayMongo's hosted payment page, which this screen encodes
  /// into a QR so a second device can open it.
  final String? redirectUrl;

  /// QR Ph: a base64 data URI PayMongo generated. Displayed as-is — it encodes
  /// the national QR Ph payload, which we must not re-encode ourselves.
  final String? qrImageUrl;

  final String paymentIntentId;

  static Future<void> show(
    BuildContext context, {
    required BillingPlan plan,
    required PayMongoMethod method,
    required double amountPhp,
    required String paymentIntentId,
    String? redirectUrl,
    String? qrImageUrl,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => QrCheckoutScreen(
          plan: plan,
          method: method,
          amountPhp: amountPhp,
          paymentIntentId: paymentIntentId,
          redirectUrl: redirectUrl,
          qrImageUrl: qrImageUrl,
        ),
      ),
    );
  }

  @override
  ConsumerState<QrCheckoutScreen> createState() => _QrCheckoutScreenState();
}

class _QrCheckoutScreenState extends ConsumerState<QrCheckoutScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  var _elapsed = Duration.zero;
  var _polling = false;
  var _settled = false;
  String? _error;
  PayMongoPaymentStatus _status = PayMongoPaymentStatus.pending;

  bool get _expired => _elapsed >= _window;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Paying on the same phone means leaving the app. Check the moment we are
    // back rather than waiting out the rest of the interval.
    if (state == AppLifecycleState.resumed) unawaited(_poll());
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _elapsed = Duration.zero;
      _error = null;
      _status = PayMongoPaymentStatus.pending;
    });
    _timer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      setState(() => _elapsed += _pollInterval);
      if (_expired) {
        _timer?.cancel();
        return;
      }
      unawaited(_poll());
    });
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_polling || _settled || !mounted) return;
    final billing = ref.read(payMongoBillingServiceProvider);
    if (billing == null) return;

    _polling = true;
    try {
      final result = await billing.fetchPaymentStatus(widget.paymentIntentId);
      if (!mounted) return;
      setState(() {
        _error = null;
        // `unknown` is a transient answer — keep showing "waiting" for it.
        if (result.status != PayMongoPaymentStatus.unknown) {
          _status = result.status;
        }
      });
      if (result.isPaid) {
        await _onPaid(billing);
      } else if (result.status == PayMongoPaymentStatus.failed) {
        _timer?.cancel();
      }
    } catch (e) {
      // A dropped request must not look like a failed payment.
      if (mounted) setState(() => _error = '$e');
    } finally {
      _polling = false;
    }
  }

  Future<void> _onPaid(PayMongoBillingService billing) async {
    if (_settled) return;
    _settled = true;
    _timer?.cancel();

    // Premium is already written server-side; pull it into local state so the
    // Settings badge is correct the instant we land there.
    await ref.read(payMongoEntitlementRefreshProvider)();
    await billing.clearPendingCheckout();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    // Grab the router before popping — this screen's context is defunct the
    // moment its route is gone.
    final router = GoRouter.of(context);
    // Close the QR screen and the payment sheet under it, then land on
    // Settings regardless of where checkout was started from.
    Navigator.of(context).popUntil((route) => route.isFirst);
    router.go('/settings');
    messenger?.showSnackBar(
      const SnackBar(content: Text('Payment received — Premium is active.')),
    );
  }

  String get _remaining {
    final left = _window - _elapsed;
    final seconds = left.isNegative ? 0 : left.inSeconds;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final failed = _status == PayMongoPaymentStatus.failed;

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: Text('Pay with ${widget.method.label}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Text(
            'Scan to pay',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.qrImageUrl != null
                ? 'Scan with GCash, Maya, or any bank app that supports QR Ph. '
                    'This screen updates on its own once payment clears.'
                : 'Open ${widget.method.label} or your camera and scan this '
                    'code. This screen updates on its own once payment clears.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Deliberately not a token: scanners need a light quiet zone
                // and true-black modules, in dark mode as well.
                color: Colors.white,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: t.line),
              ),
              child: _QrCode(
                redirectUrl: widget.redirectUrl,
                qrImageUrl: widget.qrImageUrl,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              formatPhp(widget.amountPhp),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              widget.plan == BillingPlan.yearly
                  ? 'Premium — Yearly'
                  : 'Premium — Monthly',
              style: AppTokens.mono(size: 10, color: t.textFaint),
            ),
          ),
          const SizedBox(height: 14),
          _QrActions(
            qrImageUrl: widget.qrImageUrl,
            redirectUrl: widget.redirectUrl,
            plan: widget.plan,
            amountPhp: widget.amountPhp,
          ),
          const SizedBox(height: 18),
          _StatusStrip(
            failed: failed,
            expired: _expired,
            remaining: _remaining,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              'Still checking — connection problem. ($_error)',
              textAlign: TextAlign.center,
              style: AppTokens.mono(size: 10, color: t.textFaint),
            ),
          ],
          if (failed || _expired) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Back to payment methods'),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Keep this open until it confirms. Nothing is charged twice if you '
            'scan again.',
            textAlign: TextAlign.center,
            style: AppTokens.mono(size: 10, color: t.textFaint),
          ),
        ],
      ),
    );
  }
}

/// Either PayMongo's own QR Ph image, or a QR we generate from a checkout URL.
/// Either PayMongo's own QR Ph image, or a QR we generate from a checkout URL.
///
/// Stateful so the decoded bytes survive rebuilds: the countdown ticks every
/// few seconds, and decoding afresh each time handed `Image.memory` a new
/// Uint8List, which re-decoded and made the code visibly blink.
class _QrCode extends StatefulWidget {
  const _QrCode({this.redirectUrl, this.qrImageUrl});

  final String? redirectUrl;
  final String? qrImageUrl;

  /// Pulls the bytes out of a `data:image/png;base64,...` URI.
  static Uint8List? decodeDataUri(String value) {
    if (!value.startsWith('data:')) return null;
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  State<_QrCode> createState() => _QrCodeState();
}

class _QrCodeState extends State<_QrCode> {
  static const _size = 232.0;

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_QrCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-decode when the code itself actually changed.
    if (oldWidget.qrImageUrl != widget.qrImageUrl) _decode();
  }

  void _decode() {
    final data = widget.qrImageUrl;
    _bytes = data == null ? null : _QrCode.decodeDataUri(data);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.qrImageUrl;

    // RepaintBoundary keeps the surrounding countdown repaints off the code.
    return RepaintBoundary(
      child: switch ((data, _bytes)) {
        (null, _) => QrImageView(
            data: widget.redirectUrl!,
            version: QrVersions.auto,
            size: _size,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        (_, final bytes?) => Image.memory(
            bytes,
            width: _size,
            height: _size,
            // Without this the image fades in again on every rebuild.
            gaplessPlayback: true,
          ),
        // PayMongo can also hand back a hosted image URL.
        (final url?, _) => Image.network(url, width: _size, height: _size),
      },
    );
  }
}

/// Save or copy the code, so someone can pay from a different device or come
/// back to it after leaving this screen.
class _QrActions extends StatelessWidget {
  const _QrActions({
    required this.qrImageUrl,
    required this.redirectUrl,
    required this.plan,
    required this.amountPhp,
  });

  final String? qrImageUrl;
  final String? redirectUrl;
  final BillingPlan plan;
  final double amountPhp;

  Future<void> _saveImage(BuildContext context) async {
    final data = qrImageUrl;
    if (data == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);

    final bytes = _QrCode.decodeDataUri(data);
    if (bytes == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('This code cannot be saved.')),
      );
      return;
    }

    try {
      // Written to a temp file first: the share sheet is what offers "Save to
      // Photos", and it needs a real file rather than raw bytes.
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/notably-qr-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Notably Premium — ${formatPhp(amountPhp)}. '
              'Scan with GCash, Maya, or any bank app.',
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    final link = redirectUrl;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasImage = qrImageUrl != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasImage)
          OutlinedButton.icon(
            onPressed: () => _saveImage(context),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Save QR'),
            style: OutlinedButton.styleFrom(foregroundColor: t.textSecondary),
          ),
        if (redirectUrl != null) ...[
          if (hasImage) const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _copyLink(context),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Copy link'),
            style: OutlinedButton.styleFrom(foregroundColor: t.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.failed,
    required this.expired,
    required this.remaining,
  });

  final bool failed;
  final bool expired;
  final String remaining;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final (Widget leading, String label, Color color) = switch ((
      failed,
      expired,
    )) {
      (true, _) => (
          Icon(Icons.error_outline_rounded, size: 18, color: t.textMuted),
          'Payment was cancelled or declined.',
          t.textMuted,
        ),
      (_, true) => (
          Icon(Icons.timer_off_rounded, size: 18, color: t.textMuted),
          'This code expired. Start again to get a new one.',
          t.textMuted,
        ),
      _ => (
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.premium),
          ),
          'Waiting for payment · $remaining',
          t.textMuted,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
