import 'package:intl/intl.dart';

/// Premium plan prices in Philippine Peso (display + PayMongo fallback).
///
/// Store billing (Play / App Store) should use matching products in PHP in
/// RevenueCat — these labels are shown on web and whenever store prices are
/// unavailable.
const kMonthlyPricePhp = 199.0;
const kYearlyPricePhp = 1499.0;

final _phpFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

String formatPhp(double amount) => _phpFormat.format(amount);

String yearlyPriceLabel() => '${formatPhp(kYearlyPricePhp)}/yr';

String monthlyPriceLabel() => '${formatPhp(kMonthlyPricePhp)}/mo';

/// Rounded “Save X% vs monthly” for the yearly plan card.
int yearlySavingsPercent() {
  final fullYear = kMonthlyPricePhp * 12;
  if (fullYear <= 0) return 0;
  return (((fullYear - kYearlyPricePhp) / fullYear) * 100).round();
}

String yearlySavingsLabel() => 'Save ${yearlySavingsPercent()}% vs monthly';

/// Student promo at 20% off monthly (see default `STUDENT20` voucher).
double get kStudentMonthlyPhp => kMonthlyPricePhp * 0.8;

double priceForPlan(BillingPlan plan) => switch (plan) {
      BillingPlan.yearly => kYearlyPricePhp,
      BillingPlan.monthly => kMonthlyPricePhp,
      BillingPlan.lifetime || BillingPlan.none => 0,
    };

enum BillingPlan { none, monthly, yearly, lifetime }

const kFreeQuizLimitPerMonth = 3;
