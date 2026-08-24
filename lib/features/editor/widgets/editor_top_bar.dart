import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../../app/page_routes.dart';
import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../canvas/continuous_canvas.dart';
import '../providers.dart';
import '../state/tool_settings.dart';
import '../../sync/sync_indicator.dart';
import '../../settings/entitlements.dart';
import '../../settings/premium_providers.dart';
import 'color_picker_sheet.dart';
import 'export_sheet.dart';
import 'margins_sheet.dart';
import 'sticker_picker_sheet.dart';
import 'tool_options_sheet.dart';

/// How the toolbar arranges itself for the available width.
enum EditorBarLayout {
  /// Phone: title row only — the tools live in [EditorToolDock] at the bottom,
  /// within thumb reach.
  phone,

  /// Landscape tablet: compact title bar plus a permanent tool rail.
  tabletRail,

  /// Tablet portrait / small window: title row above a full-width tool row.
  stacked,

  /// Desktop: everything on one row with the tool group centred.
  single;

  /// Picks a layout from the window width (tests + callers that only have
  /// width). Prefer [forSize] when orientation is known.
  static EditorBarLayout forWidth(double width) {
    if (width < AppBreakpoints.phone) return EditorBarLayout.phone;
    if (width < AppBreakpoints.desktop) return EditorBarLayout.stacked;
    return EditorBarLayout.single;
  }

  /// Width + orientation aware — landscape tablets get the left tool rail;
  /// portrait tablets keep the stacked top tool row. Wide monitors (shortest
  /// side ≥ 1200) still use the single desktop row.
  static EditorBarLayout forSize(Size size) {
    if (size.width < AppBreakpoints.phone) return EditorBarLayout.phone;
    if (size.shortestSide >= AppBreakpoints.tabletShortest &&
        size.width > size.height &&
        size.shortestSide < 1200) {
      return EditorBarLayout.tabletRail;
    }
    if (size.width < AppBreakpoints.desktop) return EditorBarLayout.stacked;
    return EditorBarLayout.single;
  }

  /// Chrome the editor should paint for [size].
  ///
  /// Portrait tablets (iPad / Android) use the same bottom tool dock + compact
  /// title as iPhone so colour swatches, pen options, and the quiz upsell match
  /// the phone experience. Landscape tablets keep the side rail.
  static EditorBarLayout chromeForSize(Size size) {
    final base = forSize(size);
    if (base == EditorBarLayout.tabletRail || base == EditorBarLayout.single) {
      return base;
    }
    final tabletPortrait = size.shortestSide >= AppBreakpoints.tabletShortest &&
        size.height > size.width &&
        size.width < AppBreakpoints.desktop;
    if (tabletPortrait) return EditorBarLayout.phone;
    return base;
  }

  /// Tools rendered in the top bar (stacked / single).
  bool get showsTools =>
      this == EditorBarLayout.stacked || this == EditorBarLayout.single;

  /// Tools in the bottom dock (phone + portrait tablet chrome).
  bool get showsBottomDock => this == EditorBarLayout.phone;

  /// Tools in the permanent left rail (landscape tablet).
  bool get showsSideRail => this == EditorBarLayout.tabletRail;
}

// Row heights. Separators are drawn as a bottom *border inside* each row
// rather than as Divider widgets, so a row's painted height always equals its
// declared height. That keeps [EditorTopBar.preferredSize] exactly equal to
// the sum of the row heights — no off-by-one overflow is possible.
const double _kTitleRow = 56;

/// iOS phone title row — matches section 09 of the Annotate redesign.
const double _kPhoneTitleRow = 48;

const double _kToolRow = 60;
const double _kSingleRow = 60;

/// Title never eats the whole bar — it ellipsizes past this.
const double _kMaxTitleWidth = 320;

/// The editor's top chrome: document title, page navigation, zoom, and (on
/// anything wider than a phone) the tool group.
class EditorTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const EditorTopBar({
    super.key,
    required this.documentId,
    required this.title,
    required this.subtitle,
    required this.sidebarOpen,
    required this.onToggleSidebar,
    required this.currentIndex,
    required this.pageCount,
    required this.canvasController,
    required this.pageSizeFor,
    required this.onRename,
    required this.onToggleBookmark,
    required this.bookmarked,
    required this.onOpenPageSettings,
    required this.onFind,
    required this.onQuiz,
    required this.onBack,
    required this.layout,
    this.readingMode = false,
    this.onToggleReadingMode,
  });

  final String documentId;
  final String title;

  /// Secondary line under the title — the page position, in the mono face.
  final String subtitle;
  final bool sidebarOpen;
  final VoidCallback onToggleSidebar;
  final int currentIndex;
  final int pageCount;
  final ContinuousCanvasController canvasController;
  final Size Function(NotePage) pageSizeFor;
  final VoidCallback onRename;
  final VoidCallback onToggleBookmark;
  final bool bookmarked;
  final VoidCallback onOpenPageSettings;
  final EditorBarLayout layout;

  /// Opens "find in document" (also bound to Ctrl+F).
  final VoidCallback onFind;

  /// Opens the premium quiz-from-PDF flow (redesign §11).
  final VoidCallback onQuiz;
  final VoidCallback onBack;
  final bool readingMode;
  final VoidCallback? onToggleReadingMode;

  @override
  Size get preferredSize => Size.fromHeight(switch (layout) {
    EditorBarLayout.phone => _kPhoneTitleRow,
    EditorBarLayout.tabletRail => _kTitleRow,
    EditorBarLayout.stacked => _kTitleRow + _kToolRow,
    EditorBarLayout.single => _kSingleRow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Material(
      color: t.surfaceAlt,
      child: SafeArea(
        bottom: false,
        child: layout == EditorBarLayout.single
            ? _singleRow(context, ref)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _titleRow(context, ref),
                  if (layout == EditorBarLayout.stacked)
                    _toolRow(context, ref),
                ],
              ),
      ),
    );
  }

  // ---- Desktop: one row, tool group centred --------------------------------

  Widget _singleRow(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Container(
      height: _kSingleRow,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _leading(context),
          _flexibleTitle(context),
          const SizedBox(width: 12),
          _PageJump(
            currentIndex: currentIndex,
            pageCount: pageCount,
            controller: canvasController,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Full inline strip needs ~720 logical px; narrower windows
                // (resized desktop, split-screen) fall back to primary + More.
                final inline = constraints.maxWidth >= 720;
                return Center(
                  child: _ToolGroup(
                    documentId: documentId,
                    pageSizeFor: pageSizeFor,
                    showInlineSwatches: inline,
                  ),
                );
              },
            ),
          ),
          _ZoomControls(controller: canvasController),
          const _BarSeparator(),
          _UndoRedo(documentId: documentId),
          const _BarSeparator(),
          ..._trailing(context, ref),
        ],
      ),
    );
  }

  // ---- Row 1: back, sidebar, title, page nav, zoom -------------------------

  Widget _titleRow(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final phone = layout == EditorBarLayout.phone;
    return Container(
      height: phone ? _kPhoneTitleRow : _kTitleRow,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 10),
      child: Row(
        children: [
          _leading(context),
          if (phone)
            Expanded(child: Center(child: _titleBlock(context, phone: true)))
          else ...[
            _flexibleTitle(context),
            const SizedBox(width: 8),
            _PageJump(
              currentIndex: currentIndex,
              pageCount: pageCount,
              controller: canvasController,
            ),
          ],
          if (phone) ...[
            _BarIcon(
              icon: sidebarOpen
                  ? Icons.list_alt_rounded
                  : Icons.list_alt_outlined,
              tooltip: sidebarOpen ? 'Hide pages & outline' : 'Pages & outline',
              onPressed: onToggleSidebar,
              active: sidebarOpen,
            ),
            const SizedBox(width: 2),
          ],
          ..._trailing(context, ref),
        ],
      ),
    );
  }

  Widget _leading(BuildContext context) {
    final phone = layout == EditorBarLayout.phone;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarIcon(
          icon: notablyBackIcon,
          tooltip: 'Last page',
          onPressed: onBack,
        ),
        if (!phone) ...[
          _BarIcon(
            icon: sidebarOpen
                ? Icons.list_alt_rounded
                : Icons.list_alt_outlined,
            tooltip: sidebarOpen ? 'Hide pages & outline' : 'Pages & outline',
            onPressed: onToggleSidebar,
            active: sidebarOpen,
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  /// Title that yields space to page-jump and actions on a narrow iPad bar.
  Widget _flexibleTitle(BuildContext context) {
    return Flexible(
      child: Align(
        alignment: Alignment.centerLeft,
        child: _titleBlock(context),
      ),
    );
  }

  /// Title over a mono subtitle, matching the two-line header in the design.
  Widget _titleBlock(BuildContext context, {bool phone = false}) {
    final t = context.tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kMaxTitleWidth),
      child: SizedBox(
        width: double.infinity,
        child: Tooltip(
          message: 'Rename "$title"',
          child: InkWell(
            onTap: onRename,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment:
                    phone ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: phone ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: phone ? TextAlign.center : TextAlign.start,
                    style: AppTokens.mono(
                      size: phone ? 10 : 11,
                      color: t.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _trailing(BuildContext context, WidgetRef ref) {
    if (layout == EditorBarLayout.phone) {
      return _phoneTrailing(context, ref);
    }

    final compact = layout != EditorBarLayout.single;
    final quizLocked = ref.watch(quizLimitReachedProvider);
    return [
      _BarIcon(
        icon: Icons.search_rounded,
        tooltip: 'Find in document (Ctrl+F)',
        onPressed: onFind,
      ),
      _BarIcon(
        icon: Icons.quiz_rounded,
        tooltip: quizLocked
            ? 'Quiz limit reached — upgrade for unlimited'
            : 'Quiz from this document',
        onPressed: onQuiz,
        color: quizLocked
            ? context.tokens.textFaint
            : context.tokens.premiumText,
      ),
      SyncIndicator(color: context.tokens.textSecondary),
      if (compact) ...[
        // Bookmark/export/settings stay in More so the title row fits iPad
        // portrait and the split library+editor pane.
        _OverflowMenu(
          bookmarked: bookmarked,
          onToggleBookmark: onToggleBookmark,
          onOpenPageSettings: onOpenPageSettings,
          onExport: () => ExportSheet.show(
            context,
            documentId: documentId,
            title: title,
            sizeFor: pageSizeFor,
          ),
          showBookmark: true,
          readingMode: readingMode,
          onToggleReadingMode: onToggleReadingMode,
          onQuiz: onQuiz,
          quizLocked: quizLocked,
        ),
      ] else ...[
        _BarIcon(
          icon: bookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark page',
          onPressed: onToggleBookmark,
          active: bookmarked,
        ),
        _BarIcon(
          icon: Icons.ios_share_rounded,
          tooltip: 'Export, share & print',
          onPressed: () => ExportSheet.show(
            context,
            documentId: documentId,
            title: title,
            sizeFor: pageSizeFor,
          ),
        ),
        _BarIcon(
          icon: Icons.tune_rounded,
          tooltip: 'Paper & template',
          onPressed: onOpenPageSettings,
        ),
      ],
    ];
  }

  /// iOS phone header — search & sync by default; undo/redo when drawing.
  List<Widget> _phoneTrailing(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final drawing = state.isDrawingTool;
    final quizLocked = ref.watch(quizLimitReachedProvider);

    return [
      if (drawing)
        _UndoRedo(documentId: documentId)
      else ...[
        _BarIcon(
          icon: Icons.search_rounded,
          tooltip: 'Find in document',
          onPressed: onFind,
        ),
        _BarIcon(
          icon: Icons.quiz_rounded,
          tooltip: quizLocked
              ? 'Quiz limit reached — upgrade for unlimited'
              : 'Quiz from this document',
          onPressed: onQuiz,
          color: quizLocked
              ? context.tokens.textFaint
              : context.tokens.premiumText,
        ),
        SyncIndicator(color: context.tokens.textSecondary),
      ],
      _OverflowMenu(
        bookmarked: bookmarked,
        onToggleBookmark: onToggleBookmark,
        onOpenPageSettings: onOpenPageSettings,
        onExport: () => ExportSheet.show(
          context,
          documentId: documentId,
          title: title,
          sizeFor: pageSizeFor,
        ),
        readingMode: readingMode,
        onToggleReadingMode: onToggleReadingMode,
        horizontalIcon: true,
      ),
    ];
  }

  // ---- Row 2 (stacked only): the tool group --------------------------------

  Widget _toolRow(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Container(
      height: _kToolRow,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _ToolGroup(
              documentId: documentId,
              pageSizeFor: pageSizeFor,
              // iPad split / narrow windows still get quick colours when space
              // allows; otherwise a single swatch opens the full palette.
              showInlineSwatches: wide,
            ),
          ),
          const SizedBox(width: 8),
          _UndoRedo(documentId: documentId),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- tool group --

/// Core tools in the bottom dock and the compact top tool row (tablet portrait).
const _kPrimaryDockTools = [
  (Icons.pan_tool_alt_rounded, 'Hand', ToolType.hand),
  (Icons.highlight_alt_rounded, 'Select', ToolType.lasso),
  (Icons.edit_rounded, 'Pen', ToolType.pen),
  (Icons.brush_rounded, 'Highlighter', ToolType.highlighter),
  (Icons.cleaning_services_rounded, 'Eraser', ToolType.eraser),
  (Icons.category_outlined, 'Shape', ToolType.shape),
  (Icons.text_fields_rounded, 'Text', ToolType.text),
  (Icons.sticky_note_2_outlined, 'Sticky note', ToolType.sticky),
];

/// Extra tools surfaced through the overflow sheet on phone and narrow tablets.
const _kOverflowToolEntries = [
  (Icons.brush_outlined, 'Fountain pen', ToolType.fountainPen),
  (Icons.gesture_rounded, 'Pencil', ToolType.pencil),
  (Icons.horizontal_rule_rounded, 'Tape', ToolType.tape),
  (Icons.image_outlined, 'Image', ToolType.image),
];

/// Primary tools in the phone dock — matches the Android bottom tool pill.
const _kPhoneDockTools = _kPrimaryDockTools;

/// The tools, in one recessed container with a raised pill on the active one.
///
/// Scrolls horizontally rather than wrapping: the group must keep a single
/// predictable height, and eleven tools don't fit a tablet in one line.
/// Opens the sticker picker and drops the chosen sticker onto the current
/// page. Shared by the desktop tool group and the phone dock.
void _openStickers(BuildContext context, WidgetRef ref, String documentId) {
  StickerPickerSheet.show(
    context,
    onPick: (bytes, name) => _placeSticker(ref, documentId, bytes, name),
  );
}

/// Places [bytes] as an image element near the top of the current page, then
/// selects it and switches to the Hand tool so it can be moved and resized
/// right away. Stickers are just images, so they reuse the whole image path
/// (crop, rotate, GIF animation).
Future<void> _placeSticker(
  WidgetRef ref,
  String documentId,
  Uint8List bytes,
  String name,
) async {
  final state = ref.read(editorControllerProvider(documentId));
  final pageId = state.currentPageId;
  if (pageId == null) return;
  final pageWidth = state.currentPage?.pageW ?? 800.0;
  final controller = ref.read(editorControllerProvider(documentId).notifier);
  final element = await ref
      .read(elementRepositoryProvider)
      .insertImage(
        pageId: pageId,
        bytes: bytes,
        filename: name,
        maxWidth: pageWidth * 0.35,
        at: Offset(pageWidth * 0.30, 120),
      );
  controller.selectElement(element.id);
  controller.setTool(ToolType.hand);
}

class _ToolGroup extends ConsumerWidget {
  const _ToolGroup({
    required this.documentId,
    required this.pageSizeFor,
    required this.showInlineSwatches,
  });

  final String documentId;
  final Size Function(NotePage) pageSizeFor;

  /// Desktop shows five quick colours beside the tools; narrower layouts show
  /// only the current colour and open the palette sheet for the rest.
  final bool showInlineSwatches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final drawing = state.isDrawingTool;

    Widget tool(IconData icon, String label, ToolType type) => _ToolButton(
      icon: icon,
      label: label,
      selected: state.tool == type,
      onTap: () => controller.setTool(type),
      onOptions: () => ToolOptionsSheet.show(context, documentId),
    );

    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (showInlineSwatches) ...[
              tool(Icons.pan_tool_alt_rounded, 'Hand', ToolType.hand),
              tool(Icons.edit_rounded, 'Pen', ToolType.pen),
              tool(Icons.brush_outlined, 'Fountain pen', ToolType.fountainPen),
              tool(Icons.gesture_rounded, 'Pencil', ToolType.pencil),
              tool(Icons.brush_rounded, 'Highlighter', ToolType.highlighter),
              tool(Icons.horizontal_rule_rounded, 'Tape', ToolType.tape),
              tool(Icons.category_outlined, 'Shape', ToolType.shape),
              tool(Icons.text_fields_rounded, 'Text', ToolType.text),
              tool(Icons.sticky_note_2_outlined, 'Sticky note', ToolType.sticky),
              _ToolButton(
                icon: Icons.emoji_emotions_outlined,
                label: 'Stickers',
                selected: false,
                onTap: () => _openStickers(context, ref, documentId),
              ),
              const _BarSeparator(),
              tool(Icons.highlight_alt_rounded, 'Lasso', ToolType.lasso),
              tool(Icons.image_outlined, 'Image', ToolType.image),
              tool(Icons.cleaning_services_rounded, 'Eraser', ToolType.eraser),
              const _BarSeparator(),
              _ToolButton(
                icon: Icons.straighten_rounded,
                label: 'Margins',
                selected: state.effectiveMargins?.enabled ?? false,
                onTap: () {
                  final page = state.currentPage;
                  if (page == null) return;
                  MarginsSheet.show(
                    context,
                    documentId: documentId,
                    pageSize: pageSizeFor(page),
                  );
                },
              ),
            ] else ...[
              for (final item in _kPrimaryDockTools)
                tool(item.$1, item.$2, item.$3),
              _ToolButton(
                icon: Icons.more_horiz_rounded,
                label: 'More tools',
                selected: const {
                  ToolType.fountainPen,
                  ToolType.pencil,
                  ToolType.tape,
                  ToolType.image,
                }.contains(state.tool),
                onTap: () => _OverflowTools.show(
                  context,
                  ref: ref,
                  documentId: documentId,
                  pageSizeFor: pageSizeFor,
                ),
              ),
            ],
            // Ink settings only make sense while an ink tool is held.
            if (drawing) ...[
              const _BarSeparator(),
              if (showInlineSwatches)
                _QuickSwatches(documentId: documentId)
              else
                _CurrentColorButton(
                  color: state.activeSettings.color,
                  onTap: () => ColorPickerSheet.show(context, documentId),
                ),
              const SizedBox(width: 6),
              _WidthChip(documentId: documentId),
              const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

/// A tool in the group: 38×38, icon only, tooltip for the name.
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onOptions,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Tapping an already-selected tool opens its settings panel.
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: selected && onOptions != null ? '$label options' : label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected && onOptions != null ? onOptions : onTap,
        child: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? t.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.inner),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: t.shadow.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? t.accentText : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Five one-tap colours plus a "more" affordance, for wide layouts.
class _QuickSwatches extends ConsumerWidget {
  const _QuickSwatches({required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final palette = paletteFor(state.tool);
    final quick = palette.take(5).toList();
    final selected = state.activeSettings.color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in quick)
          _Swatch(
            color: c,
            selected: c == selected,
            onTap: () => controller.setColor(c),
          ),
        const SizedBox(width: 2),
        // Always reachable: the quick row is a shortcut, not the whole palette.
        _CurrentColorButton(
          color: selected,
          // Already shown as a dot above, so this is purely the "open the
          // full palette" affordance.
          showDot: !quick.contains(selected),
          onTap: () => ColorPickerSheet.show(context, documentId),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 20,
  });

  final int color;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size + 8,
        height: size + 8,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Color(color | 0xFF000000),
              shape: BoxShape.circle,
              // Ring-outside-a-gap, so the selected dot reads clearly even
              // when its colour is close to the toolbar's.
              border: Border.all(
                color: selected ? t.fill : Colors.transparent,
                width: 2,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: t.accent, spreadRadius: 1.5)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the active colour; tapping opens the full palette.
class _CurrentColorButton extends StatelessWidget {
  const _CurrentColorButton({
    required this.color,
    required this.onTap,
    this.showDot = true,
    this.size = 22,
  });

  final int color;
  final VoidCallback onTap;
  final bool showDot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: 'More colours',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: size + 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDot)
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Color(color | 0xFF000000),
                    shape: BoxShape.circle,
                    border: Border.all(color: t.lineStrong, width: 2),
                  ),
                ),
              Icon(Icons.expand_more_rounded, size: 18, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "1.4 pt" chip from the design — current stroke width, opens the
/// thickness menu.
class _WidthChip extends ConsumerWidget {
  const _WidthChip({required this.documentId, this.compact = false});
  final String documentId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final presets = kThicknessPresets[state.tool] ?? const [2.0, 4.0, 6.0];
    final width = state.activeSettings.width;

    return PopupMenuButton<double>(
      tooltip: 'Stroke width',
      onSelected: controller.setWidth,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (var i = 0; i < presets.length; i++)
          PopupMenuItem(
            value: presets[i],
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: (presets[i] * 0.55).clamp(2.0, 10.0),
                  decoration: BoxDecoration(
                    color: t.text,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 14),
                Text(_label(i, presets.length)),
                const Spacer(),
                Text(
                  presets[i].toStringAsFixed(1),
                  style: AppTokens.mono(size: 11, color: t.textFaint),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: width,
          onTap: () => ToolOptionsSheet.show(context, documentId),
          child: const Row(
            children: [
              Icon(Icons.tune_rounded, size: 18),
              SizedBox(width: 12),
              Text('More options…'),
            ],
          ),
        ),
      ],
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: compact ? t.surfaceAlt : t.surface,
          borderRadius: BorderRadius.circular(compact ? 9 : 8),
          border: Border.all(color: t.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${width.toStringAsFixed(1)} pt',
              style: AppTokens.mono(size: 12, color: t.textSecondary),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: t.textMuted),
          ],
        ),
      ),
    );
  }

  static String _label(int index, int count) {
    if (count == 3) return const ['Thin', 'Medium', 'Thick'][index];
    return 'Size ${index + 1}';
  }
}

class _UndoRedo extends ConsumerWidget {
  const _UndoRedo({required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarIcon(
          icon: Icons.undo_rounded,
          tooltip: 'Undo (Ctrl+Z)',
          onPressed: state.canUndo ? controller.undo : null,
        ),
        _BarIcon(
          icon: Icons.redo_rounded,
          tooltip: 'Redo (Ctrl+Y)',
          onPressed: state.canRedo ? controller.redo : null,
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- phone dock --

/// Height the phone tool dock reserves, so the canvas can be inset by it.
const double kToolDockHeight = 120;

/// Floating cluster styling from section 09 of the Annotate redesign.
BoxDecoration _iosToolClusterDecoration(AppTokens t) => BoxDecoration(
  color: t.fill,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: t.lineStrong),
  boxShadow: [
    BoxShadow(
      color: t.shadow.withValues(alpha: 0.85),
      blurRadius: 44,
      offset: const Offset(0, 20),
      spreadRadius: -14,
    ),
  ],
);

/// The phone's tool surface: a colour strip above a floating tool pill.
///
/// On a phone the top bar is already full with title and navigation, and a
/// tool row up there is the hardest place on the screen for a thumb to reach.
class EditorToolDock extends ConsumerWidget {
  const EditorToolDock({
    super.key,
    required this.documentId,
    required this.pageSizeFor,
  });

  final String documentId;
  final Size Function(NotePage) pageSizeFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final palette = paletteFor(state.tool);
    final selected = state.activeSettings.color;

    Widget tool(IconData icon, String label, ToolType type) => _DockTool(
      icon: icon,
      label: label,
      selected: state.tool == type,
      onTap: () => controller.setTool(type),
      onOptions: () => ToolOptionsSheet.show(context, documentId),
    );

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.isDrawingTool)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Material(
                  color: t.fill,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: t.lineStrong),
                  ),
                  shadowColor: t.shadow,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppTokens.elevation(
                        t.shadow,
                        y: 16,
                        blur: 34,
                        opacity: 0.7,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final c in palette)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: _Swatch(
                                      color: c,
                                      selected: c == selected,
                                      onTap: () => controller.setColor(c),
                                      size: 24,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: _CurrentColorButton(
                                    color: selected,
                                    showDot: false,
                                    onTap: () => ColorPickerSheet.show(
                                      context,
                                      documentId,
                                    ),
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _WidthChip(documentId: documentId, compact: true),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: _iosToolClusterDecoration(t),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final item in _kPhoneDockTools)
                        tool(item.$1, item.$2, item.$3),
                      _DockTool(
                        icon: Icons.more_horiz_rounded,
                        label: 'More tools',
                        selected: const {
                          ToolType.fountainPen,
                          ToolType.pencil,
                          ToolType.tape,
                          ToolType.image,
                        }.contains(state.tool),
                        onTap: () => _OverflowTools.show(
                          context,
                          ref: ref,
                          documentId: documentId,
                          pageSizeFor: pageSizeFor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverflowTools {
  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required String documentId,
    required Size Function(NotePage) pageSizeFor,
  }) {
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final state = ref.read(editorControllerProvider(documentId));
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text('More tools'),
              subtitle: Text('Drawing, objects and page controls'),
            ),
            for (final item in _kOverflowToolEntries)
              ListTile(
                leading: Icon(item.$1),
                title: Text(item.$2),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.setTool(item.$3);
                },
              ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('Stickers'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openStickers(context, ref, documentId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.straighten_rounded),
              title: const Text('Margins'),
              onTap: () {
                Navigator.pop(sheetContext);
                final page = state.currentPage;
                if (page == null) return;
                MarginsSheet.show(
                  context,
                  documentId: documentId,
                  pageSize: pageSizeFor(page),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A tool in the phone dock — 42×42 touch targets per the iOS redesign.
class _DockTool extends StatelessWidget {
  const _DockTool({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onOptions,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOptions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !enabled
            ? null
            : selected && onOptions != null
                ? onOptions
                : onTap,
        child: Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            color: selected ? t.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            size: 21,
            color: !enabled
                ? t.textFaint.withValues(alpha: 0.45)
                : selected
                    ? Colors.white
                    : t.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Permanent iPad/Android-tablet annotation rail used in landscape.
class EditorToolRail extends ConsumerWidget {
  const EditorToolRail({
    super.key,
    required this.documentId,
    required this.pageSizeFor,
  });

  final String documentId;
  final Size Function(NotePage) pageSizeFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);

    Widget tool(IconData icon, String label, ToolType type) => _RailTool(
      icon: icon,
      label: label,
      selected: state.tool == type,
      onTap: () {
        if (state.tool == type && state.isDrawingTool) {
          ToolOptionsSheet.show(context, documentId);
        } else {
          controller.setTool(type);
        }
      },
    );

    return Container(
      width: 66,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    tool(Icons.pan_tool_alt_rounded, 'Hand', ToolType.hand),
                    tool(Icons.highlight_alt_rounded, 'Select', ToolType.lasso),
                    tool(Icons.edit_rounded, 'Pen', ToolType.pen),
                    tool(
                      Icons.brush_outlined,
                      'Fountain pen',
                      ToolType.fountainPen,
                    ),
                    tool(Icons.gesture_rounded, 'Pencil', ToolType.pencil),
                    tool(Icons.brush_rounded, 'Highlighter', ToolType.highlighter),
                    tool(Icons.horizontal_rule_rounded, 'Tape', ToolType.tape),
                    tool(Icons.cleaning_services_rounded, 'Eraser', ToolType.eraser),
                    tool(Icons.category_outlined, 'Shapes', ToolType.shape),
                    _RailTool(
                      icon: Icons.straighten_rounded,
                      label: 'Margins',
                      selected: state.effectiveMargins?.enabled ?? false,
                      onTap: () {
                        final page = state.currentPage;
                        if (page == null) return;
                        MarginsSheet.show(
                          context,
                          documentId: documentId,
                          pageSize: pageSizeFor(page),
                        );
                      },
                    ),
                    tool(Icons.text_fields_rounded, 'Text', ToolType.text),
                    tool(Icons.sticky_note_2_outlined, 'Sticky note', ToolType.sticky),
                    tool(Icons.image_outlined, 'Image', ToolType.image),
                    _RailTool(
                      icon: Icons.emoji_emotions_outlined,
                      label: 'Stickers',
                      selected: false,
                      onTap: () => _openStickers(context, ref, documentId),
                    ),
                  ],
                ),
              ),
            ),
            _RailTool(
              icon: Icons.undo_rounded,
              label: 'Undo',
              selected: false,
              enabled: state.canUndo,
              onTap: controller.undo,
            ),
            _RailTool(
              icon: Icons.redo_rounded,
              label: 'Redo',
              selected: false,
              enabled: state.canRedo,
              onTap: controller.redo,
            ),
            if (state.isDrawingTool) ...[
              const SizedBox(height: 6),
              for (final c in paletteFor(state.tool).take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _Swatch(
                    color: c,
                    selected: c == state.activeSettings.color,
                    onTap: () => controller.setColor(c),
                    size: 22,
                  ),
                ),
              _CurrentColorButton(
                color: state.activeSettings.color,
                showDot: false,
                onTap: () => ColorPickerSheet.show(context, documentId),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _RailTool extends StatelessWidget {
  const _RailTool({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? t.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 23,
              color: !enabled
                  ? t.textFaint.withValues(alpha: 0.45)
                  : selected
                  ? Colors.white
                  : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ misc pieces --

/// Trailing actions folded behind a single button on narrow screens.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.bookmarked,
    required this.onToggleBookmark,
    required this.onOpenPageSettings,
    required this.onExport,
    this.showBookmark = true,
    this.readingMode = false,
    this.onToggleReadingMode,
    this.horizontalIcon = false,
    this.sidebarOpen = false,
    this.onToggleSidebar,
    this.onQuiz,
    this.quizLocked = false,
    this.onMoreTools,
  });

  final bool bookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback onOpenPageSettings;
  final VoidCallback onExport;
  final bool showBookmark;
  final bool readingMode;
  final VoidCallback? onToggleReadingMode;
  final bool horizontalIcon;
  final bool sidebarOpen;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onQuiz;
  final bool quizLocked;
  final VoidCallback? onMoreTools;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More',
      icon: Icon(
        horizontalIcon ? Icons.more_horiz_rounded : Icons.more_vert_rounded,
        size: 21,
        color: context.tokens.textSecondary,
      ),
      onSelected: (value) {
        switch (value) {
          case 0:
            onToggleBookmark();
          case 1:
            onExport();
          case 2:
            onOpenPageSettings();
          case 3:
            onToggleSidebar?.call();
          case 4:
            onToggleReadingMode?.call();
          case 5:
            onQuiz?.call();
          case 6:
            onMoreTools?.call();
        }
      },
      itemBuilder: (context) => [
        if (onToggleSidebar != null)
          PopupMenuItem(
            value: 3,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                sidebarOpen
                    ? Icons.list_alt_rounded
                    : Icons.list_alt_outlined,
              ),
              title: Text(
                sidebarOpen ? 'Hide pages & outline' : 'Pages & outline',
              ),
            ),
          ),
        if (showBookmark)
          PopupMenuItem(
            value: 0,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
              title: Text(bookmarked ? 'Remove bookmark' : 'Bookmark page'),
            ),
          ),
        if (onToggleReadingMode != null)
          PopupMenuItem(
            value: 4,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                readingMode
                    ? Icons.edit_rounded
                    : Icons.chrome_reader_mode_outlined,
              ),
              title: Text(
                readingMode ? 'Show annotation tools' : 'Reading mode',
              ),
            ),
          ),
        if (onQuiz != null)
          PopupMenuItem(
            value: 5,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.quiz_rounded,
                color: quizLocked ? context.tokens.textFaint : null,
              ),
              title: Text(
                quizLocked
                    ? 'Upgrade for more quizzes'
                    : 'Quiz from document',
              ),
            ),
          ),
        if (onMoreTools != null)
          PopupMenuItem(
            value: 6,
            child: const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.more_horiz_rounded),
              title: Text('More tools'),
            ),
          ),
        const PopupMenuItem(
          value: 1,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.ios_share_rounded),
            title: Text('Export, share & print'),
          ),
        ),
        const PopupMenuItem(
          value: 2,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tune_rounded),
            title: Text('Document settings'),
          ),
        ),
      ],
    );
  }
}

/// Page number field with up/down arrows, in one recessed pill.
class _PageJump extends StatefulWidget {
  const _PageJump({
    required this.currentIndex,
    required this.pageCount,
    required this.controller,
  });

  final int currentIndex;
  final int pageCount;
  final ContinuousCanvasController controller;

  @override
  State<_PageJump> createState() => _PageJumpState();
}

class _PageJumpState extends State<_PageJump> {
  late final TextEditingController _field = TextEditingController(
    text: '${widget.currentIndex + 1}',
  );
  final _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _PageJump old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.currentIndex != old.currentIndex) {
      _field.text = '${widget.currentIndex + 1}';
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final n = int.tryParse(value.trim());
    if (n == null || n < 1 || n > widget.pageCount) {
      _field.text = '${widget.currentIndex + 1}';
      return;
    }
    widget.controller.jumpToPage(n - 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniIcon(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous page',
            onPressed: widget.currentIndex > 0
                ? () => widget.controller.jumpToPage(widget.currentIndex - 1)
                : null,
          ),
          SizedBox(
            width: 34,
            child: TextField(
              controller: _field,
              focusNode: _focus,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTokens.mono(size: 12, color: t.text),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: _submit,
            ),
          ),
          Text(
            ' / ${widget.pageCount}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.mono(size: 12, color: t.textMuted),
          ),
          _MiniIcon(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next page',
            onPressed: widget.currentIndex < widget.pageCount - 1
                ? () => widget.controller.jumpToPage(widget.currentIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

/// Zoom out / percentage / zoom in / fit, in one recessed pill.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.controller});
  final ContinuousCanvasController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniIcon(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom out',
                onPressed: controller.zoomOut,
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${(controller.zoom * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: AppTokens.mono(size: 12, color: t.textSecondary),
                ),
              ),
              _MiniIcon(
                icon: Icons.add_rounded,
                tooltip: 'Zoom in',
                onPressed: controller.zoomIn,
              ),
              _MiniIcon(
                icon: Icons.fit_screen_rounded,
                tooltip: 'Fit page',
                onPressed: controller.fitPage,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small icon button sized to sit inside a 34px pill.
class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 30,
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null ? t.textFaint : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      color: color ?? (active ? t.accentText : t.textSecondary),
      disabledColor: t.textFaint,
    );
  }
}

class _BarSeparator extends StatelessWidget {
  const _BarSeparator();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 22,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: context.tokens.lineStrong,
  );
}
