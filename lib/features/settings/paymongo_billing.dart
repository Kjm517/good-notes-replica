import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../app/supabase_bootstrap.dart';
import '../../core/sync/sync_providers.dart';
import '../auth/data/auth_repository.dart';
import '../auth/providers.dart';
import 'billing_plan.dart';
import 'entitlements.dart';
import 'premium_providers.dart';

enum PayMongoMethod { card, gcash, paymaya }

/// Legacy alias — prefer [PayMongoMethod].
typedef PayMongoWallet = PayMongoMethod;

extension PayMongoMethodApi on PayMongoMethod {
  String get apiValue => switch (this) {
        PayMongoMethod.card => 'card',
        PayMongoMethod.gcash => 'gcash',
        PayMongoMethod.paymaya => 'paymaya',
      };

  String get label => switch (this) {
        PayMongoMethod.card => 'Card',
        PayMongoMethod.gcash => 'GCash',
        PayMongoMethod.paymaya => 'Maya',
      };

  String get subtitle => switch (this) {
        PayMongoMethod.card => 'Visa · Mastercard · JCB',
        PayMongoMethod.gcash => '',
        PayMongoMethod.paymaya => '',
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

/// Server-reported state of one payment intent.
///
/// `unknown` means "ask again" (PayMongo hiccup, or a card checkout session
/// whose intent does not exist yet) — never treat it as a failure.
enum PayMongoPaymentStatus { paid, pending, failed, unknown }

class PayMongoStatus {
  const PayMongoStatus({
    required this.status,
    required this.entitlement,
  });

  final PayMongoPaymentStatus status;
  final PayMongoEntitlement entitlement;

  bool get isPaid => status == PayMongoPaymentStatus.paid;

  factory PayMongoStatus.fromJson(Map<String, dynamic> json) {
    return PayMongoStatus(
      status: switch (json['status'] as String?) {
        'paid' => PayMongoPaymentStatus.paid,
        'pending' => PayMongoPaymentStatus.pending,
        'failed' => PayMongoPaymentStatus.failed,
        _ => PayMongoPaymentStatus.unknown,
      },
      entitlement: PayMongoEntitlement.fromJson(json),
    );
  }
}

class PayMongoCheckout {
  const PayMongoCheckout({
    this.redirectUrl,
    this.paymentIntentId,
    this.granted = false,
  });

  final String? redirectUrl;
  final String? paymentIntentId;
  final bool granted;
}

const _pendingCheckoutKey = 'paymongo_pending_checkout';

/// Whether a signed-in user can fetch worker billing entitlement.
final payMongoSignedInProvider = Provider<bool>((ref) {
  if (kFileEndpoint.trim().isEmpty) return false;
  return ref.watch(authStateProvider).asData?.value != null;
});

/// Whether wallet checkout can run (native + signed-in user).
final payMongoAvailableProvider = Provider<bool>((ref) {
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

  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (prev, next) {
    final prevUid = prev?.asData?.value?.uid;
    final nextUid = next.asData?.value?.uid;
    if (prevUid == nextUid) return;
    ref.read(payMongoEntitlementSyncedProvider.notifier).state = false;
    ref.read(payMongoPremiumActiveProvider.notifier).state = false;
    if (nextUid != null) {
      Future.microtask(() {
        unawaited(ref.read(payMongoEntitlementRefreshProvider)());
      });
    }
  });

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
      if (service == null) {
        ref.read(payMongoEntitlementSyncedProvider.notifier).state = false;
        ref.read(payMongoPremiumActiveProvider.notifier).state = false;
        return;
      }
      try {
        final entitlement = await service.fetchEntitlement();
        await applyPayMongoEntitlement(ref, entitlement);
        if (entitlement.isPremium) {
          await service.clearPendingCheckout();
        }
      } catch (e) {
        debugPrint('PayMongo entitlement sync: $e');
      }
    };
  },
);

Future<void> applyPayMongoEntitlement(
  Ref ref,
  PayMongoEntitlement entitlement,
) async {
  // 1) Persist / clear local plan first (prefs + notifier state).
  if (entitlement.isPremium && entitlement.plan != null) {
    await ref.read(billingPlanProvider.notifier).syncFromPayMongo(
          plan: entitlement.plan!,
          expiresAt: entitlement.expiresAt,
        );
  } else {
    await ref.read(billingPlanProvider.notifier).clearLocalPremium(force: true);
  }

  // 2) Then publish live flags. isPremiumProvider watches these; do not
  // invalidate billingPlanProvider here (that caused CircularDependencyError).
  ref.read(payMongoPremiumActiveProvider.notifier).state =
      entitlement.isPremium;
  ref.read(payMongoEntitlementSyncedProvider.notifier).state = true;

  // 3) Refresh derived entitlement UI off the current call stack.
  Future.microtask(() {
    ref.read(entitlementServiceProvider).refresh();
  });
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
    required PayMongoMethod method,
    String? voucher,
  }) async {
    final headers = await _authHeaders();
    final response = await _client.post(
      _uri('/billing/checkout'),
      headers: headers,
      body: jsonEncode({
        'plan': plan.name,
        'method': method.apiValue,
        'wallet': method.apiValue,
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
      granted: map['granted'] == true,
      redirectUrl: map['redirectUrl'] as String?,
      paymentIntentId: map['paymentIntentId'] as String?,
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

  /// Asks the worker whether [paymentIntentId] has been paid.
  ///
  /// The worker is the only thing that decides this — it retrieves the intent
  /// from PayMongo and grants premium itself. This call cannot fake a payment.
  Future<PayMongoStatus> fetchPaymentStatus(String paymentIntentId) async {
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/billing/status?paymentIntentId='
          '${Uri.encodeQueryComponent(paymentIntentId)}'),
      headers: headers,
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? body['error'] as String? : null;
      throw StateError(message ?? 'Payment check failed.');
    }
    return PayMongoStatus.fromJson(body as Map<String, dynamic>);
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
