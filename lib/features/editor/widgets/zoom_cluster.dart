import 'package:flutter/material.dart';

import '../../../app/design.dart';
import '../canvas/continuous_canvas.dart';

/// Floating zoom control that sits over the bottom-right of the page canvas.
///
/// The toolbar already has zoom buttons, but on a large screen the pointer is
/// usually down in the page, not up in the chrome — this puts the control
/// where the reading happens. Phones don't get it: pinch is better there, and
/// the dock already owns the bottom of the screen.
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
          height: 38,
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
  const _Btn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

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
