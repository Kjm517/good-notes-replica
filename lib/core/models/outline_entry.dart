import 'dart:convert';
import 'dart:math' as math;

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

/// Nested view of a stored [OutlineEntry] list, for the sidebar and quiz
/// source picker. Ids are stable path strings (`"0.2.1"`) derived from tree
/// position so they survive a rebuild of the same outline.
@immutable
class OutlineNode {
  const OutlineNode({
    required this.id,
    required this.title,
    required this.pageIndex,
    required this.depth,
    this.children = const [],
  });

  final String id;
  final String title;

  /// Zero-based page this node jumps to.
  final int pageIndex;

  /// Nesting level (0 = top level). Same as [OutlineEntry.depth].
  final int depth;

  final List<OutlineNode> children;

  bool get hasChildren => children.isNotEmpty;

  /// This node and every nested child, for cascading section checkboxes.
  Set<String> get subtreeIds {
    final out = <String>{id};
    for (final child in children) {
      out.addAll(child.subtreeIds);
    }
    return out;
  }

  /// Checks or unchecks [node] together with its descendants.
  static Set<String> toggleSubtree(Set<String> selected, OutlineNode node) {
    final next = {...selected};
    final ids = node.subtreeIds;
    if (ids.every(next.contains)) {
      next.removeAll(ids);
    } else {
      next.addAll(ids);
    }
    return next;
  }

  /// If a parent id is selected, include every child id so the picker matches.
  static Set<String> expandSelection(
    Set<String> selected, {
    required List<OutlineNode> roots,
  }) {
    final out = {...selected};
    void walk(List<OutlineNode> nodes) {
      for (final node in nodes) {
        if (out.contains(node.id)) {
          out.addAll(node.subtreeIds);
        }
        walk(node.children);
      }
    }

    walk(roots);
    return out;
  }

  /// 1-based page number for UI.
  int get pageNumber => pageIndex + 1;

  /// Walks a stored flat outline into a tree using [OutlineEntry.depth].
  static List<OutlineNode> nest(List<OutlineEntry> entries) {
    if (entries.isEmpty) return const [];
    final stack = <_MutableNode>[];
    final roots = <_MutableNode>[];

    for (final entry in entries) {
      final depth = math.max(0, entry.depth);
      while (stack.isNotEmpty && stack.last.depth >= depth) {
        stack.removeLast();
      }
      final parent = stack.isEmpty ? null : stack.last;
      final index = parent == null ? roots.length : parent.children.length;
      final id = parent == null ? '$index' : '${parent.id}.$index';
      final node = _MutableNode(
        id: id,
        title: entry.title,
        pageIndex: entry.pageIndex,
        depth: depth,
      );
      if (parent == null) {
        roots.add(node);
      } else {
        parent.children.add(node);
      }
      stack.add(node);
    }

    return [for (final root in roots) root.freeze()];
  }

  /// Preorder flattening (parents before children).
  static List<OutlineNode> flatten(List<OutlineNode> roots) {
    final out = <OutlineNode>[];
    void walk(List<OutlineNode> nodes) {
      for (final node in nodes) {
        out.add(node);
        walk(node.children);
      }
    }

    walk(roots);
    return out;
  }

  /// Inclusive zero-based page range this node covers: from its destination
  /// until the page before the next same-or-shallower entry (or the last page).
  static (int start, int end) pageSpan(
    OutlineNode node, {
    required List<OutlineNode> roots,
    required int pageCount,
  }) {
    if (pageCount <= 0) return (node.pageIndex, node.pageIndex);
    final flat = flatten(roots);
    final i = flat.indexWhere((n) => n.id == node.id);
    final start = node.pageIndex.clamp(0, pageCount - 1);
    var end = pageCount - 1;
    if (i >= 0) {
      for (var j = i + 1; j < flat.length; j++) {
        if (flat[j].depth <= node.depth) {
          end = (flat[j].pageIndex - 1).clamp(start, pageCount - 1);
          break;
        }
      }
    }
    if (end < start) end = start;
    return (start, end);
  }

  /// Union of [pageSpan]s for every selected id, including descendants when a
  /// parent is checked.
  static Set<int> pagesForIds(
    Iterable<String> ids, {
    required List<OutlineNode> roots,
    required int pageCount,
  }) {
    final wanted = ids.toSet();
    if (wanted.isEmpty || pageCount <= 0) return {};
    final pages = <int>{};
    void walk(List<OutlineNode> nodes) {
      for (final node in nodes) {
        if (wanted.contains(node.id)) {
          final (start, end) = pageSpan(
            node,
            roots: roots,
            pageCount: pageCount,
          );
          for (var p = start; p <= end; p++) {
            pages.add(p);
          }
        }
        walk(node.children);
      }
    }

    walk(roots);
    return pages;
  }

  /// Last preorder node whose destination is on or before [pageIndex] — the
  /// section the reader is in, Edge-style.
  static String? activeIdForPage(List<OutlineNode> roots, int pageIndex) {
    String? id;
    void walk(List<OutlineNode> nodes) {
      for (final node in nodes) {
        if (node.pageIndex <= pageIndex) id = node.id;
        walk(node.children);
      }
    }

    walk(roots);
    return id;
  }

  /// Top-level outline node that contains [pageIndex] (a "chapter").
  static OutlineNode? chapterForPage(
    List<OutlineNode> roots,
    int pageIndex, {
    required int pageCount,
  }) {
    if (roots.isEmpty) return null;
    final last = math.max(1, pageCount) - 1;
    final page = pageIndex.clamp(0, last);
    for (final root in roots) {
      final (start, end) = pageSpan(
        root,
        roots: roots,
        pageCount: math.max(pageCount, page + 1),
      );
      if (page >= start && page <= end) return root;
    }
    OutlineNode? hit;
    for (final root in roots) {
      if (root.pageIndex <= page) hit = root;
    }
    return hit;
  }

  /// Depth-0 ancestor of [node] (`"0.2.1"` → the `"0"` chapter).
  static OutlineNode chapterOf(OutlineNode node, List<OutlineNode> roots) {
    final rootId = node.id.split('.').first;
    return find(roots, rootId) ?? node;
  }

  /// Ancestor ids of [id] (`"0.2.1"` → `{"0", "0.2"}`), used to keep the
  /// current section's parents expanded.
  static Set<String> ancestorIds(String id) {
    final parts = id.split('.');
    if (parts.length < 2) return const {};
    final out = <String>{};
    for (var i = 1; i < parts.length; i++) {
      out.add(parts.sublist(0, i).join('.'));
    }
    return out;
  }

  OutlineNode? findById(String id) {
    if (this.id == id) return this;
    for (final child in children) {
      final hit = child.findById(id);
      if (hit != null) return hit;
    }
    return null;
  }

  static OutlineNode? find(List<OutlineNode> roots, String id) {
    for (final root in roots) {
      final hit = root.findById(id);
      if (hit != null) return hit;
    }
    return null;
  }
}

class _MutableNode {
  _MutableNode({
    required this.id,
    required this.title,
    required this.pageIndex,
    required this.depth,
  });

  final String id;
  final String title;
  final int pageIndex;
  final int depth;
  final List<_MutableNode> children = [];

  OutlineNode freeze() => OutlineNode(
        id: id,
        title: title,
        pageIndex: pageIndex,
        depth: depth,
        children: [for (final c in children) c.freeze()],
      );
}
