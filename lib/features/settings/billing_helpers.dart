import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'billing_plan.dart';

/// Entitlement id configured in the RevenueCat dashboard.
const kPremiumEntitlementId = 'premium';

bool isPremiumFromCustomerInfo(CustomerInfo? info) {
  if (info == null) return false;
  return info.entitlements.all[kPremiumEntitlementId]?.isActive ?? false;
}

BillingPlan billingPlanFromCustomerInfo(CustomerInfo? info) {
  if (!isPremiumFromCustomerInfo(info)) return BillingPlan.none;
  final ent = info!.entitlements.all[kPremiumEntitlementId];
  final productId = ent?.productIdentifier.toLowerCase() ?? '';
  if (productId.contains('month')) return BillingPlan.monthly;
  if (productId.contains('year') || productId.contains('annual')) {
    return BillingPlan.yearly;
  }
  return BillingPlan.yearly;
}

DateTime? premiumRenewsAtFromCustomerInfo(CustomerInfo? info) {
  if (!isPremiumFromCustomerInfo(info)) return null;
  final raw = info!.entitlements.all[kPremiumEntitlementId]?.expirationDate;
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

Package? packageForPlan(Offerings? offerings, BillingPlan plan) {
  final current = offerings?.current;
  if (current == null) return null;
  return switch (plan) {
    BillingPlan.yearly => current.annual,
    BillingPlan.monthly => current.monthly,
    BillingPlan.lifetime || BillingPlan.none => null,
  };
}

String priceLabelForPackage(Package? package, BillingPlan plan) {
  // Web has no store checkout — always show our PHP list prices.
  if (kIsWeb) {
    return plan == BillingPlan.yearly ? yearlyPriceLabel() : monthlyPriceLabel();
  }
  final storePrice = package?.storeProduct.priceString;
  if (storePrice != null && storePrice.isNotEmpty) {
    return plan == BillingPlan.yearly ? '$storePrice/yr' : '$storePrice/mo';
  }
  return plan == BillingPlan.yearly ? yearlyPriceLabel() : monthlyPriceLabel();
}
