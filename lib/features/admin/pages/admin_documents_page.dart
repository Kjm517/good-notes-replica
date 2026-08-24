import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_api.dart';
import '../widgets/admin_widgets.dart';

class AdminDocumentsPage extends ConsumerWidget {
  const AdminDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final docsAsync = ref.watch(adminDocumentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          docsAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (docs) {
              final totalBytes = docs.fold<int>(0, (s, d) => s + d.storageBytes);
              final totalFiles = docs.fold<int>(0, (s, d) => s + d.fileCount);
              return AdminPageHeader(
                title: 'Documents',
                subtitle: '${docs.length} users · $totalFiles files · ${formatStorageBytes(totalBytes)} in R2',
              );
            },
          ),
          const SizedBox(height: 16),
          docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminDocumentsProvider),
            ),
            data: (docs) => AdminDataTable(
              columns: const ['User', 'Files', 'Storage'],
              emptyMessage: 'No files uploaded yet.',
              rows: [
                for (final d in docs)
                  [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.email ?? shortUid(d.uid),
                          style: TextStyle(fontWeight: FontWeight.w600, color: t.text),
                        ),
                        Text(shortUid(d.uid), style: AppTokens.mono(size: 10, color: t.textFaint)),
                      ],
                    ),
                    Text('${d.fileCount}', style: AppTokens.mono(size: 12, color: t.textSecondary)),
                    Text(formatStorageBytes(d.storageBytes), style: TextStyle(color: t.textSecondary)),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
