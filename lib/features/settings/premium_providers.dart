import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/pricing.dart';
import '../../app/providers.dart';
import '../../core/ai/ai_providers.dart';
import '../../core/storage/storage_quota.dart';

/// Billing tier — stub until StoreKit / Play Billing is wired.
enum BillingPlan { none, monthly, yearly }

const kFreeQuizLimitPerMonth = AppPricing.freeQuizLimit;

const _planKey = 'billing_plan';
const _renewKey = 'premium_renews_at';
const _trialKey = 'premium_trial_active';

final storageQuotaBytesProvider = Provider<int>((ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (!isPremium) return kFreeStorageQuotaBytes;
  final trial =
      ref.watch(sharedPrefsProvider).getBool(_trialKey) ?? false;
  return trial ? kFreeStorageQuotaBytes : kPremiumStorageQuotaBytes;
});

final billingPlanProvider =
    NotifierProvider<BillingPlanController, BillingPlan>(
  BillingPlanController.new,
);

class BillingPlanController extends Notifier<BillingPlan> {
  @override
  BillingPlan build() {
    final prefs = ref.watch(sharedPrefsProvider);
    if (prefs.getBool('is_premium') ?? false) {
      final raw = prefs.getString(_planKey);
      return switch (raw) {
        'monthly' => BillingPlan.monthly,
        'yearly' => BillingPlan.yearly,
        _ => BillingPlan.yearly,
      };
    }
    return BillingPlan.none;
  }

  Future<void> activate(BillingPlan plan) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('is_premium', true);
    await prefs.setString(_planKey, plan.name);
    await prefs.setBool(_trialKey, true);
    final renew = DateTime.now().add(const Duration(days: AppPricing.freeTrialDays));
    await prefs.setString(_renewKey, renew.toIso8601String());
    ref.invalidateSelf();
    ref.invalidate(isPremiumProvider);
    ref.invalidate(isPremiumTrialProvider);
    ref.invalidate(hasUnlimitedAiQuizzesProvider);
    ref.invalidate(quizLimitReachedProvider);
    ref.invalidate(storageQuotaBytesProvider);
    ref.invalidate(monthlyQuizUsageProvider);
  }

  Future<void> restore() async {
    // Stub: real IAP restore goes here.
    final prefs = ref.read(sharedPrefsProvider);
    if (prefs.getBool('is_premium') ?? false) return;
  }
}

final premiumRenewsAtProvider = Provider<DateTime?>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  if (!(prefs.getBool('is_premium') ?? false)) return null;
  final raw = prefs.getString(_renewKey);
  if (raw == null) return null;
  return DateTime.tryParse(raw);
});

/// True while the 7-day premium trial is active (still quota-limited).
final isPremiumTrialProvider = Provider<bool>((ref) {
  if (!ref.watch(isPremiumProvider)) return false;
  return ref.watch(sharedPrefsProvider).getBool(_trialKey) ?? false;
});

/// Paid premium (trial finished / converted) gets unlimited AI quizzes.
final hasUnlimitedAiQuizzesProvider = Provider<bool>((ref) {
  return ref.watch(isPremiumProvider) && !ref.watch(isPremiumTrialProvider);
});

/// True when free / trial allotment is exhausted — quiz icon stays tappable
/// but opens the upgrade sheet instead of generating more quizzes.
final quizLimitReachedProvider = Provider<bool>((ref) {
  if (ref.watch(hasUnlimitedAiQuizzesProvider)) return false;
  final usage = ref.watch(monthlyQuizUsageProvider).asData?.value;
  if (usage == null) return false;
  return usage.used >= usage.limit;
});

/// AI quizzes used against the free / trial allotment.
///
/// Free: calendar-month window. Trial: from trial start through the 7 days.
/// Paid premium skips this provider's limit (see [hasUnlimitedAiQuizzesProvider]).
final monthlyQuizUsageProvider = FutureProvider<({int used, int limit})>(
  (ref) async {
    if (ref.watch(hasUnlimitedAiQuizzesProvider)) {
      return (used: 0, limit: kFreeQuizLimitPerMonth);
    }
    final db = ref.watch(databaseProvider);
    final now = DateTime.now();
    DateTime start;
    if (ref.watch(isPremiumTrialProvider)) {
      final renews = ref.watch(premiumRenewsAtProvider);
      start = renews != null
          ? renews.subtract(const Duration(days: AppPricing.freeTrialDays))
          : now.subtract(const Duration(days: AppPricing.freeTrialDays));
    } else {
      start = DateTime(now.year, now.month, 1);
    }
    final count = db.quizAttempts.id.count();
    final row = await (db.selectOnly(db.quizAttempts)
          ..addColumns([count])
          ..where(db.quizAttempts.deletedAt.isNull())
          ..where(db.quizAttempts.completedAt.isBiggerOrEqualValue(start)))
        .getSingle();
    final used = row.read(count) ?? 0;
    return (used: used, limit: kFreeQuizLimitPerMonth);
  },
);

/// Aggregate quiz stats for the settings history row.
final quizStatsProvider = FutureProvider<({int count, int avgPercent})>(
  (ref) async {
    final db = ref.watch(databaseProvider);
    final rows = await (db.select(db.quizAttempts)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    if (rows.isEmpty) return (count: 0, avgPercent: 0);
    var totalPct = 0;
    var scored = 0;
    for (final row in rows) {
      if (row.questionCount == 0) continue;
      totalPct += (row.correctCount * 100 / row.questionCount).round();
      scored++;
    }
    final avg = scored == 0 ? 0 : (totalPct / scored).round();
    return (count: rows.length, avgPercent: avg);
  },
);
