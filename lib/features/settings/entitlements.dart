import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/storage/storage_quota.dart';
import '../auth/providers.dart';
import 'premium_plan_sheet.dart';
import 'premium_providers.dart';

const kTrialDuration = Duration(days: 7);
const kTrialQuizLimit = 5;

String trialStartedKey(String uid) => 'trial_started_at_$uid';

enum EntitlementTier { premium, trial, free }

/// Resolved access tier for the signed-in account (or anonymous free).
class UserEntitlement {
  const UserEntitlement({
    required this.tier,
    required this.quizUsed,
    required this.quizLimit,
    this.trialStartedAt,
    this.trialEndsAt,
  });

  final EntitlementTier tier;
  final int quizUsed;
  final int quizLimit;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;

  bool get isPremium => tier == EntitlementTier.premium;
  bool get isTrialActive => tier == EntitlementTier.trial;
  bool get isFree => tier == EntitlementTier.free;
  bool get hasPremiumFeatures => isPremium || isTrialActive;

  /// Premium: unlimited. Active trial: up to [quizLimit]. Free: locked — upgrade.
  bool get canGenerateQuiz {
    if (isPremium) return true;
    if (isTrialActive) return quizUsed < quizLimit;
    return false;
  }

  bool get canAccessQuizHistory => hasPremiumFeatures;

  bool get hadTrial => trialStartedAt != null;

  bool get trialExpired => hadTrial && !isTrialActive && !isPremium;

  int? get trialDaysRemaining {
    if (!isTrialActive || trialEndsAt == null) return null;
    final left = trialEndsAt!.difference(DateTime.now()).inDays;
    return left < 0 ? 0 : left;
  }

  String get tierLabel => switch (tier) {
        EntitlementTier.premium => 'Premium',
        EntitlementTier.trial => 'Trial',
        EntitlementTier.free => 'Free',
      };

  String quizUsageLabel() {
    if (isPremium) return 'Unlimited · from any PDF or deck';
    if (isTrialActive) {
      return '$quizUsed of $quizLimit trial quizzes used';
    }
    return 'Included with Premium or during your free trial';
  }
}

final entitlementProvider = FutureProvider<UserEntitlement>((ref) async {
  ref.watch(sharedPrefsProvider);
  ref.watch(isPremiumProvider);
  final user = ref.watch(authStateProvider).asData?.value;
  final prefs = ref.read(sharedPrefsProvider);
  final db = ref.watch(databaseProvider);

  if (ref.watch(isPremiumProvider)) {
    return const UserEntitlement(
      tier: EntitlementTier.premium,
      quizUsed: 0,
      quizLimit: 0,
    );
  }

  DateTime? trialStart;
  if (user != null) {
    final raw = prefs.getString(trialStartedKey(user.uid));
    if (raw != null) trialStart = DateTime.tryParse(raw);
  }

  if (trialStart != null) {
    final trialEnd = trialStart.add(kTrialDuration);
    if (DateTime.now().isBefore(trialEnd)) {
      final used = await _countQuizzes(
        db,
        since: trialStart,
        until: trialEnd,
      );
      return UserEntitlement(
        tier: EntitlementTier.trial,
        quizUsed: used,
        quizLimit: kTrialQuizLimit,
        trialStartedAt: trialStart,
        trialEndsAt: trialEnd,
      );
    }
  }

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final used = await _countQuizzes(db, since: monthStart);
  return UserEntitlement(
    tier: EntitlementTier.free,
    quizUsed: used,
    quizLimit: kFreeQuizLimitPerMonth,
    trialStartedAt: trialStart,
    trialEndsAt: trialStart?.add(kTrialDuration),
  );
});

Future<int> _countQuizzes(
  AppDatabase db, {
  required DateTime since,
  DateTime? until,
}) async {
  final count = db.quizAttempts.id.count();
  final query = db.selectOnly(db.quizAttempts)..addColumns([count]);
  query.where(db.quizAttempts.deletedAt.isNull());
  query.where(db.quizAttempts.updatedAt.isBiggerOrEqualValue(since));
  if (until != null) {
    query.where(db.quizAttempts.updatedAt.isSmallerThanValue(until));
  }
  final row = await query.getSingle();
  return row.read(count) ?? 0;
}

/// Premium features (quiz history, etc.) — paid or active trial only.
final hasPremiumFeaturesProvider = Provider<bool>((ref) {
  return ref.watch(entitlementProvider).maybeWhen(
        data: (e) => e.hasPremiumFeatures,
        orElse: () => false,
      );
});

/// True when the user cannot start another AI quiz (free/trial cap hit).
final quizLimitReachedProvider = Provider<bool>((ref) {
  return ref.watch(entitlementProvider).maybeWhen(
        data: (e) => !e.canGenerateQuiz,
        orElse: () => false,
      );
});

/// Import/storage ceiling — 5 GB for free and trial accounts, 15 GB for paid Premium only.
final storageQuotaBytesProvider = Provider<int>((ref) {
  ref.watch(entitlementProvider);
  final isPaidPremium = ref.watch(isPremiumProvider);
  return storageQuotaBytes(isPremium: isPaidPremium);
});

final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  return EntitlementService(ref);
});

class EntitlementService {
  EntitlementService(this._ref);
  final Ref _ref;

  /// Called once when a brand-new account is created (email sign-up or new Google user).
  Future<void> startRegistrationTrial(String uid) async {
    final prefs = _ref.read(sharedPrefsProvider);
    final key = trialStartedKey(uid);
    if (prefs.containsKey(key)) return;
    await prefs.setBool('is_premium', false);
    await prefs.setString(key, DateTime.now().toIso8601String());
    _invalidate();
  }

  void refresh() => _invalidate();

  void _invalidate() {
    _ref.invalidate(entitlementProvider);
    _ref.invalidate(isPremiumProvider);
    _ref.invalidate(hasPremiumFeaturesProvider);
    _ref.invalidate(quizLimitReachedProvider);
    _ref.invalidate(storageQuotaBytesProvider);
    _ref.invalidate(monthlyQuizUsageProvider);
    _ref.invalidate(quizStatsProvider);
  }
}

/// Modal shown when a registration trial ends without upgrading.
class TrialExpiredDialog extends ConsumerWidget {
  const TrialExpiredDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const TrialExpiredDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      title: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: t.premiumText),
          const SizedBox(width: 10),
          const Expanded(child: Text('Your free trial ended')),
        ],
      ),
      content: Text(
        'Upgrade to Premium for unlimited AI quizzes, quiz history, cloud sync, and 15 GB storage. '
        'Free accounts can still take notes and sync — AI quizzes unlock with Premium or a trial.',
        style: TextStyle(fontSize: 14, height: 1.45, color: t.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            PremiumPlanSheet.show(context);
          },
          style: FilledButton.styleFrom(
            backgroundColor: t.premium,
            foregroundColor: t.premiumOn,
          ),
          child: const Text('See Premium plans'),
        ),
      ],
    );
  }
}
