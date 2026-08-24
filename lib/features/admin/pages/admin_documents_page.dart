import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../admin_access.dart';
import '../admin_api.dart';
import '../csv_export.dart';
import '../widgets/admin_widgets.dart';

enum _DocSort { storage, files, email }

class AdminDocumentsPage extends ConsumerStatefulWidget {
  const AdminDocumentsPage({super.key});

  @override
  ConsumerState<AdminDocumentsPage> createState() => _AdminDocumentsPageState();
}

class _AdminDocumentsPageState extends ConsumerState<AdminDocumentsPage> {
  var _sort = _DocSort.storage;

  List<AdminDocumentRow> _sorted(List<AdminDocumentRow> docs) {
    final copy = [...docs];
    copy.sort((a, b) {
      switch (_sort) {
        case _DocSort.storage:
          return b.storageBytes.compareTo(a.storageBytes);
        case _DocSort.files:
          return b.fileCount.compareTo(a.fileCount);
        case _DocSort.email:
          return (a.email ?? a.uid).toLowerCase().compareTo(
                (b.email ?? b.uid).toLowerCase(),
              );
      }
    });
    return copy;
  }

  Future<void> _deleteFiles(AdminDocumentRow row) async {
    final api = ref.read(adminApiServiceProvider);
    if (api == null) return;
    final label = row.email ?? shortUid(row.uid);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete files for $label?'),
        content: const Text(
          'Removes this user’s PDFs and images from R2. '
          'Their login and subscription stay. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete files'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final n = await api.deleteUserFiles(row.uid);
      ref.invalidate(adminDocumentsProvider);
      ref.invalidate(adminOverviewProvider(30));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $n file${n == 1 ? '' : 's'} for $label.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final docsAsync = ref.watch(adminDocumentsProvider);
    final canWrite = ref.watch(adminCanWriteProvider);

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
                subtitle:
                    '${docs.length} users · $totalFiles files · ${formatStorageBytes(totalBytes)} in R2',
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await exportCsv(
                          filename: 'notably-documents.csv',
                          headers: const ['uid', 'email', 'files', 'storage_bytes'],
                          rows: [
                            for (final d in _sorted(docs))
                              [d.uid, d.email ?? '', '${d.fileCount}', '${d.storageBytes}'],
                          ],
                        );
                      },
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('CSV'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<_DocSort>(
            segments: const [
              ButtonSegment(value: _DocSort.storage, label: Text('Storage')),
              ButtonSegment(value: _DocSort.files, label: Text('Files')),
              ButtonSegment(value: _DocSort.email, label: Text('User')),
            ],
            selected: {_sort},
            onSelectionChanged: (s) => setState(() => _sort = s.first),
          ),
          const SizedBox(height: 16),
          docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(adminDocumentsProvider),
            ),
            data: (docs) {
              final rows = _sorted(docs);
              return AdminDataTable(
                columns: [
                  'User',
                  'Files',
                  'Storage',
                  if (canWrite) '',
                ],
                actionWidth: 52,
                emptyMessage: 'No files uploaded yet.',
                rows: [
                  for (final d in rows)
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
                      if (canWrite)
                        IconButton(
                          tooltip: 'Delete files',
                          icon: Icon(Icons.delete_outline, color: t.pdfBadge),
                          onPressed: d.fileCount == 0 ? null : () => _deleteFiles(d),
                        ),
                    ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
