import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/settings/billing_plan.dart';

/// Pricing arithmetic and plan labelling. These numbers are shown next to a
/// pay button, so being wrong is worse than being ugly.
void main() {
  group('prices', () {
    test('the app and the worker agree on the amounts', () {
      // worker/src/billing.ts PLAN_AMOUNTS_CENTAVOS must match these, or the
      // sheet quotes one price and PayMongo charges another.
      expect(kMonthlyPricePhp * 100, 19900);
      expect(kYearlyPricePhp * 100, 149900);
    });

    test('priceForPlan matches the constants', () {
      expect(priceForPlan(BillingPlan.monthly), kMonthlyPricePhp);
      expect(priceForPlan(BillingPlan.yearly), kYearlyPricePhp);
    });

    test('free and lifetime cost nothing to charge', () {
      expect(priceForPlan(BillingPlan.none), 0);
      expect(priceForPlan(BillingPlan.lifetime), 0);
    });

    test('yearly is cheaper than twelve months', () {
      expect(kYearlyPricePhp, lessThan(kMonthlyPricePhp * 12));
    });
  });

  group('savings', () {
    test('the advertised saving is the real one', () {
      final full = kMonthlyPricePhp * 12;
      final expected = (((full - kYearlyPricePhp) / full) * 100).round();
      expect(yearlySavingsPercent(), expected);
    });

    test('the saving is plausible, not a rounding artefact', () {
      expect(yearlySavingsPercent(), greaterThan(0));
      expect(yearlySavingsPercent(), lessThan(100));
    });

    test('the label states the percentage', () {
      expect(
        yearlySavingsLabel(),
        contains('${yearlySavingsPercent()}%'),
      );
    });
  });

  group('student pricing', () {
    test('the student rate is 20% off monthly', () {
      expect(kStudentMonthlyPhp, closeTo(kMonthlyPricePhp * 0.8, 0.001));
    });

    test('the student rate stays above PayMongo\'s minimum charge', () {
      // PayMongo rejects anything under PHP 20.
      expect(kStudentMonthlyPhp, greaterThanOrEqualTo(20));
    });
  });

  group('formatting', () {
    test('amounts render as pesos', () {
      expect(formatPhp(199), contains('199'));
      expect(formatPhp(199), contains('₱'));
    });

    test('price labels carry their period', () {
      expect(monthlyPriceLabel(), endsWith('/mo'));
      expect(yearlyPriceLabel(), endsWith('/yr'));
    });

    test('every plan has a label', () {
      for (final plan in BillingPlan.values) {
        expect(billingPlanLabel(plan), isNotEmpty, reason: '$plan');
      }
    });

    test('plan labels are distinguishable', () {
      final labels =
          BillingPlan.values.map(billingPlanLabel).toSet();
      expect(labels.length, BillingPlan.values.length);
    });
  });

  group('BillingPlan parsing', () {
    /// The worker sends plan names as strings; asNameMap is what turns them
    /// back into the enum on the way in.
    test('names round-trip through asNameMap', () {
      final byName = BillingPlan.values.asNameMap();
      expect(byName['monthly'], BillingPlan.monthly);
      expect(byName['yearly'], BillingPlan.yearly);
      expect(byName['lifetime'], BillingPlan.lifetime);
      expect(byName['none'], BillingPlan.none);
      expect(byName['bogus'], isNull);
    });
  });
}
