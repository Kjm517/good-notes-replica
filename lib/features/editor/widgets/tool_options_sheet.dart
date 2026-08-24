import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../providers.dart';
import '../state/tool_settings.dart';

/// Per-tool options panel, mirroring GoodNotes: size presets + fine slider +
/// stroke type for pens, plus the Draw Shape and Lasso Tool settings.
class ToolOptionsSheet extends ConsumerWidget {
  const ToolOptionsSheet({super.key, required this.documentId});
  final String documentId;

  static Future<void> show(BuildContext context, String documentId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ToolOptionsSheet(documentId: documentId),
    );
  }

  static String labelFor(ToolType tool) => switch (tool) {
        ToolType.pen => 'Pen',
        ToolType.fountainPen => 'Fountain Pen',
        ToolType.pencil => 'Pencil',
        ToolType.highlighter => 'Highlighter',
        ToolType.tape => 'Tape',
        ToolType.shape => 'Draw Shape',
        ToolType.lasso => 'Lasso Tool',
        ToolType.eraser => 'Eraser',
        _ => 'Tool',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final tool = state.tool;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labelFor(tool), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (kInkTools.contains(tool)) ..._inkOptions(context, ref, tool),
          if (tool == ToolType.shape) ..._shapeOptions(context, ref),
          if (tool == ToolType.lasso) ..._lassoOptions(context, ref),
          if (tool == ToolType.eraser) ..._eraserOptions(context, controller, state.eraserMode),
        ],
      ),
    );
  }

  // ---- Ink tools: size + stroke type --------------------------------------

  List<Widget> _inkOptions(BuildContext context, WidgetRef ref, ToolType tool) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final settings = state.activeSettings;
    final presets = kThicknessPresets[tool] ?? const [2.0, 4.0, 6.0];
    final (minW, maxW) = kWidthRange[tool] ?? (0.5, 20.0);
    final palette = paletteFor(tool);
    final onWhite = tool == ToolType.highlighter || tool == ToolType.tape;

    return [
      _label(context, 'Colour'),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in palette)
            _ColourSwatch(
              color: c,
              selected: c == settings.color,
              onWhite: onWhite,
              onTap: () => controller.setColor(c),
            ),
        ],
      ),
      const SizedBox(height: 8),
      _label(context, 'Size'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final w in presets)
            _SizePreset(
              width: w,
              selected: (settings.width - w).abs() < 0.01,
              onTap: () => controller.setWidth(w),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          SizedBox(
            width: 64,
            child: Text('${settings.width.toStringAsFixed(1)} pt',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Slider(
              min: minW,
              max: maxW,
              value: settings.width.clamp(minW, maxW),
              onChanged: controller.setWidth,
            ),
          ),
        ],
      ),
      // Broad tools (highlighter, tape) have a selectable nib shape.
      if (kTipTools.contains(tool)) ...[
        const Divider(height: 24),
        _label(context, 'Tip shape'),
        Row(
          children: [
            for (final t in StrokeTip.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _TipCard(
                    tip: t,
                    color: Color(settings.color | 0xFF000000),
                    selected: settings.tip == t,
                    onTap: () => controller.setStrokeTip(t),
                  ),
                ),
              ),
          ],
        ),
      ],
      const Divider(height: 24),
      _label(context, 'Stroke Type'),
      for (final style in StrokeStyle.values)
        RadioListTile<StrokeStyle>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: style,
          // ignore: deprecated_member_use
          groupValue: settings.style,
          // ignore: deprecated_member_use
          onChanged: (v) => controller.setStrokeStyle(v!),
          title: Row(
            children: [
              SizedBox(
                width: 46,
                child: CustomPaint(
                  size: const Size(46, 12),
                  painter: _StylePreview(style),
                ),
              ),
              const SizedBox(width: 12),
              Text(switch (style) {
                StrokeStyle.solid => 'Solid',
                StrokeStyle.dashed => 'Dashed',
                StrokeStyle.dotted => 'Dotted',
              }),
            ],
          ),
        ),
    ];
  }

  // ---- Draw Shape ----------------------------------------------------------

  List<Widget> _shapeOptions(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final o = state.shapeOptions;
    return [
      const Divider(height: 24),
      _label(context, 'Settings'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: o.requireHoldToSnap,
        onChanged: (v) =>
            controller.setShapeOptions(o.copyWith(requireHoldToSnap: v)),
        title: const Text('Require Hold to Snap'),
        subtitle: const Text('Pause before lifting to snap the shape'),
      ),
      _label(context, 'Advanced Options'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: o.snapToOtherShapes,
        onChanged: (v) =>
            controller.setShapeOptions(o.copyWith(snapToOtherShapes: v)),
        title: const Text('Snap to Other Shapes'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: o.fillColor,
        onChanged: (v) => controller.setShapeOptions(o.copyWith(fillColor: v)),
        title: const Text('Fill Color'),
        subtitle: const Text('Fill closed shapes with the stroke colour'),
      ),
    ];
  }

  // ---- Lasso ---------------------------------------------------------------

  List<Widget> _lassoOptions(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider(documentId));
    final controller = ref.read(editorControllerProvider(documentId).notifier);
    final o = state.lassoOptions;
    return [
      _label(context, 'Lasso Type'),
      Row(
        children: [
          Expanded(
            child: _LassoTypeCard(
              icon: Icons.crop_din_rounded,
              label: 'Rectangular',
              selected: o.mode == LassoMode.rectangular,
              onTap: () => controller
                  .setLassoOptions(o.copyWith(mode: LassoMode.rectangular)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LassoTypeCard(
              icon: Icons.gesture_rounded,
              label: 'Freehand',
              selected: o.mode == LassoMode.freehand,
              onTap: () => controller
                  .setLassoOptions(o.copyWith(mode: LassoMode.freehand)),
            ),
          ),
        ],
      ),
      const Divider(height: 24),
      _label(context, 'Included in Selection'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: o.includeHandwriting,
        onChanged: (v) =>
            controller.setLassoOptions(o.copyWith(includeHandwriting: v)),
        title: const Text('Handwriting'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: o.includeShapes,
        onChanged: (v) =>
            controller.setLassoOptions(o.copyWith(includeShapes: v)),
        title: const Text('Shapes'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: o.includeHighlighter,
        onChanged: (v) =>
            controller.setLassoOptions(o.copyWith(includeHighlighter: v)),
        title: const Text('Highlighter'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: o.includeTape,
        onChanged: (v) =>
            controller.setLassoOptions(o.copyWith(includeTape: v)),
        title: const Text('Tape'),
      ),
    ];
  }

  List<Widget> _eraserOptions(
      BuildContext context, dynamic controller, EraserMode mode) {
    return [
      _label(context, 'Eraser Mode'),
      for (final m in EraserMode.values)
        RadioListTile<EraserMode>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: m,
          // ignore: deprecated_member_use
          groupValue: mode,
          // ignore: deprecated_member_use
          onChanged: (v) => controller.setEraserMode(v!),
          title: Text(switch (m) {
            EraserMode.stroke => 'Erase whole stroke',
            EraserMode.area => 'Erase by area',
            EraserMode.highlighterOnly => 'Highlighter only',
          }),
        ),
    ];
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).hintColor,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                )),
      );
}

class _ColourSwatch extends StatelessWidget {
  const _ColourSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.onWhite,
  });

  final int color;
  final bool selected;
  final bool onWhite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = Color(onWhite ? color : (color | 0xFF000000));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onWhite ? Colors.white : null,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: fill.computeLuminance() > 0.5
                        ? Colors.black87
                        : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _SizePreset extends StatelessWidget {
  const _SizePreset(
      {required this.width, required this.selected, required this.onTap});
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 76,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant),
        ),
        child: Container(
          width: 42,
          height: (width * 0.7).clamp(2.0, 14.0),
          decoration: BoxDecoration(
            color: scheme.onSurface,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// Nib-shape picker showing an actual round or square swatch of the tool's
/// colour, so the difference is visible rather than described.
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.tip,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final StrokeTip tip;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final round = tip == StrokeTip.round;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A short stroke drawn with this nib.
            Container(
              width: 54,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    round ? BorderRadius.circular(8) : BorderRadius.zero,
              ),
            ),
            const SizedBox(height: 8),
            Text(round ? 'Round' : 'Square',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LassoTypeCard extends StatelessWidget {
  const _LassoTypeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Small solid/dashed/dotted preview line.
class _StylePreview extends CustomPainter {
  const _StylePreview(this.style);
  final StrokeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF444444)
      ..strokeWidth = 2.4
      ..strokeCap =
          style == StrokeStyle.dotted ? StrokeCap.round : StrokeCap.butt;
    final y = size.height / 2;
    switch (style) {
      case StrokeStyle.solid:
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      case StrokeStyle.dashed:
        for (double x = 0; x < size.width; x += 12) {
          canvas.drawLine(
              Offset(x, y), Offset((x + 7).clamp(0, size.width), y), paint);
        }
      case StrokeStyle.dotted:
        for (double x = 1; x < size.width; x += 7) {
          canvas.drawLine(Offset(x, y), Offset(x + 0.1, y), paint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _StylePreview old) => old.style != style;
}
