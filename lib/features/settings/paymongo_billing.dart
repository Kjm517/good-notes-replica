import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../app/supabase_bootstrap.dart';
import '../../core/sync/sync_providers.dart';
import '../auth/providers.dart';
import 'billing_plan.dart';
import 'entitlements.dart';
import 'premium_providers.dart';

enum PayMongoWallet { gcash, paymaya }

extension PayMongoWalletApi on PayMongoWallet {
  String get apiValue => switch (this) {
        PayMongoWallet.gcash => 'gcash',
        PayMongoWallet.paymaya => 'paymaya',
      };

  String get label => switch (this) {
        PayMongoWallet.gcash => 'GCash',
        PayMongoWallet.paymaya => 'Maya',
      };
}

class PayMongoEntitlement {
  const PayMongoEntitlement({
    required this.isPremium,
    this.plan,
    this.expiresAt,
  });

  final bool isPremium;
  final BillingPlan? plan;
  final DateTime? expiresAt;

  factory PayMongoEntitlement.fromJson(Map<String, dynamic> json) {
    final planRaw = json['plan'] as String?;
    final plan = planRaw == null
        ? null
        : BillingPlan.values.asNameMap()[planRaw];
    final expiresRaw = json['expiresAt'] as String?;
    return PayMongoEntitlement(
      isPremium: json['isPremium'] as bool? ?? false,
      plan: plan,
      expiresAt:
          expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
    );
  }
}

class PayMongoCheckout {
  const PayMongoCheckout({
    required this.redirectUrl,
    required this.paymentIntentId,
  });

  final String redirectUrl;
  final String paymentIntentId;
}

const _pendingCheckoutKey = 'paymongo_pending_checkout';

/// Whether a signed-in user can fetch worker billing entitlement.
final payMongoSignedInProvider = Provider<bool>((ref) {
  if (kFileEndpoint.trim().isEmpty) return false;
  return ref.watch(authStateProvider).asData?.value != null;
});

/// Whether wallet checkout can run (native + signed-in user).
final payMongoAvailableProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  return ref.watch(payMongoSignedInProvider);
});

/// Active PayMongo premium from the worker entitlement API.
// Defined in premium_providers.dart — updated after wallet checkout.

final payMongoBillingServiceProvider = Provider<PayMongoBillingService?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null || kFileEndpoint.trim().isEmpty) return null;
  return PayMongoBillingService(
    endpoint: kFileEndpoint,
    prefs: ref.watch(sharedPrefsProvider),
    idToken: () async {
      final token = await supabaseAccessToken();
      return token ?? '';
    },
  );
});

/// Polls worker entitlement while signed in so admin grants apply without
/// restarting the app.
const _entitlementPollInterval = Duration(seconds: 12);

final payMongoSyncProvider = Provider<void>((ref) {
  if (!ref.watch(payMongoSignedInProvider)) return;
  var inFlight = false;
  Future<void> tick() async {
    if (inFlight) return;
    inFlight = true;
    try {
      await ref.read(payMongoEntitlementRefreshProvider)();
    } finally {
      inFlight = false;
    }
  }

  unawaited(tick());
  final timer = Timer.periodic(_entitlementPollInterval, (_) => unawaited(tick()));
  ref.onDispose(timer.cancel);
});

/// Refreshes PayMongo premium state from the worker (safe from widgets & providers).
final payMongoEntitlementRefreshProvider = Provider<Future<void> Function()>(
  (ref) {
    return () async {
      final service = ref.read(payMongoBillingServiceProvider);
      if (service == null) return;
      try {
        final entitlement = await service.fetchEntitlement();
        applyPayMongoEntitlement(ref, entitlement);
        if (entitlement.isPremium) {
          await service.clearPendingCheckout();
        }
      } catch (e) {
        debugPrint('PayMongo entitlement sync: $e');
      }
    };
  },
);

void applyPayMongoEntitlement(Ref ref, PayMongoEntitlement entitlement) {
  final wasPremium = ref.read(payMongoPremiumActiveProvider);
  final currentPlan = ref.read(billingPlanProvider);
  final nextPlan = entitlement.isPremium
      ? (entitlement.plan ?? BillingPlan.lifetime)
      : BillingPlan.none;
  if (wasPremium == entitlement.isPremium) {
    if (!entitlement.isPremium) return;
    if (currentPlan == nextPlan) return;
  }

  ref.read(payMongoPremiumActiveProvider.notifier).state =
      entitlement.isPremium;
  if (entitlement.isPremium) {
    unawaited(
      ref.read(billingPlanProvider.notifier).syncFromPayMongo(
            plan: nextPlan,
            expiresAt: entitlement.expiresAt,
          ),
    );
  } else if (!ref.read(rcPremiumActiveProvider)) {
    unawaited(ref.read(billingPlanProvider.notifier).clearFromPayMongo());
  }
  ref.invalidate(isPremiumProvider);
  ref.read(entitlementServiceProvider).refresh();
}

class PayMongoBillingService {
  PayMongoBillingService({
    required this.endpoint,
    required this.prefs,
    required this.idToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final SharedPreferences prefs;
  final Future<String> Function() idToken;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$endpoint$path');

  Future<Map<String, String>> _authHeaders() async {
    final token = await idToken();
    if (token.isEmpty) {
      throw StateError('Sign in required for wallet checkout.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<PayMongoCheckout> createCheckout({
    required BillingPlan plan,
    required PayMongoWallet wallet,
    String? voucher,
  }) async {
    final headers = await _authHeaders();
    final response = await _client.post(
      _uri('/billing/checkout'),
      headers: headers,
      body: jsonEncode({
        'plan': plan.name,
        'wallet': wallet.apiValue,
        if (voucher != null && voucher.trim().isNotEmpty)
          'voucher': voucher.trim(),
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? body['error'] as String? : null;
      throw StateError(message ?? 'Checkout failed (${response.statusCode}).');
    }
    final map = body as Map<String, dynamic>;
    return PayMongoCheckout(
      redirectUrl: map['redirectUrl'] as String,
      paymentIntentId: map['paymentIntentId'] as String,
    );
  }

  Future<PayMongoEntitlement> fetchEntitlement() async {
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/billing/entitlement'),
      headers: headers,
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? body['error'] as String? : null;
      throw StateError(message ?? 'Entitlement check failed.');
    }
    return PayMongoEntitlement.fromJson(body as Map<String, dynamic>);
  }

  Future<void> markPendingCheckout(String paymentIntentId) async {
    await prefs.setString(_pendingCheckoutKey, paymentIntentId);
  }

  Future<bool> hasPendingCheckout() async {
    return prefs.containsKey(_pendingCheckoutKey);
  }

  Future<void> clearPendingCheckout() async {
    await prefs.remove(_pendingCheckoutKey);
  }
}
