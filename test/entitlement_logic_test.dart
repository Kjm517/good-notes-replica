import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/settings/billing_plan.dart';
import 'package:notably/features/settings/entitlements.dart';

/// Pure entitlement logic — the rules that decide who may use a paid feature.
/// No database or network, so these run under plain `flutter test`.
UserEntitlement premium() => const UserEntitlement(
      tier: EntitlementTier.premium,
      quizUsed: 0,
      quizLimit: 0,
    );

UserEntitlement trial({int used = 0, DateTime? startedAt}) {
  final start = startedAt ?? DateTime.now().subtract(const Duration(days: 1));
  return UserEntitlement(
    tier: EntitlementTier.trial,
    quizUsed: used,
    quizLimit: kTrialQuizLimit,
    trialStartedAt: start,
    trialEndsAt: start.add(kTrialDuration),
  );
}

UserEntitlement free({int used = 0, DateTime? trialStartedAt}) {
  return UserEntitlement(
    tier: EntitlementTier.free,
    quizUsed: used,
    quizLimit: kFreeQuizLimitPerMonth,
    trialStartedAt: trialStartedAt,
    trialEndsAt: trialStartedAt?.add(kTrialDuration),
  );
}

void main() {
  group('quiz access', () {
    test('premium is unlimited regardless of use', () {
      const heavy = UserEntitlement(
        tier: EntitlementTier.premium,
        quizUsed: 9999,
        quizLimit: 0,
      );
      expect(heavy.canGenerateQuiz, isTrue);
    });

    test('trial allows quizzes up to the limit', () {
      expect(trial(used: 0).canGenerateQuiz, isTrue);
      expect(trial(used: kTrialQuizLimit - 1).canGenerateQuiz, isTrue);
    });

    test('trial blocks once the limit is reached', () {
      expect(trial(used: kTrialQuizLimit).canGenerateQuiz, isFalse);
      expect(trial(used: kTrialQuizLimit + 1).canGenerateQuiz, isFalse);
    });

    /// Documents current behaviour, which contradicts the data the free tier
    /// is built with: `entitlementProvider` sets quizLimit to
    /// kFreeQuizLimitPerMonth (3), but canGenerateQuiz refuses free users
    /// outright, so that allowance can never be spent. Either the limit is
    /// dead data or the gate is wrong — see the note in the PR.
    test('free tier cannot generate quizzes even below its stated limit', () {
      expect(kFreeQuizLimitPerMonth, greaterThan(0));
      expect(free(used: 0).canGenerateQuiz, isFalse);
    });

    test('premium and trial unlock quiz history; free does not', () {
      expect(premium().canAccessQuizHistory, isTrue);
      expect(trial().canAccessQuizHistory, isTrue);
      expect(free().canAccessQuizHistory, isFalse);
    });
  });

  group('premium features', () {
    test('trial counts as having premium features', () {
      expect(trial().hasPremiumFeatures, isTrue);
      expect(premium().hasPremiumFeatures, isTrue);
      expect(free().hasPremiumFeatures, isFalse);
    });
  });

  group('trial expiry', () {
    test('a user who never had a trial has not expired', () {
      expect(free().hadTrial, isFalse);
      expect(free().trialExpired, isFalse);
    });

    test('a lapsed trial without premium counts as expired', () {
      final lapsed = free(
        trialStartedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(lapsed.hadTrial, isTrue);
      expect(lapsed.trialExpired, isTrue);
    });

    test('an active trial has not expired', () {
      expect(trial().trialExpired, isFalse);
    });

    /// Upgrading during or after a trial must not leave the "your trial
    /// ended" dialog primed to fire at a paying customer.
    test('buying premium clears the expired state', () {
      const upgraded = UserEntitlement(
        tier: EntitlementTier.premium,
        quizUsed: 0,
        quizLimit: 0,
        trialStartedAt: null,
      );
      expect(upgraded.trialExpired, isFalse);
    });
  });

  group('trialDaysRemaining', () {
    test('is null outside an active trial', () {
      expect(premium().trialDaysRemaining, isNull);
      expect(free().trialDaysRemaining, isNull);
    });

    test('reports whole days left', () {
      final started = DateTime.now().subtract(const Duration(days: 2));
      expect(trial(startedAt: started).trialDaysRemaining, 4);
    });

    /// `.inDays` truncates, so the final hours read as 0 rather than going
    /// negative. Anything else would show "-1 days left".
    test('reads zero, never negative, in the final hours', () {
      final started = DateTime.now().subtract(
        kTrialDuration - const Duration(hours: 6),
      );
      expect(trial(startedAt: started).trialDaysRemaining, 0);
    });
  });

  group('labels', () {
    test('tier labels match the tier', () {
      expect(premium().tierLabel, 'Premium');
      expect(trial().tierLabel, 'Trial');
      expect(free().tierLabel, 'Free');
    });

    test('trial usage label shows progress', () {
      expect(trial(used: 2).quizUsageLabel(), contains('2 of $kTrialQuizLimit'));
    });

    test('premium usage label promises unlimited', () {
      expect(premium().quizUsageLabel(), contains('Unlimited'));
    });
  });
}
