import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/design.dart';
import 'paymongo_billing.dart';
import 'premium_providers.dart';
import 'settings_widgets.dart';

/// One row of history, from either source.
class _Receipt {
  const _Receipt({
    required this.at,
    required this.label,
    required this.amountPhp,
    required this.status,
  });

  final DateTime at;
  final String label;
  final double amountPhp;
  final String status;
}

/// Payment history, read from the worker so it survives a reinstall and shows
/// payments made on other devices.
///
/// Local prefs stay as the fallback: they hold store purchases, which never
/// reach the PayMongo ledger, and cover the offline case.
class BillingHistoryScreen extends ConsumerWidget {
  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final remote = ref.watch(payMongoPaymentsProvider);
    final local = ref.watch(billingHistoryProvider);

    final localReceipts = [
      for (final e in local)
        _Receipt(
          at: e.at,
          label: e.planLabel,
          amountPhp: e.amountPhp,
          status: e.status,
        ),
    ];

    final receipts = remote.maybeWhen(
      data: (payments) => payments.isEmpty
          ? localReceipts
          : [
              for (final p in payments)
                _Receipt(
                  at: p.paidAt.toLocal(),
                  label: switch (p.plan) {
                    BillingPlan.yearly => 'Premium — Yearly',
                    BillingPlan.monthly => 'Premium — Monthly',
                    BillingPlan.lifetime => 'Premium — Lifetime',
                    BillingPlan.none => 'Premium',
                  },
                  amountPhp: p.amountPhp,
                  status: p.statusLabel,
                ),
            ],
      orElse: () => localReceipts,
    );

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: const Text('Billing history'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: remote.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: remote.isLoading
                ? null
                : () => ref.invalidate(payMongoPaymentsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(payMongoPaymentsProvider);
          await ref.read(payMongoEntitlementRefreshProvider)();
        },
        child: receipts.isEmpty
            ? _EmptyState(error: remote.error)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                itemCount: receipts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _ReceiptCard(receipt: receipts[index]),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Always scrollable so pull-to-refresh works with nothing in the list.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.receipt_long_outlined, size: 40, color: t.textFaint),
        const SizedBox(height: 12),
        const Text(
          'No payments yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          error == null
              ? 'Your subscription charges will show up here after checkout.'
              : 'Could not reach billing. Pull down to try again.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.4, color: t.textMuted),
        ),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});

  final _Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SettingsGroupCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.premiumSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.receipt_rounded,
                  color: t.premiumText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat.yMMMd().add_jm().format(receipt.at),
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPhp(receipt.amountPhp),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    receipt.status,
                    style: AppTokens.mono(size: 10, color: t.success),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
