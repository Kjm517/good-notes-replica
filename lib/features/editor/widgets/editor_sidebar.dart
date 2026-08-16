import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../../core/db/database.dart';
import '../../../core/models/outline_entry.dart';
import '../providers.dart';
import 'page_preview.dart';

/// Which panel the sidebar is showing.
enum SidebarTab { thumbnails, outline }

/// Logical width of a sidebar page thumbnail.
const double _kThumbWidth = 186;

/// PDF-reader style left sidebar: page thumbnails ("page guides") and an
/// outline of bookmarked pages. Collapsible from the top toolbar.
class EditorSidebar extends ConsumerStatefulWidget {
  const EditorSidebar({
    super.key,
    required this.documentId,
    required this.pages,
    required this.currentIndex,
    required this.defaultPageSize,
    required this.onJumpToPage,
    this.outline = const [],
  });

  final String documentId;
  final List<NotePage> pages;
  final int currentIndex;
  final Size defaultPageSize;
  final void Function(int index) onJumpToPage;

  /// The source PDF's embedded table of contents, extracted in the background.
  /// Empty for notebooks, image imports, or PDFs without an outline.
  final List<OutlineEntry> outline;

  @override
  ConsumerState<EditorSidebar> createState() => _EditorSidebarState();
}

class _EditorSidebarState extends ConsumerState<EditorSidebar> {
  SidebarTab _tab = SidebarTab.thumbnails;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Size _sizeFor(NotePage page) {
    final w = page.pageW;
    final h = page.pageH;
    if (w != null && h != null) return Size(w, h);
    return widget.defaultPageSize;
  }

  double _thumbExtent(NotePage page) {
    final size = _sizeFor(page);
    final aspect = size.width == 0 ? 1.3 : size.height / size.width;
    return 14 + _kThumbWidth * aspect + 20;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: Column(
        children: [
          // Tab switcher: a recessed track with a raised pill on the active
          // tab, matching the segmented controls used elsewhere.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Container(
              height: 36,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  for (final tab in SidebarTab.values)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _tab = tab),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tab == tab ? t.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(Radii.inner),
                            boxShadow: _tab == tab
                                ? [
                                    BoxShadow(
                                      color: t.shadow.withValues(alpha: 0.10),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            tab == SidebarTab.thumbnails ? 'Pages' : 'Outline',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _tab == tab
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _tab == tab ? t.text : t.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _tab == SidebarTab.thumbnails
                ? _thumbnails()
                : _outline(context),
          ),
        ],
      ),
    );
  }

  Widget _thumbnails() {
    final first = widget.pages.isEmpty ? null : widget.pages.first;
    final uniform = first != null &&
        widget.pages.length > 1 &&
        _sizeFor(widget.pages.last) == _sizeFor(first);
    final extent = first == null ? null : _thumbExtent(first);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.pages.length,
      itemExtent: uniform ? extent : null,
      cacheExtent: 240,
      itemBuilder: (context, i) {
        final page = widget.pages[i];
        final selected = i == widget.currentIndex;
        return _ThumbTile(
          key: ValueKey(page.id),
          page: page,
          pageSize: _sizeFor(page),
          number: i + 1,
          selected: selected,
          onTap: () => widget.onJumpToPage(i),
        );
      },
    );
  }

  Widget _outline(BuildContext context) {
    final t = context.tokens;

    // The PDF's own table of contents (clamped to real pages, in case the file
    // referenced pages we didn't import).
    final toc = [
      for (final e in widget.outline)
        if (e.pageIndex >= 0 && e.pageIndex < widget.pages.length) e,
    ];

    // Pages the user bookmarked by hand.
    final marked = <int>[];
    for (var i = 0; i < widget.pages.length; i++) {
      if ((widget.pages[i].bookmarkTitle ?? '').isNotEmpty) marked.add(i);
    }

    if (toc.isEmpty && marked.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 34, color: t.textFaint),
            const SizedBox(height: 12),
            Text(
              'No outline yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'PDFs with a table of contents show it here. '
              'Bookmark a page to add your own.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          ],
        ),
      );
    }

    final showSections = toc.isNotEmpty && marked.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        if (showSections) _sectionLabel(context, 'Contents'),
        for (final entry in toc)
          _OutlineTile(
            title: entry.title,
            pageNumber: entry.pageIndex + 1,
            depth: entry.depth,
            selected: entry.pageIndex == widget.currentIndex,
            onTap: () => widget.onJumpToPage(entry.pageIndex),
          ),
        if (showSections) ...[
          const SizedBox(height: 6),
          _sectionLabel(context, 'Bookmarks'),
        ],
        for (final index in marked)
          _OutlineTile(
            title: widget.pages[index].bookmarkTitle!,
            pageNumber: index + 1,
            depth: 0,
            bookmark: true,
            selected: index == widget.currentIndex,
            onTap: () => widget.onJumpToPage(index),
          ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Text(text.toUpperCase(),
          style: AppTokens.sectionLabel(context.tokens.textFaint)),
    );
  }
}

/// One row in the outline: a TOC entry (indented by depth) or a manual
/// bookmark. Tapping it jumps to the page.
class _OutlineTile extends StatelessWidget {
  const _OutlineTile({
    required this.title,
    required this.pageNumber,
    required this.depth,
    required this.selected,
    required this.onTap,
    this.bookmark = false,
  });

  final String title;
  final int pageNumber;
  final int depth;
  final bool selected;
  final bool bookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Indent nested entries; cap the depth so a deep outline never marches off
    // the edge of a 240px sidebar.
    final indent = 18.0 + (depth.clamp(0, 5)) * 14.0;
    final topLevel = depth == 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? t.accentSoft : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? t.accent : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(indent - 2, 7, 12, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bookmark) ...[
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 6),
                child: Icon(Icons.bookmark_rounded,
                    size: 14, color: t.accentText),
              ),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: topLevel ? 13 : 12.5,
                  height: 1.3,
                  fontWeight:
                      topLevel ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? t.accentText
                      : (topLevel ? t.text : t.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '$pageNumber',
                style: AppTokens.mono(
                  size: 10.5,
                  color: selected ? t.accentText : t.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One sidebar page thumbnail.
class _ThumbTile extends ConsumerStatefulWidget {
  const _ThumbTile({
    super.key,
    required this.page,
    required this.pageSize,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final NotePage page;
  final Size pageSize;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  ConsumerState<_ThumbTile> createState() => _ThumbTileState();
}

class _ThumbTileState extends ConsumerState<_ThumbTile> {
  ui.Image? _image;

  bool get _hasBackground =>
      widget.page.pdfAssetId != null || widget.page.bgAssetId != null;

  @override
  void initState() {
    super.initState();
    if (_hasBackground) {
      // Wait one frame so MediaQuery (device pixel ratio) is available, but
      // bail if the tile was scrolled away and disposed in the meantime —
      // touching `context` after unmount throws.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    // Render at physical pixels so the preview isn't upscaled (blurry).
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final target = (_kThumbWidth * dpr).clamp(180.0, 700.0);
    final img = await ref
        .read(pageBackgroundServiceProvider)
        .loadThumbnail(widget.page, targetWidth: target);
    if (!mounted) {
      img?.dispose();
      return;
    }
    setState(() {
      final previous = _image;
      _image = img;
      previous?.dispose();
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final aspect = widget.pageSize.height / widget.pageSize.width;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.selected ? t.accent : t.line,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.shadow.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1 / aspect,
                // Composites background + ink + images, so the preview shows
                // the annotations rather than just the source page.
                child: (_hasBackground && _image == null)
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : PagePreview(
                        page: widget.page,
                        baseSize: widget.pageSize,
                        background: _image,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('${widget.number}',
              style: AppTokens.mono(
                size: 11,
                weight: widget.selected ? FontWeight.w700 : FontWeight.w400,
                color: widget.selected ? t.accentText : t.textFaint,
              )),
        ],
      ),
    );
  }
}
