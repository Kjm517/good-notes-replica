import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/models/enums.dart';
import 'data/library_repository.dart';
import 'providers.dart';
import 'widgets/document_card.dart';
import 'widgets/new_notebook_sheet.dart';

/// The library shelf. [parentId] null = root; otherwise a folder's contents.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, required this.parentId});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(folderChildrenProvider(parentId));
    final gridMode = ref.watch(libraryGridModeProvider);
    final isRoot = parentId == null;

    return Scaffold(
      appBar: AppBar(
        leading: isRoot
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
        title: _Title(parentId: parentId),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => showSearch(
              context: context,
              delegate: _LibrarySearchDelegate(ref),
            ),
          ),
          IconButton(
            tooltip: gridMode ? 'List view' : 'Grid view',
            icon: Icon(gridMode
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded),
            onPressed: () => ref
                .read(libraryGridModeProvider.notifier)
                .update((v) => !v),
          ),
          _SortButton(ref: ref),
          if (isRoot)
            IconButton(
              tooltip: 'Trash',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => context.push('/trash'),
            ),
          if (isRoot)
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      floatingActionButton: _NewButton(parentId: parentId),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) {
          if (docs.isEmpty) return _EmptyState(parentId: parentId);
          return gridMode
              ? _Grid(docs: docs, parentId: parentId)
              : _List(docs: docs, parentId: parentId);
        },
      ),
    );
  }
}

class _Title extends ConsumerWidget {
  const _Title({required this.parentId});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (parentId == null) return const Text('Library');
    final docAsync = ref.watch(documentProvider(parentId!));
    return Text(docAsync.asData?.value?.title ?? 'Folder');
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.docs, required this.parentId});
  final List<Document> docs;
  final String? parentId;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 0.72,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: docs.length,
      itemBuilder: (context, i) => _CardItem(doc: docs[i], parentId: parentId),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.docs, required this.parentId});
  final List<Document> docs;
  final String? parentId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = docs[i];
        return ListTile(
          leading: Icon(switch (d.type) {
            DocumentType.folder => Icons.folder_rounded,
            DocumentType.notebook => Icons.menu_book_rounded,
            DocumentType.pdf => Icons.picture_as_pdf_rounded,
          }),
          title: Text(d.title),
          trailing: IconButton(
            icon: Icon(d.starred
                ? Icons.star_rounded
                : Icons.star_border_rounded),
            color: d.starred ? Colors.amber : null,
            onPressed: () => _toggleStar(context, d),
          ),
          onTap: () => _open(context, d),
          onLongPress: () => showDocumentActions(context, d),
        );
      },
    );
  }
}

class _CardItem extends ConsumerWidget {
  const _CardItem({required this.doc, required this.parentId});
  final Document doc;
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DocumentCard(
      document: doc,
      onTap: () => _open(context, doc),
      onLongPress: () => showDocumentActions(context, doc),
      onStarTap: () => _toggleStar(context, doc),
    );
  }
}

void _open(BuildContext context, Document d) {
  final container = ProviderScope.containerOf(context);
  if (d.type == DocumentType.folder) {
    context.push('/folder/${d.id}');
  } else {
    container.read(libraryRepositoryProvider).touchOpened(d.id);
    context.push('/doc/${d.id}');
  }
}

void _toggleStar(BuildContext context, Document d) {
  ProviderScope.containerOf(context)
      .read(libraryRepositoryProvider)
      .setStarred(d.id, !d.starred);
}

/// Long-press action sheet for a document.
Future<void> showDocumentActions(BuildContext context, Document d) async {
  final container = ProviderScope.containerOf(context);
  final repo = container.read(libraryRepositoryProvider);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline_rounded),
            title: const Text('Rename'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final name = await _promptText(context, 'Rename', d.title);
              if (name != null) repo.rename(d.id, name);
            },
          ),
          ListTile(
            leading: Icon(d.starred
                ? Icons.star_outline_rounded
                : Icons.star_rounded),
            title: Text(d.starred ? 'Remove star' : 'Add star'),
            onTap: () {
              Navigator.pop(sheetContext);
              repo.setStarred(d.id, !d.starred);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Move to Trash'),
            onTap: () {
              Navigator.pop(sheetContext);
              repo.moveToTrash(d.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Moved "${d.title}" to Trash'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () => repo.restore(d.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

Future<String?> _promptText(
    BuildContext context, String title, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _NewButton extends ConsumerWidget {
  const _NewButton({required this.parentId});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _showNewMenu(context, ref),
      icon: const Icon(Icons.add_rounded),
      label: const Text('New'),
    );
  }

  void _showNewMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: const Text('Notebook'),
              onTap: () {
                Navigator.pop(sheetContext);
                NewNotebookSheet.show(context, parentId: parentId).then((_) {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_rounded),
              title: const Text('Folder'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final name =
                    await _promptText(context, 'New Folder', 'New Folder');
                if (name != null && name.isNotEmpty) {
                  ref
                      .read(libraryRepositoryProvider)
                      .createFolder(parentId: parentId, title: name);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LibrarySort>(
      icon: const Icon(Icons.sort_rounded),
      tooltip: 'Sort',
      onSelected: (s) => ref.read(librarySortProvider.notifier).state = s,
      itemBuilder: (context) => const [
        PopupMenuItem(value: LibrarySort.modifiedDesc, child: Text('Last modified')),
        PopupMenuItem(value: LibrarySort.createdDesc, child: Text('Date created')),
        PopupMenuItem(value: LibrarySort.nameAsc, child: Text('Name (A–Z)')),
        PopupMenuItem(value: LibrarySort.nameDesc, child: Text('Name (Z–A)')),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.parentId});
  final String? parentId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_rounded,
              size: 72, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          Text('Nothing here yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Tap New to create a notebook or folder',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}

class _LibrarySearchDelegate extends SearchDelegate<void> {
  _LibrarySearchDelegate(this.ref);
  final WidgetRef ref;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final repo = ref.read(libraryRepositoryProvider);
    if (query.trim().isEmpty) {
      return const Center(child: Text('Type to search your notes'));
    }
    return StreamBuilder<List<Document>>(
      stream: repo.watchSearch(query),
      builder: (context, snap) {
        final docs = snap.data ?? const [];
        if (docs.isEmpty) return const Center(child: Text('No matches'));
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
                onTap: () {
                  close(context, null);
                  _open(context, d);
                },
              ),
          ],
        );
      },
    );
  }
}
