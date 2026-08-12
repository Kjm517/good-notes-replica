import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../canvas/continuous_canvas.dart';
import '../providers.dart';
import '../state/tool_settings.dart';
import '../../sync/sync_indicator.dart';
import 'color_picker_sheet.dart';
import 'export_sheet.dart';
import 'margins_sheet.dart';
import 'tool_options_sheet.dart';

/// How the toolbar arranges itself for the available width.
enum EditorBarLayout {
  /// Phone: title row only — the tools live in [EditorToolDock] at the bottom,
  /// within thumb reach.
  phone,

  /// Tablet / small window: title row above a full-width tool row.
  stacked,

  /// Desktop: everything on one row with the tool group centred.
  single;

  /// Picks a layout from the window width.
  static EditorBarLayout forWidth(double width) {
    if (width < 760) return EditorBarLayout.phone;
    if (width < 1240) return EditorBarLayout.stacked;
    return EditorBarLayout.single;
  }

  bool get showsTools => this != EditorBarLayout.phone;
}

// Row heights. Separators are drawn as a bottom *border inside* each row
// rather than as Divider widgets, so a row's painted height always equals its
// declared height. That keeps [EditorTopBar.preferredSize] exactly equal to
// the sum of the row heights — no off-by-one overflow is possible.
const double _kTitleRow = 56;
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
    required this.onBack,
    required this.layout,
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
  final VoidCallback onBack;

  @override
  Size get preferredSize => Size.fromHeight(switch (layout) {
        EditorBarLayout.phone => _kTitleRow,
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
                  if (layout == EditorBarLayout.stacked) _toolRow(context, ref),
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
          _titleBlock(context),
          const SizedBox(width: 12),
          _PageJump(
            currentIndex: currentIndex,
            pageCount: pageCount,
            controller: canvasController,
          ),
          // The tool group is centred by equal Spacers rather than a fixed
          // margin, so it stays optically centred as the title changes width.
          const Spacer(),
          Flexible(
            flex: 0,
            child: _ToolGroup(
              documentId: documentId,
              pageSizeFor: pageSizeFor,
              showInlineSwatches: true,
            ),
          ),
          const Spacer(),
          _ZoomControls(controller: canvasController),
          const _BarSeparator(),
          _UndoRedo(documentId: documentId),
          const _BarSeparator(),
          ..._trailing(context),
        ],
      ),
    );
  }

  // ---- Row 1: back, sidebar, title, page nav, zoom -------------------------

  Widget _titleRow(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final phone = layout == EditorBarLayout.phone;
    return Container(
      height: _kTitleRow,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _leading(context),
          _titleBlock(context),
          const Spacer(),
          if (!phone) ...[
            _PageJump(
              currentIndex: currentIndex,
              pageCount: pageCount,
              controller: canvasController,
            ),
            const SizedBox(width: 8),
            _ZoomControls(controller: canvasController),
            const SizedBox(width: 4),
          ],
          ..._trailing(context),
        ],
      ),
    );
  }

  Widget _leading(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarIcon(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back to library',
          onPressed: onBack,
        ),
        if (layout != EditorBarLayout.phone)
          _BarIcon(
            icon: sidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
            tooltip: sidebarOpen ? 'Hide pages' : 'Show pages',
            onPressed: onToggleSidebar,
          ),
        const SizedBox(width: 6),
      ],
    );
  }

  /// Title over a mono subtitle, matching the two-line header in the design.
  Widget _titleBlock(BuildContext context) {
    final t = context.tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kMaxTitleWidth),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                    height: 1.2,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.mono(size: 11, color: t.textFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _trailing(BuildContext context) {
    final phone = layout == EditorBarLayout.phone;
    return [
      _BarIcon(
        icon: Icons.search_rounded,
        tooltip: 'Find in document (Ctrl+F)',
        onPressed: onFind,
      ),
      SyncIndicator(color: context.tokens.textSecondary),
      if (phone)
        // Five trailing icons overflow a phone row; everything but search
        // folds behind one button.
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
        )
      else ...[
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

  // ---- Row 2 (stacked only): the tool group --------------------------------

  Widget _toolRow(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
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
              showInlineSwatches: false,
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

/// The tools, in one recessed container with a raised pill on the active one.
///
/// Scrolls horizontally rather than wrapping: the group must keep a single
/// predictable height, and eleven tools don't fit a tablet in one line.
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
            tool(Icons.edit_rounded, 'Pen', ToolType.pen),
            tool(Icons.brush_outlined, 'Fountain pen', ToolType.fountainPen),
            tool(Icons.gesture_rounded, 'Pencil', ToolType.pencil),
            tool(Icons.brush_rounded, 'Highlighter', ToolType.highlighter),
            tool(Icons.horizontal_rule_rounded, 'Tape', ToolType.tape),
            tool(Icons.category_outlined, 'Shape', ToolType.shape),
            const _BarSeparator(),
            tool(Icons.highlight_alt_rounded, 'Lasso', ToolType.lasso),
            tool(Icons.image_outlined, 'Image', ToolType.image),
            tool(Icons.cleaning_services_rounded, 'Eraser', ToolType.eraser),
            tool(Icons.pan_tool_alt_rounded, 'Hand', ToolType.hand),
            const _BarSeparator(),
            _ToolButton(
              icon: Icons.straighten_rounded,
              label: 'Margins',
              selected: state.effectiveMargins?.enabled ?? false,
              onTap: () {
                final page = state.currentPage;
                if (page == null) return;
                MarginsSheet.show(context,
                    documentId: documentId, pageSize: pageSizeFor(page));
              },
            ),
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
  });

  final int color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 38,
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Color(color | 0xFF000000),
              shape: BoxShape.circle,
              // Ring-outside-a-gap, so the selected dot reads clearly even
              // when its colour is close to the toolbar's.
              border: Border.all(
                color: selected ? t.surface : Colors.transparent,
                width: 2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: t.accent,
                        spreadRadius: 1.5,
                      ),
                    ]
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
  });

  final int color;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: 'More colours',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 38,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDot)
                Container(
                  width: 22,
                  height: 22,
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
  const _WidthChip({required this.documentId});
  final String documentId;

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
                Text(presets[i].toStringAsFixed(1),
                    style: AppTokens.mono(size: 11, color: t.textFaint)),
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
          color: t.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${width.toStringAsFixed(1)} pt',
                style: AppTokens.mono(size: 12, color: t.textSecondary)),
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
const double kToolDockHeight = 132;

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

    return Container(
      color: t.surfaceAlt,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.isDrawingTool)
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final c in palette.take(6))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _Swatch(
                          color: c,
                          selected: c == selected,
                          onTap: () => controller.setColor(c),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _CurrentColorButton(
                        color: selected,
                        showDot: !palette.take(6).contains(selected),
                        onTap: () =>
                            ColorPickerSheet.show(context, documentId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Center(child: _WidthChip(documentId: documentId)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: t.fill,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: t.line),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            tool(Icons.edit_rounded, 'Pen', ToolType.pen),
                            tool(Icons.brush_outlined, 'Fountain pen',
                                ToolType.fountainPen),
                            tool(Icons.gesture_rounded, 'Pencil',
                                ToolType.pencil),
                            tool(Icons.brush_rounded, 'Highlighter',
                                ToolType.highlighter),
                            tool(Icons.horizontal_rule_rounded, 'Tape',
                                ToolType.tape),
                            tool(Icons.category_outlined, 'Shape',
                                ToolType.shape),
                            tool(Icons.highlight_alt_rounded, 'Lasso',
                                ToolType.lasso),
                            tool(Icons.image_outlined, 'Image',
                                ToolType.image),
                            tool(Icons.cleaning_services_rounded, 'Eraser',
                                ToolType.eraser),
                            tool(Icons.pan_tool_alt_rounded, 'Hand',
                                ToolType.hand),
                            _DockTool(
                              icon: Icons.straighten_rounded,
                              label: 'Margins',
                              selected:
                                  state.effectiveMargins?.enabled ?? false,
                              onTap: () {
                                final page = state.currentPage;
                                if (page == null) return;
                                MarginsSheet.show(context,
                                    documentId: documentId,
                                    pageSize: pageSizeFor(page));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Undo/redo pinned outside the scroller so they can never
                  // slide off the end of the strip.
                  _UndoRedo(documentId: documentId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tool in the phone dock — bigger touch target than its desktop twin.
class _DockTool extends StatelessWidget {
  const _DockTool({
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
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected && onOptions != null ? onOptions : onTap,
        child: Container(
          width: 46,
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? t.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? Colors.white : t.textMuted,
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
  });

  final bool bookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback onOpenPageSettings;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More',
      icon: Icon(Icons.more_vert_rounded,
          size: 20, color: context.tokens.textSecondary),
      onSelected: (value) {
        if (value == 0) {
          onToggleBookmark();
        } else if (value == 1) {
          onExport();
        } else {
          onOpenPageSettings();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(bookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded),
            title: Text(bookmarked ? 'Remove bookmark' : 'Bookmark page'),
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
            title: Text('Paper & template'),
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
  late final TextEditingController _field =
      TextEditingController(text: '${widget.currentIndex + 1}');
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
          Text(' / ${widget.pageCount}',
              style: AppTokens.mono(size: 12, color: t.textMuted)),
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
                child: Text('${(controller.zoom * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: AppTokens.mono(size: 12, color: t.textSecondary)),
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
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

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
      color: active ? t.accentText : t.textSecondary,
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
