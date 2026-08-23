import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_providers.dart';
/// Billing tier — stub until StoreKit / Play Billing is wired.
enum BillingPlan { none, monthly, yearly }

const kFreeQuizLimitPerMonth = 3;

const _planKey = 'billing_plan';
const _renewKey = 'premium_renews_at';

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
    final renew = DateTime.now().add(
      plan == BillingPlan.yearly
          ? const Duration(days: 365)
          : const Duration(days: 30),
    );
    await prefs.setString(_renewKey, renew.toIso8601String());
    ref.invalidateSelf();
    ref.invalidate(isPremiumProvider);
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

/// Quizzes completed this calendar month (all documents).
final monthlyQuizUsageProvider = FutureProvider<({int used, int limit})>(
  (ref) async {
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium) {
      return (used: 0, limit: kFreeQuizLimitPerMonth);
    }
    final db = ref.watch(databaseProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
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

/// Aggregate quiz stats for premium settings row.
final quizStatsProvider = FutureProvider<({int count, int avgPercent})>(
  (ref) async {
    final db = ref.watch(databaseProvider);
    final rows = await (db.select(db.quizAttempts)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    if (rows.isEmpty) return (count: 0, avgPercent: 0);
    var totalPct = 0;
    for (final row in rows) {
      if (row.questionCount == 0) continue;
      totalPct += (row.correctCount * 100 / row.questionCount).round();
    }
    final avg = rows.isEmpty ? 0 : (totalPct / rows.length).round();
    return (count: rows.length, avgPercent: avg);
  },
);
