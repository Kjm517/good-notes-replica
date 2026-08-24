import 'billing_plan.dart';

/// Public voucher codes (mirrored in worker `DEFAULT_STORE` on first deploy).
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

String studentPricingHint() =>
    'Students with a .edu email get ${formatPhp(kStudentMonthlyPhp)}/mo automatically '
    '(or use $kStudentVoucherCode).';

String launchPricingHint() =>
    'Early adopters: use $kLaunchVoucherCode for ${formatPhp(kLaunchMonthlyPhp)} '
    'your first month (GCash & Maya).';

String freeTierSummary() =>
    '5 GB storage · AI quizzes unlock with Premium or trial';

String premiumTierSummary() =>
    'Unlimited AI quizzes · quiz history · cloud sync · 15 GB storage';
