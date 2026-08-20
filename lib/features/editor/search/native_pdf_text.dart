import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/models/outline_entry.dart';

/// File-backed PDF text and bookmarks via the platform PDF toolkit.
///
/// Syncfusion's parser only accepts a full `Uint8List`, which a 150 MB
/// textbook cannot afford on a phone heap. Android (PdfBox) and iOS (PDFKit)
/// can open the same file from disk and return one page of text at a time.
class NativePdfText {
  NativePdfText._();

  static const _channel = MethodChannel('notably/pdf_text');

  static bool get isSupported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  static Future<NativePdfSession?> open(String path) async {
    if (!isSupported) return null;
    try {
      final id = await _channel.invokeMethod<String>('open', {'path': path});
      if (id == null || id.isEmpty) return null;
      return NativePdfSession._(id);
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('Native PDF open failed: $e');
      return null;
    }
  }
}

class NativePdfSession {
  NativePdfSession._(this._id);

  final String _id;
  bool _closed = false;

  Future<String> extractPage(int pageIndex) async {
    if (_closed) return '';
    try {
      return await NativePdfText._channel.invokeMethod<String>(
            'extractPage',
            {'id': _id, 'pageIndex': pageIndex},
          ) ??
          '';
    } catch (e) {
      debugPrint('Native PDF extract failed for page $pageIndex: $e');
      return '';
    }
  }

  Future<List<OutlineEntry>> outline() async {
    if (_closed) return const [];
    try {
      final raw = await NativePdfText._channel.invokeMethod<List<dynamic>>(
        'outline',
        {'id': _id},
      );
      if (raw == null) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            OutlineEntry.fromMap(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      debugPrint('Native PDF outline failed: $e');
      return const [];
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await NativePdfText._channel.invokeMethod<void>('close', {'id': _id});
    } catch (_) {}
  }
}
