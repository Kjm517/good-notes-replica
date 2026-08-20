/// Heuristic table-of-contents from PDF text lines when the file has no
/// embedded bookmarks.
///
/// Does not OCR. Scanned pages with no extractable text yield an empty list;
/// [DocumentTextService.ensureOutline] is the seam a later OCR pass can fill.
class HeadingLine {
  const HeadingLine({
    required this.text,
    required this.pageIndex,
    this.fontSize = 0,
    this.bold = false,
  });

  final String text;
  final int pageIndex;
  final double fontSize;
  final bool bold;
}

class OutlineHeadingDetector {
  OutlineHeadingDetector._();

  static final _section = RegExp(
    r'^(section|chapter|part|unit)\s+[\divxlcdm0-9]+',
    caseSensitive: false,
  );
  static final _numbered = RegExp(r'^(\d+(?:\.\d+){0,6})[.)]?\s+\S');
  static final _bullet = RegExp(r'^[•·\-–—*]\s+\S');
  static final _whitespace = RegExp(r'\s+');

  /// Turns extracted lines into a depth-tagged outline, or `[]` if the
  /// document does not look like it has a real TOC.
  static List<({String title, int pageIndex, int depth})> detect(
    List<HeadingLine> lines,
  ) {
    final cleaned = _dropNoise(lines);
    if (cleaned.isEmpty) return const [];

    final sizes = [
      for (final line in cleaned)
        if (line.fontSize > 0) line.fontSize,
    ]..sort();
    final median = sizes.isEmpty ? 0.0 : sizes[sizes.length ~/ 2];

    final hits = <({String title, int pageIndex, int depth})>[];
    for (final line in cleaned) {
      final depth = _depthFor(line, median);
      if (depth == null) continue;
      hits.add((
        title: _normalizeTitle(line.text),
        pageIndex: line.pageIndex,
        depth: depth,
      ));
    }

    // A handful of false positives is worse than an empty outline.
    if (hits.length < 3) return const [];

    // Keep document order; drop consecutive duplicates (running titles).
    final out = <({String title, int pageIndex, int depth})>[];
    for (final hit in hits) {
      if (out.isNotEmpty &&
          out.last.title.toLowerCase() == hit.title.toLowerCase() &&
          out.last.pageIndex == hit.pageIndex) {
        continue;
      }
      out.add(hit);
    }
    return out;
  }

  static List<HeadingLine> _dropNoise(List<HeadingLine> lines) {
    final counts = <String, int>{};
    for (final line in lines) {
      final key = _normalizeTitle(line.text).toLowerCase();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final kept = <HeadingLine>[];
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty || text.length > 90) continue;
      if (text.contains('http') || text.contains('@')) continue;
      final key = _normalizeTitle(text).toLowerCase();
      // Same short line on many pages is a running header/footer.
      if ((counts[key] ?? 0) >= 4) continue;
      kept.add(line);
    }
    return kept;
  }

  /// Null if this line is body text.
  static int? _depthFor(HeadingLine line, double median) {
    final text = line.text.trim();
    if (_section.hasMatch(text)) return 0;

    final numbered = _numbered.firstMatch(text);
    if (numbered != null) {
      final dots = '.'.allMatches(numbered.group(1)!).length;
      return (dots + 1).clamp(1, 6);
    }

    if (_bullet.hasMatch(text)) {
      // Only treat bullets as headings when they look like a list of topics
      // (short, not a sentence) under a numbered parent.
      if (text.length <= 48 && !text.contains('.')) return 2;
      return null;
    }

    final large = median > 0 && line.fontSize >= median * 1.25;
    final allCaps = text.length >= 8 &&
        text == text.toUpperCase() &&
        RegExp(r'[A-Z]').hasMatch(text);
    if (line.bold && large) return 1;
    if (allCaps && (line.bold || large)) return 0;
    if (large && _looksLikeTitle(text)) return 1;
    return null;
  }

  static bool _looksLikeTitle(String text) {
    if (text.length < 4 || text.length > 70) return false;
    if (text.endsWith('.') || text.endsWith(',')) return false;
    final words = text.split(_whitespace);
    if (words.length > 12) return false;
    var titled = 0;
    for (final word in words) {
      if (word.isEmpty) continue;
      final initial = word[0];
      if (initial.toUpperCase() == initial) titled++;
    }
    return titled >= (words.length / 2).ceil();
  }

  static String _normalizeTitle(String text) {
    return text.replaceAll(_whitespace, ' ').trim();
  }
}
