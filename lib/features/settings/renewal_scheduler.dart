import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_providers.dart';
import '../../core/notifications/notification_service.dart';
import 'billing_plan.dart';
import 'premium_providers.dart';

/// Fixed ids so rescheduling replaces the previous pair rather than stacking
/// duplicates every time entitlement syncs.
const _firstNoticeId = 91001;
const _secondNoticeId = 91002;

/// Books the two expiry reminders for a one-time term.
///
/// Wallet and QR Ph payments cannot be auto-debited, so the term simply ends.
/// These are what stop that happening silently: a nudge five days out, and a
/// second three days out for anyone who ignored the first.
///
/// Scheduled rather than shown on open, so they arrive even if the app is
/// closed — which is the whole point of a reminder.
class RenewalScheduler {
  const RenewalScheduler(this._ref);

  final Ref _ref;

  Future<void> sync() async {
    final service = NotificationService.instance;
    if (!service.supported) return;

    // Always clear first: the previous pair may be for an expiry that has
    // since moved, been cancelled, or been paid off.
    await service.cancel(_firstNoticeId);
    await service.cancel(_secondNoticeId);

    if (!_shouldRemind()) return;

    final expiresAt = _ref.read(premiumRenewsAtProvider);
    if (expiresAt == null) return;

    final silent = _ref.read(notificationsSilentProvider);
    final plan = _ref.read(billingPlanProvider);
    final price = plan == BillingPlan.yearly
        ? yearlyPriceLabel()
        : monthlyPriceLabel();

    await service.scheduleAt(
      id: _firstNoticeId,
      when: expiresAt.subtract(kRenewalReminderWindow),
      title: 'Premium ends in 5 days',
      body: 'Extend for $price to keep unlimited quizzes and 15 GB storage.',
      silent: silent,
    );

    await service.scheduleAt(
      id: _secondNoticeId,
      when: expiresAt.subtract(kRenewalSecondNoticeWindow),
      title: 'Premium ends in 3 days',
      body: 'Your Premium has not been extended yet. Tap to renew for $price.',
      silent: silent,
    );
  }

  /// Reminders are pointless for a plan that renews itself, never ends, or
  /// that the user has already told us they are done with.
  bool _shouldRemind() {
    if (!_ref.read(notificationsEnabledProvider)) return false;
    if (!_ref.read(renewalReminderEnabledProvider)) return false;
    if (!_ref.read(isPremiumProvider)) return false;
    if (_ref.read(premiumCancelledProvider)) return false;
    if (_ref.read(premiumAutoRenewsProvider)) return false;
    if (_ref.read(billingPlanProvider) == BillingPlan.lifetime) return false;
    return true;
  }
}

final renewalSchedulerProvider = Provider<RenewalScheduler>((ref) {
  return RenewalScheduler(ref);
});

/// Rebooks the reminders whenever the term, the switches, or the cancellation
/// state changes. Watched once at app level.
final renewalReminderSyncProvider = Provider<void>((ref) {
  // Every input the schedule depends on.
  ref.watch(billingRevisionProvider);
  ref.watch(billingPlanProvider);
  ref.watch(isPremiumProvider);
  ref.watch(premiumCancelledProvider);
  ref.watch(notificationsEnabledProvider);
  ref.watch(notificationsSilentProvider);
  ref.watch(renewalReminderEnabledProvider);

  // Off the build frame — this reads providers that are still settling.
  Future.microtask(() async {
    try {
      await ref.read(renewalSchedulerProvider).sync();
    } catch (e) {
      debugPrint('Renewal reminder scheduling failed: $e');
    }
  });
});
