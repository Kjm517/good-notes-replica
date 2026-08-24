import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/settings/billing_ladder.dart';
import 'package:notably/features/settings/billing_plan.dart';

void main() {
  group('billing ladder', () {
    test('student email domains qualify', () {
      expect(qualifiesForStudentPricing('alice@stanford.edu'), isTrue);
      expect(qualifiesForStudentPricing('bob@up.edu.ph'), isTrue);
      expect(qualifiesForStudentPricing('carol@dlsu.edu.ph'), isTrue);
      expect(qualifiesForStudentPricing('dan@example.com'), isFalse);
      expect(qualifiesForStudentPricing(null), isFalse);
    });

    test('student monthly price is 20% off standard', () {
      expect(kStudentMonthlyPhp, closeTo(kMonthlyPricePhp * 0.8, 0.01));
    });

    test('launch discount yields ₱99 on monthly plan', () {
      final discounted = kMonthlyPricePhp * (1 - kLaunchDiscountRate);
      expect(discounted, closeTo(kLaunchMonthlyPhp, 0.01));
    });

    test('yearly saves vs twelve monthly payments', () {
      expect(yearlySavingsPercent(), greaterThan(30));
      expect(kYearlyPricePhp, lessThan(kMonthlyPricePhp * 12));
    });
  });
}
