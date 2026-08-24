import 'package:flutter/material.dart';

/// Standard luminance grayscale matrix for [ColorFiltered].
const ColorFilter kGrayscaleColorFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Grays out [builder], then reveals full colour from the bottom up as
/// [progress] goes 0 → 1. The wipe is eased so discrete sync ticks do not flash.
class CoverSyncProgressOverlay extends StatefulWidget {
  const CoverSyncProgressOverlay({
    super.key,
    required this.builder,
    required this.progress,
    required this.active,
  });

  final WidgetBuilder builder;
  final double? progress;
  final bool active;

  @override
  State<CoverSyncProgressOverlay> createState() =>
      _CoverSyncProgressOverlayState();
}

class _CoverSyncProgressOverlayState extends State<CoverSyncProgressOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _displayed = 0;

  @override
  void initState() {
    super.initState();
    _displayed = widget.progress?.clamp(0.0, 1.0) ?? 0;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _animation = AlwaysStoppedAnimation(_displayed);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _displayed = _animation.value;
      }
    });
  }

  @override
  void didUpdateWidget(covariant CoverSyncProgressOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) return;
    // A null tick is "still working, no new fraction" — hold the wipe
    // rather than swapping to a pulsing widget (that swap is the flicker).
    if (widget.progress == null) return;
    final target = widget.progress!.clamp(0.0, 1.0);
    final from = _controller.isAnimating ? _animation.value : _displayed;
    if (target + 0.002 < from) return;
    _animateTo(target);
  }

  void _animateTo(double target) {
    final from = _controller.isAnimating ? _animation.value : _displayed;
    if ((target - from).abs() < 0.002) return;
    _displayed = from;
    _animation = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..duration = Duration(
        milliseconds: (280 + 420 * (target - from).abs()).round().clamp(
              280,
              700,
            ),
      )
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.builder(context);

    final colorChild = KeyedSubtree(
      key: const ValueKey('cover-color'),
      child: widget.builder(context),
    );
    final grayChild = KeyedSubtree(
      key: const ValueKey('cover-gray'),
      child: ColorFiltered(
        colorFilter: kGrayscaleColorFilter,
        child: widget.builder(context),
      ),
    );

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final p = (_controller.isAnimating ? _animation.value : _displayed)
                  .clamp(0.0, 1.0);
              final veilHeight = constraints.maxHeight * (1 - p);
              return Stack(
                fit: StackFit.expand,
                children: [
                  colorChild,
                  if (veilHeight > 0.5)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: veilHeight,
                      child: IgnorePointer(
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: constraints.maxWidth,
                            maxWidth: constraints.maxWidth,
                            minHeight: constraints.maxHeight,
                            maxHeight: constraints.maxHeight,
                            child: grayChild,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
