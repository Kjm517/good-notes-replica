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
  });

  final String label;
  final double fraction;
  final int pageCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final determinate = fraction > 0 && fraction < 1;
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
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: t.accent,
                          value: determinate ? fraction : null,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: determinate ? fraction.clamp(0.0, 1.0) : null,
                          color: t.accent,
                          backgroundColor: t.fill,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onClose,
                        child: Text(
                          'Close',
                          style: TextStyle(color: t.textMuted),
                        ),
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
