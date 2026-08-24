import 'package:flutter/material.dart';

/// Compact brand marks for checkout.
///
/// Card stays painted; GCash / Maya use the provided logo assets.
/// All marks share [slotWidth] so row labels line up.
class PaymentMark extends StatelessWidget {
  const PaymentMark.card({super.key}) : kind = _Kind.card;
  const PaymentMark.gcash({super.key}) : kind = _Kind.gcash;
  const PaymentMark.maya({super.key}) : kind = _Kind.maya;

  final _Kind kind;

  /// Square height for circular / card marks.
  static const double size = 36;

  /// Shared leading column so G / M / card start on the same x, and labels align.
  static const double slotWidth = 44;

  @override
  Widget build(BuildContext context) {
    final child = switch (kind) {
      _Kind.card => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: const _CardMarkPainter()),
        ),
      _Kind.gcash => const _AssetMark(
          asset: 'assets/payments/gcash.png',
          width: size,
          height: size,
        ),
      // Wordmark: left-align with GCash's G, and fill most of the slot so the
      // green "maya" reads at a similar weight to the round G mark.
      _Kind.maya => const _AssetMark(
          asset: 'assets/payments/maya.png',
          width: slotWidth,
          height: size * 0.92,
          alignment: Alignment.centerLeft,
        ),
    };

    return SizedBox(
      width: slotWidth,
      height: size,
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

enum _Kind { card, gcash, maya }

class _AssetMark extends StatelessWidget {
  const _AssetMark({
    required this.asset,
    required this.width,
    required this.height,
    this.alignment = Alignment.center,
  });

  final String asset;
  final double width;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: alignment,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.payments_outlined, size: 18),
      ),
    );
  }
}

class _CardMarkPainter extends CustomPainter {
  const _CardMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(9),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3A6B), Color(0xFF2F6FED)],
        ).createShader(Offset.zero & size),
    );
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.16, size.height * 0.28, size.width * 0.68,
          size.height * 0.48),
      const Radius.circular(3),
    );
    canvas.drawRRect(card, Paint()..color = const Color(0xFFE8EEF8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.22, size.height * 0.40, size.width * 0.16,
            size.height * 0.14),
        const Radius.circular(1.4),
      ),
      Paint()..color = const Color(0xFFE0B84A),
    );
    final dots = Paint()..color = const Color(0xFF1B3A6B).withValues(alpha: 0.45);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.46 + i * 0.08), size.height * 0.47),
        1.15,
        dots,
      );
    }
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.64),
      size.width * 0.07,
      Paint()..color = const Color(0xFFE8A317),
    );
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.64),
      size.width * 0.07,
      Paint()..color = const Color(0xFFD94A3D).withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
