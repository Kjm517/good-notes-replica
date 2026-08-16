import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One entry in a PDF's embedded table of contents (its "outline" / bookmarks).
///
/// Extracted once from the source PDF and stored as a flat, ordered list on the
/// document — [depth] preserves the original nesting so the sidebar can indent
/// sections without a tree structure, and [pageIndex] is the zero-based page the
/// entry jumps to. Not synced: it's derived from the PDF, so each device can
/// regenerate it from its own copy of the asset (the same policy as searchText).
@immutable
class OutlineEntry {
  const OutlineEntry({
    required this.title,
    required this.pageIndex,
    this.depth = 0,
  });

  final String title;

  /// Zero-based page this entry points at.
  final int pageIndex;

  /// Nesting level in the original outline (0 = top level).
  final int depth;

  Map<String, dynamic> toMap() => {'t': title, 'p': pageIndex, 'd': depth};

  factory OutlineEntry.fromMap(Map<String, dynamic> map) => OutlineEntry(
        title: (map['t'] as String?) ?? '',
        pageIndex: (map['p'] as num?)?.toInt() ?? 0,
        depth: (map['d'] as num?)?.toInt() ?? 0,
      );

  /// Encodes a whole outline to the JSON stored on the document.
  static String encode(List<OutlineEntry> entries) =>
      jsonEncode([for (final e in entries) e.toMap()]);

  /// Decodes the document's stored JSON. Returns an empty list for null/empty
  /// (never attempted) or malformed data.
  static List<OutlineEntry> decode(String? source) {
    if (source == null || source.isEmpty) return const [];
    try {
      final data = jsonDecode(source);
      if (data is! List) return const [];
      return [
        for (final item in data)
          if (item is Map<String, dynamic>) OutlineEntry.fromMap(item),
      ];
    } catch (_) {
      return const [];
    }
  }
}
