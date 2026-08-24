import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/design.dart';
import 'premium_providers.dart';
import 'settings_widgets.dart';

class BillingHistoryScreen extends ConsumerWidget {
  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final entries = ref.watch(billingHistoryProvider);

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        backgroundColor: t.canvas,
        title: const Text('Billing history'),
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: t.textFaint),
                    const SizedBox(height: 12),
                    const Text(
                      'No payments yet',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your subscription charges will show up here after checkout.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.4, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
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
                                  entry.planLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat.yMMMd().add_jm().format(entry.at),
                                  style: AppTokens.mono(size: 10, color: t.textFaint),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatPhp(entry.amountPhp),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: t.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.status,
                                style: AppTokens.mono(size: 10, color: t.success),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
