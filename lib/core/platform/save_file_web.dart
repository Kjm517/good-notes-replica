import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [bytes] as [filename].
Future<String> saveBytes(
    Uint8List bytes, String filename, String mimeType) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
  return filename;
}
