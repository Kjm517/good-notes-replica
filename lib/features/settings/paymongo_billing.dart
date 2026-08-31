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

enum PayMongoMethod { card, gcash, paymaya, qrph }

/// Legacy alias — prefer [PayMongoMethod].
typedef PayMongoWallet = PayMongoMethod;

extension PayMongoMethodApi on PayMongoMethod {
  String get apiValue => switch (this) {
        PayMongoMethod.card => 'card',
        PayMongoMethod.gcash => 'gcash',
        PayMongoMethod.paymaya => 'paymaya',
        PayMongoMethod.qrph => 'qrph',
      };

  String get label => switch (this) {
        PayMongoMethod.card => 'Card',
        PayMongoMethod.gcash => 'GCash',
        PayMongoMethod.paymaya => 'Maya',
        PayMongoMethod.qrph => 'QR Ph',
      };

  String get subtitle => switch (this) {
        PayMongoMethod.card => 'Visa · Mastercard · JCB',
        PayMongoMethod.gcash => '',
        PayMongoMethod.paymaya => '',
        PayMongoMethod.qrph => 'Any bank or e-wallet app',
      };
}

class PayMongoEntitlement {
  const PayMongoEntitlement({
    required this.isPremium,
    this.plan,
    this.expiresAt,
    this.method,
  });

  final bool isPremium;
  final BillingPlan? plan;
  final DateTime? expiresAt;

  /// How the active term was paid for, when known.
  final PayMongoMethod? method;

  factory PayMongoEntitlement.fromJson(Map<String, dynamic> json) {
    final planRaw = json['plan'] as String?;
    final plan = planRaw == null
        ? null
        : BillingPlan.values.asNameMap()[planRaw];
    final expiresRaw = json['expiresAt'] as String?;
    final walletRaw = json['wallet'] as String?;
    return PayMongoEntitlement(
      isPremium: json['isPremium'] as bool? ?? false,
      plan: plan,
      expiresAt:
          expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
      method: switch (walletRaw) {
        'card' => PayMongoMethod.card,
        'gcash' => PayMongoMethod.gcash,
        'paymaya' => PayMongoMethod.paymaya,
        'qrph' => PayMongoMethod.qrph,
        _ => null,
      },
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

/// One settled payment from the worker's ledger.
class PayMongoPayment {
  const PayMongoPayment({
    required this.plan,
    required this.amountPhp,
    required this.paidAt,
    this.method,
    this.paymentIntentId,
  });

  final BillingPlan plan;
  final double amountPhp;
  final DateTime paidAt;
  final PayMongoMethod? method;
  final String? paymentIntentId;

  factory PayMongoPayment.fromJson(Map<String, dynamic> json) {
    return PayMongoPayment(
      plan: BillingPlan.values.asNameMap()[json['plan'] as String? ?? ''] ??
          BillingPlan.none,
      amountPhp: ((json['amountCentavos'] as num?)?.toDouble() ?? 0) / 100,
      paidAt:
          DateTime.tryParse(json['paidAt'] as String? ?? '') ?? DateTime.now(),
      method: switch (json['method'] as String?) {
        'card' => PayMongoMethod.card,
        'gcash' => PayMongoMethod.gcash,
        'paymaya' => PayMongoMethod.paymaya,
        'qrph' => PayMongoMethod.qrph,
        _ => null,
      },
      paymentIntentId: json['paymentIntentId'] as String?,
    );
  }

  String get statusLabel =>
      method == null ? 'Paid' : 'Paid · ${method!.label}';
}

class PayMongoCheckout {
  const PayMongoCheckout({
    this.redirectUrl,
    this.qrImageUrl,
    this.paymentIntentId,
    this.granted = false,
  });

  /// Set for redirect methods (card, GCash, Maya) — a page to open.
  final String? redirectUrl;

  /// Set for QR Ph only — a base64 data URI of the code to display.
  final String? qrImageUrl;

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

/// The signed-in user's payment history, straight from the worker.
///
/// Auto-disposed so reopening Billing history refetches instead of showing a
/// cached list from an earlier session.
final payMongoPaymentsProvider =
    FutureProvider.autoDispose<List<PayMongoPayment>>((ref) async {
  final service = ref.watch(payMongoBillingServiceProvider);
  if (service == null) return const [];
  return service.fetchPayments();
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
          method: entitlement.method?.apiValue,
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
      qrImageUrl: map['qrImageUrl'] as String?,
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

  /// The signed-in user's own settled payments, newest first.
  Future<List<PayMongoPayment>> fetchPayments() async {
    final headers = await _authHeaders();
    final response = await _client.get(
      _uri('/billing/payments'),
      headers: headers,
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = body is Map ? body['error'] as String? : null;
      throw StateError(message ?? 'Could not load payments.');
    }
    final list = (body as Map<String, dynamic>)['payments'] as List<dynamic>?;
    return (list ?? [])
        .map((e) => PayMongoPayment.fromJson(e as Map<String, dynamic>))
        .toList();
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
