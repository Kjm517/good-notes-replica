import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../admin_dates.dart';
import '../csv_export.dart';
import '../widgets/admin_widgets.dart';

/// Every settled payment, newest first.
///
/// Distinct from Subscriptions, which shows who *is* premium right now. This
/// is the transaction history behind that state — renewals included, so a user
/// who has paid three times appears three times.
class AdminPaymentsPage extends ConsumerWidget {
  const AdminPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final paymentsAsync = ref.watch(adminPaymentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Payments',
            subtitle: 'Settled PayMongo transactions, newest first.',
            trailing: paymentsAsync.asData == null
                ? null
                : OutlinedButton.icon(
                    onPressed: () async {
                      final payments = paymentsAsync.asData!.value;
                      await exportCsv(
                        filename: 'notably-payments.csv',
                        headers: const [
                          'paid_at',
                          'uid',
                          'email',
                          'plan',
                          'method',
                          'amount_php',
                          'payment_intent_id',
                          'covers_until',
                        ],
                        rows: [
                          for (final p in payments)
                            [
                              p.paidAt,
                              p.uid,
                              p.email ?? '',
                              p.plan,
                              p.methodLabel,
                              p.amountPhp.toStringAsFixed(2),
                              p.paymentIntentId ?? '',
                              p.expiresAt,
                            ],
                        ],
                      );
                    },
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('CSV'),
                  ),
          ),
          const SizedBox(height: 16),
          paymentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminPaymentsProvider),
            ),
            data: (payments) => _PaymentsBody(payments: payments, t: t),
          ),
        ],
      ),
    );
  }
}

class _PaymentsBody extends StatelessWidget {
  const _PaymentsBody({required this.payments, required this.t});

  final List<AdminPaymentRow> payments;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    final gross = payments.fold<double>(0, (s, p) => s + p.amountPhp);
    final now = DateTime.now();
    final thisMonth = payments.where((p) {
      final paid = DateTime.tryParse(p.paidAt);
      return paid != null && paid.year == now.year && paid.month == now.month;
    }).toList();
    final monthGross = thisMonth.fold<double>(0, (s, p) => s + p.amountPhp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricChip(label: 'Payments', value: '${payments.length}', t: t),
            _MetricChip(label: 'Gross', value: formatPhp(gross.round()), t: t),
            _MetricChip(
              label: 'This month',
              value: formatPhp(monthGross.round()),
              t: t,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminDataTable(
          columns: const ['Paid', 'User', 'Plan', 'Method', 'Amount'],
          flex: const [3, 5, 2, 2, 2],
          emptyMessage: 'No payments recorded yet.',
          rows: [
            for (final p in payments)
              [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatAdminWhen(p.paidAt),
                      style: AppTokens.mono(size: 11, color: t.textSecondary),
                    ),
                    Text(
                      'covers to ${p.expiresAt.length >= 10 ? p.expiresAt.substring(0, 10) : p.expiresAt}',
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.email ?? shortUid(p.uid),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    Text(
                      p.paymentIntentId ?? shortUid(p.uid),
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                  ],
                ),
                AdminStatusChip(
                  label: p.plan,
                  color: p.plan == 'yearly' ? t.success : t.textMuted,
                ),
                Text(
                  p.methodLabel,
                  style: TextStyle(fontSize: 13, color: t.textSecondary),
                ),
                Text(
                  formatPhp(p.amountPhp.round()),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
              ],
          ],
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value, required this.t});

  final String label;
  final String value;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTokens.sectionLabel(t.textFaint)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}
