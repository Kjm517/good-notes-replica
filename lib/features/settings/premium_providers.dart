import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import 'billing_env.dart';
import 'billing_helpers.dart';
import 'billing_plan.dart';

export 'billing_plan.dart';

const _planKey = 'billing_plan';
const _renewKey = 'premium_renews_at';
const _historyKey = 'billing_history_json';

/// Live premium flag from RevenueCat when configured.
final rcPremiumActiveProvider = StateProvider<bool>((ref) => false);

/// Live premium flag from PayMongo wallet checkout (worker entitlement).
final payMongoPremiumActiveProvider = StateProvider<bool>((ref) => false);

/// Paid Premium — RevenueCat, PayMongo wallet, or dev prefs stub.
final isPremiumProvider = Provider<bool>((ref) {
  if (ref.watch(revenueCatConfiguredProvider)) {
    if (ref.watch(rcPremiumActiveProvider)) return true;
  }
  if (ref.watch(payMongoPremiumActiveProvider)) return true;
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getBool('is_premium') ?? false;
});

class BillingHistoryEntry {
  const BillingHistoryEntry({
    required this.at,
    required this.plan,
    required this.amountPhp,
    required this.status,
  });

  final DateTime at;
  final BillingPlan plan;
  final double amountPhp;
  final String status;

  String get planLabel => switch (plan) {
        BillingPlan.yearly => 'Premium — Yearly',
        BillingPlan.monthly => 'Premium — Monthly',
        BillingPlan.none => 'Premium',
      };

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'plan': plan.name,
        'amount': amountPhp,
        'status': status,
      };

  factory BillingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return BillingHistoryEntry(
      at: DateTime.parse(json['at'] as String),
      plan: BillingPlan.values.byName(json['plan'] as String),
      amountPhp: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
    );
  }
}

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

  /// Dev / web fallback when RevenueCat is not configured.
  Future<void> activate(BillingPlan plan, {double? amountPhp}) async {
    final prefs = ref.read(sharedPrefsProvider);
    final paid = amountPhp ?? priceForPlan(plan);
    await prefs.setBool('is_premium', true);
    await prefs.setString(_planKey, plan.name);
    final renew = DateTime.now().add(
      plan == BillingPlan.yearly
          ? const Duration(days: 365)
          : const Duration(days: 30),
    );
    await prefs.setString(_renewKey, renew.toIso8601String());
    await _appendHistory(
      prefs,
      BillingHistoryEntry(
        at: DateTime.now(),
        plan: plan,
        amountPhp: paid,
        status: 'Paid',
      ),
    );
    ref.invalidateSelf();
    ref.invalidate(isPremiumProvider);
    ref.invalidate(billingHistoryProvider);
  }

  /// Cache RevenueCat state locally for plan labels and renewal dates.
  Future<void> syncFromCustomerInfo(CustomerInfo info) async {
    final prefs = ref.read(sharedPrefsProvider);
    final active = isPremiumFromCustomerInfo(info);
    if (active) {
      final plan = billingPlanFromCustomerInfo(info);
      final renew = premiumRenewsAtFromCustomerInfo(info);
      await prefs.setBool('is_premium', true);
      await prefs.setString(_planKey, plan.name);
      if (renew != null) {
        await prefs.setString(_renewKey, renew.toIso8601String());
      }
    } else {
      await prefs.setBool('is_premium', false);
    }
    ref.invalidateSelf();
  }

  Future<void> syncFromPayMongo({
    required BillingPlan plan,
    DateTime? expiresAt,
    double? amountPhp,
  }) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('is_premium', true);
    await prefs.setString(_planKey, plan.name);
    if (expiresAt != null) {
      await prefs.setString(_renewKey, expiresAt.toIso8601String());
    }
    if (amountPhp != null) {
      await _appendHistory(
        prefs,
        BillingHistoryEntry(
          at: DateTime.now(),
          plan: plan,
          amountPhp: amountPhp,
          status: 'Paid · PayMongo',
        ),
      );
    }
    ref.invalidateSelf();
    ref.invalidate(billingHistoryProvider);
  }

  Future<void> recordStorePurchase({
    required BillingPlan plan,
    required Package package,
  }) async {
    final prefs = ref.read(sharedPrefsProvider);
    final price = package.storeProduct.price;
    await _appendHistory(
      prefs,
      BillingHistoryEntry(
        at: DateTime.now(),
        plan: plan,
        amountPhp: price,
        status: 'Paid · ${package.storeProduct.identifier}',
      ),
    );
    ref.invalidate(billingHistoryProvider);
  }
}

Future<void> _appendHistory(
  SharedPreferences prefs,
  BillingHistoryEntry entry,
) async {
  final existing = billingHistoryFromPrefs(prefs);
  final asStrings = [
    jsonEncode(entry.toJson()),
    for (final e in existing) jsonEncode(e.toJson()),
  ];
  await prefs.setStringList(_historyKey, asStrings);
}

List<BillingHistoryEntry> billingHistoryFromPrefs(SharedPreferences prefs) {
  final raw = prefs.getStringList(_historyKey) ?? const [];
  final entries = <BillingHistoryEntry>[];
  for (final line in raw) {
    try {
      final json = jsonDecode(line);
      if (json is Map<String, dynamic>) {
        entries.add(BillingHistoryEntry.fromJson(json));
      }
    } catch (_) {
      // Skip corrupt rows.
    }
  }
  return entries;
}

final billingHistoryProvider = Provider<List<BillingHistoryEntry>>((ref) {
  ref.watch(billingPlanProvider);
  final prefs = ref.watch(sharedPrefsProvider);
  return billingHistoryFromPrefs(prefs);
});

final premiumRenewsAtProvider = Provider<DateTime?>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final paidViaRc =
      ref.watch(revenueCatConfiguredProvider) && ref.watch(rcPremiumActiveProvider);
  final paidViaPayMongo = ref.watch(payMongoPremiumActiveProvider);
  if (!paidViaRc && !paidViaPayMongo && !(prefs.getBool('is_premium') ?? false)) {
    return null;
  }
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
    var counted = 0;
    for (final row in rows) {
      if (row.questionCount == 0 || !row.completed) continue;
      totalPct += (row.correctCount * 100 / row.questionCount).round();
      counted++;
    }
    final avg = counted == 0 ? 0 : (totalPct / counted).round();
    return (count: counted, avgPercent: avg);
  },
);
