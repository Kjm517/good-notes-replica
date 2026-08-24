import 'package:flutter/material.dart';

import '../../../app/design.dart';

class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.flex,
    this.actionWidth = 52,
    this.emptyMessage = 'No data yet.',
  });

  final List<String> columns;
  final List<List<Widget>> rows;

  /// Relative width of each column. Null falls back to "first column double,
  /// the rest equal", which is only right when the first column is the only
  /// wide one — a table whose identity column holds an email needs to say so.
  ///
  /// Entries for action columns are ignored; those are sized to their button.
  final List<int>? flex;

  final String emptyMessage;

  /// Width of the trailing column when its header is blank.
  ///
  /// Such a column holds a control, not data. Giving it an equal share of the
  /// table steals width from the column people actually read — that is what
  /// truncates long emails while an icon sits in acres of space. It is a fixed
  /// width rather than "size to content" because the header cell has to match
  /// the body cell exactly, or every flexible column either side of it drifts.
  ///
  /// The default fits an [IconButton]; widen it for a text button.
  final double actionWidth;

  bool _isAction(int i) => i < columns.length && columns[i].trim().isEmpty;

  int _flexFor(int i) {
    final weights = flex;
    if (weights != null && i < weights.length && weights[i] > 0) {
      return weights[i];
    }
    return i == 0 ? 2 : 1;
  }

  /// Header and body must be laid out by the same rule or the columns drift
  /// apart, so both go through here.
  List<Widget> _cells(List<Widget> cells) {
    return [
      for (var i = 0; i < cells.length; i++)
        if (_isAction(i))
          SizedBox(width: actionWidth, child: cells[i])
        else
          Expanded(flex: _flexFor(i), child: cells[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(emptyMessage, style: TextStyle(color: t.textMuted)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.fill,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: _cells([
                for (final column in columns)
                  Text(column, style: AppTokens.sectionLabel(t.textFaint)),
              ]),
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? Border(bottom: BorderSide(color: t.line))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _cells(rows[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: t.lineStrong),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: t.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: t.text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: TextStyle(fontSize: 13, color: t.textMuted)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AdminErrorView extends StatelessWidget {
  const AdminErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // A chip is the width of its label. Inside a table cell it gets a tight
    // width constraint from Expanded, and a bare Container obeys it — which is
    // how a three-letter role ends up as a pill stretched across the column.
    // Align gives the chip loose constraints again so it hugs its text.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppTokens.mono(size: 10, weight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
