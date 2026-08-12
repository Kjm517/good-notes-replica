import 'dart:convert';
import 'dart:typed_data';

import '../db/database.dart';
import '../models/enums.dart';
import 'ink_stroke.dart';

/// Serialises a whole page of ink into one blob, and back.
///
/// Sync stores ink **per page** rather than per stroke: a page can hold
/// hundreds of strokes, and cloud databases bill per document write. One blob
/// per page keeps a burst of drawing to a single write.
///
/// Format: a 4-byte little-endian header length, a JSON header describing each
/// stroke, then the packed Float32 point data (x, y, pressure) back to back —
/// the same packing the local database uses, so no re-encoding is needed.
const int _kInkFormatVersion = 1;

/// The parts of a stroke the codec needs, so drift rows and [InkStroke]
/// objects can share one implementation.
class _Entry {
  const _Entry({
    required this.id,
    required this.tool,
    required this.color,
    required this.width,
    required this.opacity,
    required this.style,
    required this.filled,
    required this.tip,
    required this.seq,
    required this.points,
  });

  final String id;
  final ToolType tool;
  final int color;
  final double width;
  final double opacity;
  final StrokeStyle style;
  final bool filled;
  final StrokeTip tip;
  final int seq;
  final Uint8List points;
}

/// Encodes drift stroke rows (the sync engine's path).
Uint8List encodeInkPage(List<Stroke> strokes) => _encode([
      for (final s in strokes)
        _Entry(
          id: s.id,
          tool: s.tool,
          color: s.color,
          width: s.width,
          opacity: s.opacity,
          style: s.style,
          filled: s.filled,
          tip: s.tip,
          seq: s.seq,
          points: s.points,
        ),
    ]);

/// Encodes in-memory [InkStroke]s (used by tests and any in-memory caller).
Uint8List encodeInkPageFromStrokes(List<InkStroke> strokes) => _encode([
      for (final s in strokes)
        _Entry(
          id: s.id,
          tool: s.tool,
          color: s.color,
          width: s.width,
          opacity: s.opacity,
          style: s.style,
          filled: s.filled,
          tip: s.tip,
          seq: s.seq,
          points: s.packPoints(),
        ),
    ]);

Uint8List _encode(List<_Entry> entries) {
  final header = <Map<String, Object?>>[];
  final buffers = <Uint8List>[];
  var offset = 0;

  for (final e in entries) {
    header.add({
      'id': e.id,
      'tool': e.tool.index,
      'color': e.color,
      'width': e.width,
      'opacity': e.opacity,
      'style': e.style.index,
      'filled': e.filled,
      'tip': e.tip.index,
      'seq': e.seq,
      'offset': offset,
      'length': e.points.lengthInBytes,
    });
    buffers.add(e.points);
    offset += e.points.lengthInBytes;
  }

  final headerBytes = utf8.encode(jsonEncode({
    'v': _kInkFormatVersion,
    'strokes': header,
  }));

  final out = BytesBuilder(copy: false);
  final prefix = ByteData(4)
    ..setUint32(0, headerBytes.length, Endian.little);
  out.add(prefix.buffer.asUint8List());
  out.add(headerBytes);
  for (final b in buffers) {
    out.add(b);
  }
  return out.toBytes();
}

/// Decodes a page blob. Malformed input yields an empty list rather than
/// throwing — a corrupt blob must not take the whole sync down.
List<InkStroke> decodeInkPage(Uint8List bytes) {
  if (bytes.lengthInBytes < 4) return const [];

  final int headerLength;
  final Map<String, Object?> header;
  try {
    headerLength = ByteData.sublistView(bytes).getUint32(0, Endian.little);
    if (headerLength <= 0 || 4 + headerLength > bytes.lengthInBytes) {
      return const [];
    }
    header = jsonDecode(utf8.decode(bytes.sublist(4, 4 + headerLength)))
        as Map<String, Object?>;
  } catch (_) {
    return const [];
  }

  final dataStart = 4 + headerLength;
  final strokes = <InkStroke>[];

  for (final entry in (header['strokes'] as List? ?? const [])) {
    final map = entry as Map<String, Object?>;
    final offset = (map['offset'] as num).toInt();
    final length = (map['length'] as num).toInt();
    final start = dataStart + offset;
    if (start + length > bytes.lengthInBytes) continue;

    strokes.add(InkStroke(
      id: map['id'] as String,
      tool: ToolType.values[(map['tool'] as num).toInt()],
      color: (map['color'] as num).toInt(),
      width: (map['width'] as num).toDouble(),
      opacity: (map['opacity'] as num?)?.toDouble() ?? 1.0,
      seq: (map['seq'] as num?)?.toInt() ?? 0,
      style: StrokeStyle.values[(map['style'] as num?)?.toInt() ?? 0],
      filled: map['filled'] as bool? ?? false,
      tip: StrokeTip.values[(map['tip'] as num?)?.toInt() ?? 0],
      points: InkStroke.unpackPoints(bytes.sublist(start, start + length)),
    ));
  }
  return strokes;
}
