import 'billing_plan.dart';

/// Promo / voucher codes for GCash & Maya checkout (PayMongo).
///
/// Codes are stored on the worker (R2) and managed from `/admin/vouchers`.
/// Defaults: [kStudentVoucherCode], [kLaunchVoucherCode] — see [billing_ladder.dart].
export 'billing_ladder.dart'
    show
        kStudentVoucherCode,
        kLaunchVoucherCode,
        kStudentDiscountRate,
        kLaunchMonthlyPhp,
        qualifiesForStudentPricing;

class BillingVoucher {
  const BillingVoucher({
    required this.code,
    required this.discountRate,
    this.label,
  });

  final String code;
  /// Fraction off the plan price, e.g. `0.2` = 20% off.
  final double discountRate;
  final String? label;
}
