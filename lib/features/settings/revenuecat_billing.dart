import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../auth/data/auth_repository.dart';
import '../auth/providers.dart';
import 'billing_env.dart';
import 'billing_helpers.dart';
import 'premium_providers.dart';

export 'billing_env.dart' show revenueCatConfiguredProvider;
export 'premium_providers.dart' show isPremiumProvider;

final customerInfoProvider =
    NotifierProvider<CustomerInfoNotifier, CustomerInfo?>(
  CustomerInfoNotifier.new,
);

class CustomerInfoNotifier extends Notifier<CustomerInfo?> {
  @override
  CustomerInfo? build() => null;

  Future<void> refresh() async {
    if (!ref.read(revenueCatConfiguredProvider)) return;
    try {
      final info = await Purchases.getCustomerInfo();
      _apply(info);
    } catch (e) {
      debugPrint('RevenueCat refresh failed: $e');
    }
  }

  void _apply(CustomerInfo info) {
    state = info;
    ref.read(rcPremiumActiveProvider.notifier).state =
        isPremiumFromCustomerInfo(info);
    ref.read(billingPlanProvider.notifier).syncFromCustomerInfo(info);
    ref.invalidate(isPremiumProvider);
  }

  void apply(CustomerInfo info) => _apply(info);
}

final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  if (!ref.watch(revenueCatConfiguredProvider)) return null;
  try {
    return Purchases.getOfferings();
  } catch (e) {
    debugPrint('RevenueCat offerings failed: $e');
    return null;
  }
});

/// Keeps RevenueCat tied to Supabase auth and listens for entitlement updates.
final revenueCatSyncProvider = Provider<void>((ref) {
  if (!ref.watch(revenueCatConfiguredProvider)) return;

  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (prev, next) {
    unawaited(_syncAuth(ref, next.asData?.value));
  });

  void onCustomerInfo(CustomerInfo info) {
    // Listener can fire during provider init — defer so we don't modify
    // [customerInfoProvider] while another provider is still building.
    Future.microtask(() {
      ref.read(customerInfoProvider.notifier).apply(info);
    });
  }

  Purchases.addCustomerInfoUpdateListener(onCustomerInfo);
  ref.onDispose(() {
    Purchases.removeCustomerInfoUpdateListener(onCustomerInfo);
  });

  Future.microtask(() {
    unawaited(ref.read(customerInfoProvider.notifier).refresh());
  });
});

Future<void> _syncAuth(Ref ref, AppUser? user) async {
  if (!ref.read(revenueCatConfiguredProvider)) return;
  try {
    if (user != null) {
      final result = await Purchases.logIn(user.uid);
      ref.read(customerInfoProvider.notifier).apply(result.customerInfo);
    } else {
      final info = await Purchases.logOut();
      ref.read(customerInfoProvider.notifier).apply(info);
    }
  } catch (e) {
    debugPrint('RevenueCat auth sync failed: $e');
  }
}

/// Call once during app bootstrap (after `.env` is loaded).
Future<void> configureRevenueCat() async {
  if (kIsWeb) return;
  final apiKey = revenueCatApiKeyFromEnv();
  if (apiKey == null) {
    debugPrint(
      'RevenueCat not configured — add $kRevenueCatFlutterKeyEnv to .env',
    );
    return;
  }
  try {
    final config = PurchasesConfiguration(apiKey);
    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }
    await Purchases.configure(config);
    debugPrint('RevenueCat configured');
  } catch (e) {
    debugPrint('RevenueCat configure failed: $e');
  }
}

Future<PurchaseResult> purchasePackage(Package package) {
  return Purchases.purchase(PurchaseParams.package(package));
}

Future<CustomerInfo> restorePurchases() {
  return Purchases.restorePurchases();
}

bool isPurchaseCancelled(Object error) {
  if (error is PlatformException) {
    final code = PurchasesErrorHelper.getErrorCode(error);
    return code == PurchasesErrorCode.purchaseCancelledError;
  }
  return false;
}
