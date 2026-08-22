import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/design.dart';
import '../../app/page_routes.dart';
import '../../core/db/database.dart';
import '../../core/models/enums.dart';
import '../../core/storage/storage_quota.dart';
import '../../core/sync/sync_providers.dart';
import '../sync/sync_indicator.dart';
import 'data/import_service.dart';
import 'data/library_repository.dart';
import 'document_transfer.dart';
import 'providers.dart';
import 'widgets/convert_to_pdf_dialog.dart';
import 'widgets/create_sheet.dart';
import 'widgets/document_card.dart';
import 'widgets/library_sidebar.dart';
import 'widgets/new_notebook_sheet.dart';

/// The library shelf. [parentId] null = root; otherwise a folder's contents.
///
/// Two layouts share one body: above [kSidebarBreakpoint] a persistent sidebar
/// plus a toolbar header, below it a phone layout with a large title, filter
/// chips and a FAB. Both render the same grid, so document presentation only
/// exists once.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, required this.parentId});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= AppBreakpoints.librarySidebar;
    final phone = width < AppBreakpoints.phone;
    // Sections are a root-level idea; inside a folder we always show its
    // children, so the chips/sidebar selection is ignored there.
    final inFolder = parentId != null;

    return Scaffold(
      backgroundColor: context.tokens.canvas,
      body: wide
          ? Row(
              children: [
                if (!inFolder) const LibrarySidebar(),
                Expanded(child: _Pane(parentId: parentId, wide: true)),
              ],
            )
          : _Pane(parentId: parentId, wide: false),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.extended(
              onPressed: () => runCreateFlow(context, ref, parentId: parentId),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New'),
            ),
      bottomNavigationBar: phone && parentId == null
          ? const _MobileLibraryNav()
          : null,
    );
  }
}

/// Compact navigation from the Android/iOS redesign. Filters remain available
/// as chips above the grid; the bottom bar keeps the three destinations used
/// most often within thumb reach.
class _MobileLibraryNav extends ConsumerWidget {
  const _MobileLibraryNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(librarySectionProvider);
    final t = context.tokens;

    Widget destination({
      required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? t.accentText : t.textMuted,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? t.accentText : t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: t.surfaceAlt,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: Row(
            children: [
              destination(
                icon: Icons.description_outlined,
                label: 'Docs',
                selected: section == LibrarySection.all,
                onTap: () => ref.read(librarySectionProvider.notifier).state =
                    LibrarySection.all,
              ),
              destination(
                icon: Icons.star_outline_rounded,
                label: 'Starred',
                selected: section == LibrarySection.starred,
                onTap: () => ref.read(librarySectionProvider.notifier).state =
                    LibrarySection.starred,
              ),
              destination(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: false,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header + grid, shared by both layouts.
class _Pane extends ConsumerWidget {
  const _Pane({required this.parentId, required this.wide});

  final String? parentId;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inFolder = parentId != null;
    final section = inFolder
        ? LibrarySection.all
        : ref.watch(librarySectionProvider);
    final docsAsync = inFolder
        ? ref.watch(folderChildrenProvider(parentId))
        : switch (section) {
            LibrarySection.all => ref.watch(folderChildrenProvider(null)),
            LibrarySection.recent => ref.watch(recentsProvider),
            LibrarySection.starred => ref.watch(starredProvider),
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          _DesktopHeader(parentId: parentId)
        else
          _MobileHeader(parentId: parentId),
        Expanded(
          child: docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (docs) {
              if (docs.isEmpty) {
                return _EmptyState(section: section, inFolder: inFolder);
              }
              return _Body(
                docs: docs,
                parentId: parentId,
                section: section,
                wide: wide,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- headers --

/// Desktop toolbar: search field, view toggle, sort, and the New button.
class _DesktopHeader extends ConsumerWidget {
  const _DesktopHeader({required this.parentId});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final gridMode = ref.watch(libraryGridModeProvider);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (parentId != null) ...[
              IconButton(
                icon: Icon(notablyBackIcon),
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(child: _SearchField(ref: ref)),
            const SizedBox(width: 12),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Segmented(
                      options: const [
                        (Icons.grid_view_rounded, 'Grid'),
                        (Icons.view_list_rounded, 'List'),
                      ],
                      selected: gridMode ? 0 : 1,
                      onSelect: (i) =>
                          ref.read(libraryGridModeProvider.notifier).state =
                              i == 0,
                    ),
                    const SizedBox(width: 10),
                    _SortButton(ref: ref),
                    const SizedBox(width: 10),
                    const _RefreshButton(),
                    const SyncIndicator(),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => context.push('/settings'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () =>
                          runCreateFlow(context, ref, parentId: parentId),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: const Text('New'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone header: big title, icon actions, and the section chips.
class _MobileHeader extends ConsumerWidget {
  const _MobileHeader({required this.parentId});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final inFolder = parentId != null;
    final section = ref.watch(librarySectionProvider);
    final title = inFolder
        ? (ref.watch(documentProvider(parentId!)).asData?.value?.title ??
              'Folder')
        : 'Library';

    return Container(
      color: t.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 8, 12),
              child: Row(
                children: [
                  if (inFolder)
                    IconButton(
                      icon: Icon(notablyBackIcon),
                      onPressed: () => context.pop(),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: t.text,
                      ),
                    ),
                  ),
                  const _RefreshButton(),
                  const SyncIndicator(),
                  IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => showSearch(
                      context: context,
                      delegate: _LibrarySearchDelegate(ref),
                    ),
                  ),
                  _SortButton(ref: ref),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            if (!inFolder)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final s in LibrarySection.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Chip(
                          label: s.shortLabel,
                          selected: section == s,
                          onTap: () =>
                              ref.read(librarySectionProvider.notifier).state =
                                  s,
                        ),
                      ),
                    // Not a filter — Trash has its own screen, with the
                    // restore and empty actions the grid doesn't offer.
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(
                        label: 'Trash',
                        selected: false,
                        onTap: () => context.push('/trash'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.accent : t.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? t.accent : t.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.control),
      onTap: () =>
          showSearch(context: context, delegate: _LibrarySearchDelegate(ref)),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: t.line),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 19, color: t.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search documents…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: t.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS-style segmented control: a recessed track with a raised active pill.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<(IconData, String)> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            Tooltip(
              message: options[i].$2,
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: i == selected ? t.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.inner),
                    boxShadow: i == selected
                        ? [
                            BoxShadow(
                              color: t.shadow.withValues(alpha: 0.10),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    options[i].$1,
                    size: 19,
                    color: i == selected ? t.text : t.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- body --

class _Body extends StatelessWidget {
  const _Body({
    required this.docs,
    required this.parentId,
    required this.section,
    required this.wide,
  });

  final List<Document> docs;
  final String? parentId;
  final LibrarySection section;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gridMode = ProviderScope.containerOf(
      context,
    ).read(libraryGridModeProvider);
    final pad = wide ? 28.0 : 20.0;

    // Pull-to-refresh does exactly what the toolbar button does. On a tablet
    // reaching for the toolbar is fine; on a phone, dragging the shelf down is
    // the gesture people already try when they want to know whether something
    // deleted elsewhere has really gone.
    return RefreshIndicator(
      onRefresh: () async {
        final ref = ProviderScope.containerOf(context);
        final engine = ref.read(syncEngineProvider);
        if (engine != null && !ref.read(syncPausedProvider)) {
          await engine.refreshNow();
        }
      },
      child: CustomScrollView(
        // Always scrollable, or a shelf with one card is too short to drag
        // and the gesture silently does nothing.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, wide ? 24 : 10, pad, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: parentId == null ? section.label : 'Contents',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.text,
                            ),
                          ),
                          TextSpan(
                            text: '  · ${docs.length}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: t.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (wide)
                    Text(
                      _sortCaption(context),
                      style: AppTokens.mono(size: 12, color: t.textFaint),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 110),
            sliver: gridMode || !wide
                ? SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      // Wider tiles on desktop (4 across a 1160px pane), two
                      // columns on a phone.
                      maxCrossAxisExtent: wide ? 230 : 190,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: wide ? 22 : 16,
                      mainAxisSpacing: wide ? 22 : 18,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => DocumentCard(
                        document: docs[i],
                        onTap: () => _open(context, docs[i]),
                        onLongPress: () =>
                            showDocumentActions(context, docs[i]),
                        onStarTap: () => _toggleStar(context, docs[i]),
                        onMore: () => showDocumentActions(context, docs[i]),
                      ),
                      childCount: docs.length,
                    ),
                  )
                : SliverList.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, i) => _ListRow(doc: docs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  static String _sortCaption(BuildContext context) {
    final sort = ProviderScope.containerOf(context).read(librarySortProvider);
    return switch (sort) {
      LibrarySort.modifiedDesc => 'Sorted by last modified',
      LibrarySort.createdDesc => 'Sorted by date created',
      LibrarySort.nameAsc => 'Sorted by name (A–Z)',
      LibrarySort.nameDesc => 'Sorted by name (Z–A)',
    };
  }
}

class _ListRow extends ConsumerWidget {
  const _ListRow({required this.doc});
  final Document doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final pendingUpload =
        ref.watch(pendingUploadDocumentsProvider).asData?.value ?? const {};
    final missingLocal =
        ref.watch(missingLocalFileDocumentsProvider).asData?.value ?? const {};
    final paused = ref.watch(syncPausedProvider);
    final status = ref.watch(syncStatusProvider);
    final transfer = documentTransferState(
      documentId: doc.id,
      pendingUpload: pendingUpload,
      missingLocal: missingLocal,
      status: status,
      paused: paused,
    );
    final locked = transfer.locked;
    final badgeLabel = transfer.listBadgeLabel(status);
    final showTransfer = transfer.kind != DocumentTransferKind.none;

    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.control),
          onTap: locked ? null : () => _open(context, doc),
          onLongPress: () => showDocumentActions(context, doc),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: t.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    showTransfer
                        ? (transfer.kind == DocumentTransferKind.downloading
                            ? Icons.cloud_download_outlined
                            : Icons.cloud_upload_outlined)
                        : switch (doc.type) {
                            DocumentType.folder => Icons.folder_rounded,
                            DocumentType.notebook => Icons.menu_book_rounded,
                            DocumentType.pdf => Icons.picture_as_pdf_rounded,
                          },
                    size: 19,
                    color: showTransfer
                        ? t.textSecondary
                        : doc.type == DocumentType.pdf
                            ? t.pdfBadge
                            : t.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                      if (badgeLabel != null)
                        Text(
                          badgeLabel,
                          style: AppTokens.mono(size: 11, color: t.textFaint),
                        ),
                    ],
                  ),
                ),
                if (!showTransfer)
                  Text(
                    DateFormat.MMMd().format(doc.updatedAt),
                    style: AppTokens.mono(size: 11, color: t.textFaint),
                  ),
                if (!locked)
                  IconButton(
                    icon: Icon(
                      doc.starred
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 19,
                    ),
                    color: doc.starred ? t.star : t.textFaint,
                    onPressed: () => _toggleStar(context, doc),
                  ),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  color: t.textMuted,
                  onPressed: () => showDocumentActions(context, doc),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _open(BuildContext context, Document d) {
  final container = ProviderScope.containerOf(context);
  final pendingUpload =
      container.read(pendingUploadDocumentsProvider).asData?.value ?? const {};
  final missingLocal =
      container.read(missingLocalFileDocumentsProvider).asData?.value ??
          const {};
  final paused = container.read(syncPausedProvider);
  final status = container.read(syncStatusProvider);
  final transfer = documentTransferState(
    documentId: d.id,
    pendingUpload: pendingUpload,
    missingLocal: missingLocal,
    status: status,
    paused: paused,
  );
  if (transfer.locked) {
    final pct = transfer.percent(status);
    final pctLabel = pct != null ? ' ($pct%)' : '';
    final verb = transfer.kind == DocumentTransferKind.downloading
        ? 'downloading'
        : 'uploading';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Still $verb$pctLabel — try again when sync finishes.'),
      ),
    );
    return;
  }
  if (d.type == DocumentType.folder) {
    context.push('/folder/${d.id}');
  } else {
    container.read(libraryRepositoryProvider).touchOpened(d.id);
    context.push('/doc/${d.id}');
  }
}

void _toggleStar(BuildContext context, Document d) {
  ProviderScope.containerOf(
    context,
  ).read(libraryRepositoryProvider).setStarred(d.id, !d.starred);
}

// ---------------------------------------------------------------- actions --

/// Long-press action sheet for a document.
Future<void> showDocumentActions(BuildContext context, Document d) async {
  final container = ProviderScope.containerOf(context);
  final repo = container.read(libraryRepositoryProvider);
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                d.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontSize: 16),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline_rounded),
            title: const Text('Rename'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final name = await promptText(context, 'Rename', d.title);
              if (name != null) repo.rename(d.id, name);
            },
          ),
          ListTile(
            leading: Icon(
              d.starred ? Icons.star_outline_rounded : Icons.star_rounded,
            ),
            title: Text(d.starred ? 'Remove star' : 'Add star'),
            onTap: () {
              Navigator.pop(sheetContext);
              repo.setStarred(d.id, !d.starred);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Details'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await _showDetails(context, repo, d);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(sheetContext).colorScheme.error,
            ),
            title: Text(
              'Move to Trash',
              style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
            ),
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
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _showDetails(
  BuildContext context,
  LibraryRepository repo,
  Document d,
) async {
  final pages = d.type == DocumentType.folder ? 0 : await repo.pageCount(d.id);
  final fileBytes =
      d.type == DocumentType.folder ? null : await repo.storageBytesFor(d.id);
  final fmt = DateFormat.yMMMd().add_jm();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(d.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow(context, 'Type', switch (d.type) {
            DocumentType.folder => 'Folder',
            DocumentType.notebook => 'Notebook',
            DocumentType.pdf => 'PDF',
          }),
          if (d.type != DocumentType.folder)
            _detailRow(context, 'Pages', '$pages'),
          if (fileBytes != null && fileBytes > 0)
            _detailRow(context, 'File size', formatStorageBytes(fileBytes)),
          _detailRow(context, 'Created', fmt.format(d.createdAt)),
          _detailRow(context, 'Modified', fmt.format(d.updatedAt)),
          if (d.starred) _detailRow(context, 'Starred', 'Yes'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Widget _detailRow(BuildContext context, String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 84,
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: context.tokens.textMuted),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: AppTokens.mono(size: 12.5, color: context.tokens.text),
        ),
      ),
    ],
  ),
);

Future<String?> promptText(BuildContext context, String title, String initial) {
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ----------------------------------------------------------------- create --

/// Opens the create sheet and carries out whatever the user picked.
Future<void> runCreateFlow(
  BuildContext context,
  WidgetRef ref, {
  required String? parentId,
}) async {
  final action = await CreateSheet.show(context);
  if (action == null || !context.mounted) return;

  switch (action) {
    case CreateAction.notebook:
      await NewNotebookSheet.show(context, parentId: parentId);
    case CreateAction.folder:
      final name = await promptText(context, 'New folder', 'New Folder');
      if (name != null && name.isNotEmpty) {
        await ref
            .read(libraryRepositoryProvider)
            .createFolder(parentId: parentId, title: name);
      }
    case CreateAction.importPdf:
      if (!await _ensureStorageAvailable(context, ref)) return;
      if (!context.mounted) return;
      await _import(context, ref, isPdf: true, parentId: parentId);
    case CreateAction.importImages:
      if (!await _ensureStorageAvailable(context, ref)) return;
      if (!context.mounted) return;
      await _import(context, ref, isPdf: false, parentId: parentId);
    case CreateAction.scan:
      if (!await _ensureStorageAvailable(context, ref)) return;
      if (!context.mounted) return;
      await _scan(context, ref, parentId: parentId);
  }
}

/// Blocks PDF/image/scan imports when the 5 GB allowance is already full.
Future<bool> _ensureStorageAvailable(
  BuildContext context,
  WidgetRef ref,
) async {
  final used = await ref.read(assetRepositoryProvider).totalBytes();
  if (used < kStorageQuotaBytes) return true;
  if (!context.mounted) return false;
  await showStorageQuotaDialog(
    context,
    StorageQuotaExceeded(usedBytes: used, neededBytes: 1),
  );
  return false;
}

Future<void> showStorageQuotaDialog(
  BuildContext context,
  StorageQuotaExceeded error,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(error.title),
      content: Text(error.message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Captures pages from the camera one at a time — asking "add another page?"
/// between shots — then builds a notebook from them.
Future<void> _scan(
  BuildContext context,
  WidgetRef ref, {
  required String? parentId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final service = ref.read(importServiceProvider);
  final pages = <ImagePayload>[];

  try {
    while (true) {
      final page = await service.captureScanPage();
      // Cancelling the camera keeps whatever was captured before it.
      if (page == null) break;
      pages.add(page);
      if (!context.mounted) return;
      final again = await showDialog<bool>(
        context: context,
        builder: (_) => _ScanAnotherDialog(pageCount: pages.length),
      );
      if (again != true) break;
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    return;
  }

  if (pages.isEmpty) return;

  final progress = ValueNotifier<(double, String)>((0, 'Saving pages…'));
  var dialogOpen = false;
  try {
    if (context.mounted) {
      dialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _ImportProgressDialog(title: 'Building scan', progress: progress),
      );
    }
    final id = await service.createImageDocument(
      images: pages,
      parentId: parentId,
      onProgress: (f, label) => progress.value = (f, label),
    );
    if (dialogOpen && context.mounted) Navigator.of(context).pop();
    dialogOpen = false;
    if (id != null) {
      ref.read(libraryRepositoryProvider).touchOpened(id);
      router.push('/doc/$id');
    }
  } on StorageQuotaExceeded catch (error) {
    if (dialogOpen && context.mounted) Navigator.of(context).pop();
    dialogOpen = false;
    if (context.mounted) await showStorageQuotaDialog(context, error);
  } catch (e) {
    if (dialogOpen && context.mounted) Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('Scan failed: $e')));
  } finally {
    progress.dispose();
  }
}

/// Between-capture prompt for the scanner: keep shooting or finish.
class _ScanAnotherDialog extends StatelessWidget {
  const _ScanAnotherDialog({required this.pageCount});

  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('$pageCount page${pageCount == 1 ? '' : 's'} captured'),
      content: const Text(
        'Scan another page, or finish and open the document?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Done'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Scan another'),
        ),
      ],
    );
  }
}

Future<void> _import(
  BuildContext context,
  WidgetRef ref, {
  required bool isPdf,
  required String? parentId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final service = ref.read(importServiceProvider);
  final progress = ValueNotifier<(double, String)>((0, 'Choose a file…'));
  var dialogOpen = false;

  void showProgressDialog() {
    dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(
        title: isPdf ? 'Importing PDF' : 'Importing images',
        progress: progress,
      ),
    );
  }

  try {
    final id = isPdf
        ? await service.importPdf(
            parentId: parentId,
            onProgress: (f, label) {
              if (!dialogOpen) showProgressDialog();
              progress.value = (f, label);
            },
          )
        : await service.importImages(
            parentId: parentId,
            onProgress: (f, label) {
              if (!dialogOpen) showProgressDialog();
              progress.value = (f, label);
            },
          );
    if (dialogOpen && context.mounted) Navigator.of(context).pop();
    dialogOpen = false;
    if (id != null) {
      ref.read(libraryRepositoryProvider).touchOpened(id);
      router.push('/doc/$id');
    }
  } on UnsupportedImportFormat catch (failure) {
    // Not really an error — the user picked a PowerPoint/Word file, so
    // explain the one step needed rather than showing a failure.
    if (dialogOpen && context.mounted) Navigator.of(context).pop();
    dialogOpen = false;
    if (context.mounted) await ConvertToPdfDialog.show(context, failure);
  } on StorageQuotaExceeded catch (error) {
    if (dialogOpen && context.mounted) Navigator.of(context).pop();
    dialogOpen = false;
    if (context.mounted) await showStorageQuotaDialog(context, error);
  } catch (e) {
    if (dialogOpen && context.mounted) Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  } finally {
    progress.dispose();
  }
}

/// Modal progress dialog shown while a PDF/image import runs.
class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.title, required this.progress});

  final String title;
  final ValueNotifier<(double, String)> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: ValueListenableBuilder<(double, String)>(
        valueListenable: progress,
        builder: (context, value, _) {
          final (fraction, label) = value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: fraction <= 0 ? null : fraction.clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(fraction * 100).round()}%',
                    style: AppTokens.mono(size: 13, weight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pulls the account down again from scratch.
///
/// Sync is already automatic — local edits and Firestore snapshots both
/// trigger it — so this exists for the case automation cannot cover: being
/// sure. A delete made on another device is the one change where "it will
/// turn up eventually" is not good enough, and unlike the routine pull this
/// ignores the incremental cursor, so it cannot be defeated by two devices
/// disagreeing about the time.
class _RefreshButton extends ConsumerStatefulWidget {
  const _RefreshButton();

  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton> {
  bool _spinning = false;

  Future<void> _refresh() async {
    setState(() => _spinning = true);
    try {
      await refreshLibrary(context, ref);
    } finally {
      // The widget can be gone by now — a refresh outlives a rotation.
      if (mounted) setState(() => _spinning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(syncEngineProvider);
    if (engine == null) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Refresh from the cloud',
      onPressed: _spinning ? null : _refresh,
      icon: _spinning
          ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded),
    );
  }
}

/// Shared by the toolbar button and pull-to-refresh so both behave the same.
Future<void> refreshLibrary(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final engine = ref.read(syncEngineProvider);
  if (engine == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Sign in to sync with your other devices.')),
    );
    return;
  }
  if (ref.read(syncPausedProvider)) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Sync is paused — resume it from the cloud menu.'),
      ),
    );
    return;
  }
  await engine.refreshNow();
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
        PopupMenuItem(
          value: LibrarySort.modifiedDesc,
          child: Text('Last modified'),
        ),
        PopupMenuItem(
          value: LibrarySort.createdDesc,
          child: Text('Date created'),
        ),
        PopupMenuItem(value: LibrarySort.nameAsc, child: Text('Name (A–Z)')),
        PopupMenuItem(value: LibrarySort.nameDesc, child: Text('Name (Z–A)')),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.section, required this.inFolder});

  final LibrarySection section;
  final bool inFolder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (icon, title, hint) = switch (section) {
      _ when inFolder => (
        Icons.folder_open_rounded,
        'This folder is empty',
        'Add a notebook or import a PDF into it',
      ),
      LibrarySection.starred => (
        Icons.star_outline_rounded,
        'Nothing starred yet',
        'Star a document to keep it within reach',
      ),
      LibrarySection.recent => (
        Icons.schedule_rounded,
        'No recent documents',
        'Documents you open will show up here',
      ),
      LibrarySection.all => (
        Icons.auto_stories_rounded,
        'Nothing here yet',
        'Tap New to create a notebook or import a PDF',
      ),
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: t.fill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 34, color: t.textFaint),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(hint, style: TextStyle(fontSize: 13.5, color: t.textMuted)),
        ],
      ),
    );
  }
}

class _LibrarySearchDelegate extends SearchDelegate<void> {
  _LibrarySearchDelegate(this.ref);
  final WidgetRef ref;

  @override
  String get searchFieldLabel => 'Search documents…';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: Icon(notablyBackIcon),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final t = context.tokens;
    final repo = ref.read(libraryRepositoryProvider);
    if (query.trim().isEmpty) {
      return Center(
        child: Text(
          'Type to search your notes',
          style: TextStyle(color: t.textMuted),
        ),
      );
    }
    return StreamBuilder<List<Document>>(
      stream: repo.watchSearch(query),
      builder: (context, snap) {
        final docs = snap.data ?? const [];
        if (docs.isEmpty) {
          return Center(
            child: Text('No matches', style: TextStyle(color: t.textMuted)),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final d in docs)
              ListTile(
                leading: Icon(switch (d.type) {
                  DocumentType.folder => Icons.folder_rounded,
                  DocumentType.notebook => Icons.menu_book_rounded,
                  DocumentType.pdf => Icons.picture_as_pdf_rounded,
                }),
                title: Text(d.title),
                subtitle: Text(
                  DateFormat.yMMMd().format(d.updatedAt),
                  style: AppTokens.mono(size: 11, color: t.textFaint),
                ),
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
