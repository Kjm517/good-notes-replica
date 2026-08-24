import 'dart:convert';
import 'dart:typed_data';

import '../../core/platform/save_file.dart';

String csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

Future<String> exportCsv({
  required String filename,
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final buf = StringBuffer()..writeln(headers.map(csvCell).join(','));
  for (final row in rows) {
    buf.writeln(row.map(csvCell).join(','));
  }
  final name = filename.endsWith('.csv') ? filename : '$filename.csv';
  return saveBytes(
    Uint8List.fromList(utf8.encode(buf.toString())),
    name,
    'text/csv;charset=utf-8',
  );
}
