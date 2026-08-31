import 'package:flutter_test/flutter_test.dart';
import 'package:notably/features/settings/billing_plan.dart';
import 'package:notably/features/settings/paymongo_billing.dart';

/// Parsing of everything the worker sends back. These decide whether someone
/// is treated as paid, so a silent parse failure is an access-control bug.
void main() {
  group('PayMongoEntitlement', () {
    test('reads a full premium payload', () {
      final e = PayMongoEntitlement.fromJson({
        'isPremium': true,
        'plan': 'yearly',
        'expiresAt': '2027-01-15T10:30:00.000Z',
        'wallet': 'gcash',
      });
      expect(e.isPremium, isTrue);
      expect(e.plan, BillingPlan.yearly);
      expect(e.expiresAt, DateTime.parse('2027-01-15T10:30:00.000Z'));
      expect(e.method, PayMongoMethod.gcash);
    });

    test('reads the lapsed payload', () {
      final e = PayMongoEntitlement.fromJson({
        'isPremium': false,
        'plan': null,
        'expiresAt': null,
        'source': null,
      });
      expect(e.isPremium, isFalse);
      expect(e.plan, isNull);
      expect(e.expiresAt, isNull);
    });

    /// Lifetime comes back with a null expiry, which must not read as lapsed —
    /// an earlier bug did exactly that and admin lifetime grants never applied.
    test('lifetime keeps premium despite a null expiry', () {
      final e = PayMongoEntitlement.fromJson({
        'isPremium': true,
        'plan': 'lifetime',
        'expiresAt': null,
      });
      expect(e.isPremium, isTrue);
      expect(e.plan, BillingPlan.lifetime);
      expect(e.expiresAt, isNull);
    });

    test('defaults to not premium when the flag is missing', () {
      expect(PayMongoEntitlement.fromJson(const {}).isPremium, isFalse);
    });

    /// A plan name the app does not know must not be coerced into a real plan.
    test('an unknown plan parses as null rather than guessing', () {
      final e = PayMongoEntitlement.fromJson({
        'isPremium': true,
        'plan': 'quarterly',
      });
      expect(e.plan, isNull);
    });

    test('an unparseable expiry becomes null instead of throwing', () {
      final e = PayMongoEntitlement.fromJson({
        'isPremium': true,
        'plan': 'monthly',
        'expiresAt': 'not-a-date',
      });
      expect(e.expiresAt, isNull);
    });

    test('every payment method round-trips', () {
      for (final (raw, expected) in const [
        ('card', PayMongoMethod.card),
        ('gcash', PayMongoMethod.gcash),
        ('paymaya', PayMongoMethod.paymaya),
        ('qrph', PayMongoMethod.qrph),
      ]) {
        final e = PayMongoEntitlement.fromJson({
          'isPremium': true,
          'plan': 'monthly',
          'wallet': raw,
        });
        expect(e.method, expected, reason: 'wallet=$raw');
      }
    });

    test('an unknown wallet parses as null', () {
      final e = PayMongoEntitlement.fromJson({
        'isPremium': true,
        'plan': 'monthly',
        'wallet': 'shopeepay',
      });
      expect(e.method, isNull);
    });
  });

  group('PayMongoStatus', () {
    test('paid is recognised', () {
      final s = PayMongoStatus.fromJson({
        'status': 'paid',
        'isPremium': true,
        'plan': 'monthly',
      });
      expect(s.status, PayMongoPaymentStatus.paid);
      expect(s.isPaid, isTrue);
      expect(s.entitlement.isPremium, isTrue);
    });

    test('pending and failed are distinct', () {
      expect(
        PayMongoStatus.fromJson({'status': 'pending'}).status,
        PayMongoPaymentStatus.pending,
      );
      expect(
        PayMongoStatus.fromJson({'status': 'failed'}).status,
        PayMongoPaymentStatus.failed,
      );
    });

    /// The QR screen keeps waiting on `unknown` and only gives up on `failed`,
    /// so an unrecognised status must never collapse into failure.
    test('an unrecognised status is unknown, not failed', () {
      expect(
        PayMongoStatus.fromJson({'status': 'weird_new_state'}).status,
        PayMongoPaymentStatus.unknown,
      );
      expect(
        PayMongoStatus.fromJson(const {}).status,
        PayMongoPaymentStatus.unknown,
      );
    });

    test('a non-paid status is never treated as paid', () {
      for (final raw in ['pending', 'failed', 'unknown', 'anything']) {
        expect(
          PayMongoStatus.fromJson({'status': raw}).isPaid,
          isFalse,
          reason: 'status=$raw',
        );
      }
    });
  });

  group('PayMongoPayment', () {
    test('converts centavos to pesos', () {
      final p = PayMongoPayment.fromJson({
        'plan': 'monthly',
        'amountCentavos': 19900,
        'paidAt': '2026-08-31T12:00:00.000Z',
        'method': 'qrph',
        'paymentIntentId': 'pi_abc',
      });
      expect(p.amountPhp, 199.0);
      expect(p.plan, BillingPlan.monthly);
      expect(p.method, PayMongoMethod.qrph);
      expect(p.paymentIntentId, 'pi_abc');
    });

    test('keeps a discounted amount exact', () {
      final p = PayMongoPayment.fromJson({
        'plan': 'monthly',
        'amountCentavos': 15920,
        'paidAt': '2026-08-31T12:00:00.000Z',
      });
      expect(p.amountPhp, 159.20);
    });

    test('a grant with no method is labelled rather than blank', () {
      final p = PayMongoPayment.fromJson({
        'plan': 'lifetime',
        'amountCentavos': 0,
        'paidAt': '2026-08-31T12:00:00.000Z',
      });
      expect(p.method, isNull);
      expect(p.statusLabel, 'Paid');
    });

    test('names the wallet when there is one', () {
      final p = PayMongoPayment.fromJson({
        'plan': 'monthly',
        'amountCentavos': 19900,
        'paidAt': '2026-08-31T12:00:00.000Z',
        'method': 'gcash',
      });
      expect(p.statusLabel, contains('GCash'));
    });

    test('survives a missing amount', () {
      final p = PayMongoPayment.fromJson({
        'plan': 'monthly',
        'paidAt': '2026-08-31T12:00:00.000Z',
      });
      expect(p.amountPhp, 0);
    });
  });

  group('PayMongoCheckout', () {
    test('a QR Ph checkout carries an image and no redirect', () {
      const c = PayMongoCheckout(
        qrImageUrl: 'data:image/png;base64,AAAA',
        paymentIntentId: 'pi_qr',
      );
      expect(c.qrImageUrl, isNotNull);
      expect(c.redirectUrl, isNull);
      expect(c.granted, isFalse);
    });

    test('a wallet checkout carries a redirect and no image', () {
      const c = PayMongoCheckout(
        redirectUrl: 'https://pm.link/x',
        paymentIntentId: 'pi_wallet',
      );
      expect(c.redirectUrl, isNotNull);
      expect(c.qrImageUrl, isNull);
    });
  });

  group('method labels', () {
    test('every method has a non-empty label', () {
      for (final m in PayMongoMethod.values) {
        expect(m.label, isNotEmpty, reason: '$m');
        expect(m.apiValue, isNotEmpty, reason: '$m');
      }
    });

    test('api values match what the worker accepts', () {
      expect(PayMongoMethod.card.apiValue, 'card');
      expect(PayMongoMethod.gcash.apiValue, 'gcash');
      expect(PayMongoMethod.paymaya.apiValue, 'paymaya');
      expect(PayMongoMethod.qrph.apiValue, 'qrph');
    });
  });
}
