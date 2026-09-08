import 'package:file_picker/file_picker.dart';

import 'pick_files_io.dart'
    if (dart.library.js_interop) 'pick_files_web.dart' as impl;

/// Opens the platform file dialog.
///
/// Native platforms delegate straight to `file_picker`. The web goes through
/// our own `<input type="file">` (see `pick_files_web.dart`) because the
/// plugin's web implementation never opens a dialog in iOS Safari.
///
/// Must be called *synchronously from the tap handler*: WebKit only opens a
/// file dialog while the originating tap is still on the call stack.
Future<FilePickerResult?> pickFilesCompat({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  bool allowMultiple = false,
  bool withData = false,
}) =>
    impl.pickFilesCompat(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: withData,
    );
