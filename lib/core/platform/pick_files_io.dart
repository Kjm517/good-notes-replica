import 'package:file_picker/file_picker.dart';

/// Native file dialog — the plugin handles Android, iOS, macOS, Windows and
/// Linux correctly, so this is a straight delegation.
Future<FilePickerResult?> pickFilesCompat({
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  bool allowMultiple = false,
  bool withData = false,
}) =>
    FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: withData,
    );
