import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import 'providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashAsync = ref.watch(trashProvider);
    final repo = ref.read(libraryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Empty Trash?'),
                  content: const Text('This permanently deletes all items.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Empty')),
                  ],
                ),
              );
              if (ok == true) repo.emptyTrash();
            },
            child: const Text('Empty'),
          ),
        ],
      ),
      body: trashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) {
          if (docs.isEmpty) {
            return const Center(child: Text('Trash is empty'));
          }
          return ListView(
            children: [
              for (final d in docs)
                ListTile(
                  leading: Icon(switch (d.type) {
                    DocumentType.folder => Icons.folder_rounded,
                    DocumentType.notebook => Icons.menu_book_rounded,
                    DocumentType.pdf => Icons.picture_as_pdf_rounded,
                  }),
                  title: Text(d.title),
                  subtitle: const Text('Deleted'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Restore',
                        icon: const Icon(Icons.restore_rounded),
                        onPressed: () => repo.restore(d.id),
                      ),
                      IconButton(
                        tooltip: 'Delete forever',
                        icon: const Icon(Icons.delete_forever_rounded),
                        onPressed: () => repo.deleteForever(d.id),
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
