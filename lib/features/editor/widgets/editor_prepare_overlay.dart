import 'package:flutter/material.dart';

import '../../../app/design.dart';

/// Blocks the editor while a PDF (or other file-backed notebook) is still
/// downloading or rendering its first pages. Interacting during that window
/// is what makes a multi-thousand-page document hitch and crash.
class EditorPrepareOverlay extends StatelessWidget {
  const EditorPrepareOverlay({
    super.key,
    required this.label,
    required this.fraction,
    required this.pageCount,
    required this.onClose,
    this.paused = false,
    this.onPause,
    this.onResume,
  });

  final String label;
  final double fraction;
  final int pageCount;
  final VoidCallback onClose;
  final bool paused;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.canvas.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(Radii.sheet),
                  boxShadow: AppTokens.elevation(t.shadow),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Getting this document ready',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: t.text,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: t.textSecondary),
                      ),
                      if (pageCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          pageCount > 20
                              ? '${_formatCount(pageCount)} pages · first pages first, the rest as you scroll'
                              : '$pageCount page${pageCount == 1 ? '' : 's'}',
                          textAlign: TextAlign.center,
                          style: AppTokens.mono(size: 11, color: t.textMuted),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _SmoothLinearProgress(fraction: fraction),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (paused && onResume != null)
                            TextButton(
                              onPressed: onResume,
                              child: const Text('Resume'),
                            )
                          else if (!paused && onPause != null)
                            TextButton(
                              onPressed: onPause,
                              child: Text(
                                'Pause',
                                style: TextStyle(color: t.textMuted),
                              ),
                            ),
                          TextButton(
                            onPressed: onClose,
                            child: Text(
                              'Close',
                              style: TextStyle(color: t.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i != 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Eases the bar forward between discrete sync ticks.
///
/// Null / zero / backward readings are ignored so a staged sync cursor
/// (or a determinate↔indeterminate swap) cannot snap the fill back.
class _SmoothLinearProgress extends StatefulWidget {
  const _SmoothLinearProgress({required this.fraction});

  final double fraction;

  @override
  State<_SmoothLinearProgress> createState() => _SmoothLinearProgressState();
}

class _SmoothLinearProgressState extends State<_SmoothLinearProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _displayed = 0;

  @override
  void initState() {
    super.initState();
    _displayed = widget.fraction.clamp(0.0, 1.0);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _animation = AlwaysStoppedAnimation(_displayed);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _displayed = _animation.value;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SmoothLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animateTo(widget.fraction.clamp(0.0, 1.0));
  }

  void _animateTo(double target) {
    final from = _controller.isAnimating ? _animation.value : _displayed;
    // Hold through gaps; never ease backward (kind/cursor swaps).
    if (target <= 0 || target + 0.002 < from) return;
    if ((target - from).abs() < 0.002) return;
    _displayed = from;
    _animation = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..duration = Duration(
        milliseconds: (360 + 500 * (target - from).abs()).round().clamp(
              360,
              900,
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
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final value =
                (_controller.isAnimating ? _animation.value : _displayed)
                    .clamp(0.0, 1.0);
            return ColoredBox(
              color: t.fill,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value,
                  heightFactor: 1,
                  child: ColoredBox(color: t.accent),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
