import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

/// Web file dialog, hand-rolled instead of `file_picker`'s.
///
/// The plugin's web implementation opens dialogs on Chrome but never on iOS
/// Safari, for three reasons this replacement avoids:
///
///  * it removes the `<input>` from the DOM in the same synchronous block as
///    `click()`, and WebKit cancels the pending dialog of a detached input;
///  * the input is `display: none`, which WebKit refuses to activate
///    programmatically;
///  * it treats the very next window `focus` as a cancellation after one
///    second, which on iOS fires while the photo sheet is still open.
///
/// So: the input stays in the document, rendered but invisible, and is only
/// removed once the pick actually settles.
Future<FilePickerResult?> pickFilesCompat({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  bool allowMultiple = false,
  bool withData = false,
}) {
  final completer = Completer<FilePickerResult?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..multiple = allowMultiple
    ..accept = _accept(type, allowedExtensions);
  // Rendered (WebKit ignores click() on display:none) but invisible and
  // untouchable, pinned so it can never scroll the page.
  input.style
    ..position = 'fixed'
    ..top = '0'
    ..left = '0'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0'
    ..pointerEvents = 'none';
  web.document.body!.append(input);

  var settled = false;
  void finish(FilePickerResult? result) {
    if (settled) return;
    settled = true;
    input.remove();
    completer.complete(result);
  }

  Future<void> onChange() async {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final picked = <PlatformFile>[];
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file == null) continue;
      final bytes = withData ? await _readBytes(file) : null;
      picked.add(PlatformFile(
        name: file.name,
        size: bytes?.length ?? file.size,
        bytes: bytes,
      ));
    }
    finish(picked.isEmpty ? null : FilePickerResult(picked));
  }

  input.addEventListener('change', ((web.Event _) => unawaited(onChange())).toJS);
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);

  // Safari before 16.4 (and any browser without the `cancel` event) gives no
  // signal for a dismissed dialog, so fall back to "the page got focus back
  // and still has no file". Only registered when `cancel` is missing: on iOS
  // focus also fires while the sheet is open, which would cancel a live pick.
  if (!(input as JSObject).has('oncancel')) {
    late final JSFunction onFocus;
    onFocus = ((web.Event _) {
      web.window.removeEventListener('focus', onFocus);
      Timer(const Duration(seconds: 2), () {
        if ((input.files?.length ?? 0) == 0) finish(null);
      });
    }).toJS;
    web.window.addEventListener('focus', onFocus);
  }

  input.click();
  return completer.future;
}

Future<Uint8List?> _readBytes(web.File file) {
  final completer = Completer<Uint8List?>();
  final reader = web.FileReader();
  reader.addEventListener('load', ((web.Event _) {
    final buffer = reader.result as JSArrayBuffer?;
    completer.complete(buffer?.toDart.asUint8List());
  }).toJS);
  reader.addEventListener('error', ((web.Event _) => completer.complete(null)).toJS);
  reader.readAsArrayBuffer(file);
  return completer.future;
}

/// MIME types *and* extensions: iOS Safari only greys files in or out by MIME
/// type, while desktop browsers and Android are happiest with extensions.
const Map<String, String> _mimeTypes = {
  'pdf': 'application/pdf',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'odp': 'application/vnd.oasis.opendocument.presentation',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'odt': 'application/vnd.oasis.opendocument.text',
  'rtf': 'application/rtf',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ods': 'application/vnd.oasis.opendocument.spreadsheet',
  'key': 'application/x-iwork-keynote-sffkey',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'svg': 'image/svg+xml',
};

String _accept(FileType type, List<String>? allowedExtensions) {
  switch (type) {
    case FileType.any:
      return '';
    case FileType.audio:
      return 'audio/*';
    case FileType.image:
      return 'image/*';
    case FileType.video:
      return 'video/*';
    case FileType.media:
      return 'image/*,video/*';
    case FileType.custom:
      final parts = <String>[];
      for (final ext in allowedExtensions ?? const <String>[]) {
        final clean = ext.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
        final mime = _mimeTypes[clean];
        if (mime != null && !parts.contains(mime)) parts.add(mime);
        parts.add('.$clean');
      }
      return parts.join(',');
  }
}
