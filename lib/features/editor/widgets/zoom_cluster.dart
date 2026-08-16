import 'package:flutter/material.dart';

import '../../../app/design.dart';
import '../canvas/continuous_canvas.dart';

/// Floating zoom control that sits over the bottom-right of the page canvas.
///
/// It remains available on touch devices as an accessible alternative to
/// pinch-to-zoom. The slider supports fine adjustment while +/- provide quick
/// steps and the percentage readout resets to fit-page.
class ZoomCluster extends StatelessWidget {
  const ZoomCluster({super.key, required this.controller});

  final ContinuousCanvasController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: t.line),
            boxShadow: [
              BoxShadow(
                color: t.shadow.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Btn(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom out',
                onTap: controller.zoomOut,
              ),
              SizedBox(
                width: 104,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: t.accent,
                    inactiveTrackColor: t.lineStrong,
                    thumbColor: t.accent,
                    overlayColor: t.accent.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: controller.zoom.clamp(0.25, 8.0),
                    min: 0.25,
                    max: 8,
                    onChanged: controller.setZoom,
                  ),
                ),
              ),
              // Tapping the readout snaps back to a page-width fit — the same
              // affordance a browser's zoom indicator offers.
              Tooltip(
                message: 'Fit page',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: controller.fitPage,
                  child: SizedBox(
                    width: 48,
                    child: Text(
                      '${(controller.zoom * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: AppTokens.mono(size: 12, color: t.textSecondary),
                    ),
                  ),
                ),
              ),
              _Btn(
                icon: Icons.add_rounded,
                tooltip: 'Zoom in',
                onTap: controller.zoomIn,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 19, color: context.tokens.textSecondary),
        ),
      ),
    );
  }
}
