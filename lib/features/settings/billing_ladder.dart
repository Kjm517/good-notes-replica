import 'billing_plan.dart';

/// Promo codes for PayMongo checkout (card, GCash, Maya).
///
/// Stored on the worker and managed from `/admin/vouchers`. These constants
/// are the defaults on first deploy — they are not shown in customer UI.
const kStudentVoucherCode = 'STUDENT20';
const kLaunchVoucherCode = 'LAUNCH99';

const kStudentDiscountRate = 0.2;

/// Launch promo: first month at ₱99 (monthly plan only via PayMongo).
const kLaunchMonthlyPhp = 99.0;

/// Exact fraction off [kMonthlyPricePhp] that yields [kLaunchMonthlyPhp].
const kLaunchDiscountRate = 1 - kLaunchMonthlyPhp / kMonthlyPricePhp;

/// Approximate monthly equivalent when paying yearly.
double get kYearlyEffectiveMonthlyPhp => kYearlyPricePhp / 12;

/// True for common student / school email domains in PH and abroad.
bool qualifiesForStudentPricing(String? email) {
  if (email == null || email.trim().isEmpty) return false;
  final lower = email.trim().toLowerCase();
  const suffixes = ['.edu', '.edu.ph', '.ac.ph'];
  return suffixes.any((s) => lower.endsWith(s));
}
