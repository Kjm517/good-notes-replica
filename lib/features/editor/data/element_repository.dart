import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/image_element.dart';
import '../../library/data/asset_repository.dart';

/// Data access for canvas elements (images today; text/shapes later).
class ElementRepository {
  ElementRepository(this._db, this._uuid, this._assets);

  final AppDatabase _db;
  final Uuid _uuid;
  final AssetRepository _assets;

  Stream<List<CanvasElement>> watchElements(String pageId) {
    return (_db.select(_db.canvasElements)
          ..where((e) => e.pageId.equals(pageId) & e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.asc(e.z)]))
        .watch();
  }

  Future<List<CanvasElement>> getElements(String pageId) {
    return (_db.select(_db.canvasElements)
          ..where((e) => e.pageId.equals(pageId) & e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.asc(e.z)]))
        .get();
  }

  Future<Uint8List?> imageBytes(String assetId) => _assets.getBytes(assetId);

  /// Prompts for an image file and places it on [pageId].
  /// [maxWidth] caps the initial placement size in content points.
  Future<CanvasElement?> pickAndInsertImage({
    required String pageId,
    required double maxWidth,
    Offset? at,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (bytes == null) return null;
    return insertImage(
      pageId: pageId,
      bytes: Uint8List.fromList(bytes),
      filename: file?.name ?? 'image',
      maxWidth: maxWidth,
      at: at,
    );
  }

  /// Stores [bytes] as an asset and places an image element on the page.
  Future<CanvasElement> insertImage({
    required String pageId,
    required Uint8List bytes,
    required String filename,
    required double maxWidth,
    Offset? at,
  }) async {
    final size = await _decodeSize(bytes);
    final scale = size.width > maxWidth ? maxWidth / size.width : 1.0;
    final w = size.width * scale;
    final h = size.height * scale;
    final origin = at ?? const Offset(40, 40);

    final assetId = await _assets.store(
      id: _uuid.v4(),
      bytes: bytes,
      kind: 0,
      filename: filename,
      mime: 'image/*',
    );
    final elementId = _uuid.v4();
    await _db.transaction(() async {
      await _db.into(_db.canvasElements).insert(CanvasElementsCompanion.insert(
            id: elementId,
            pageId: pageId,
            type: ElementType.image,
            data: ImageElementData(assetId: assetId).toJson(),
            x: Value(origin.dx),
            y: Value(origin.dy),
            width: Value(w),
            height: Value(h),
          ));
    });
    return (await (_db.select(_db.canvasElements)
              ..where((e) => e.id.equals(elementId)))
            .getSingle());
  }

  Future<void> updateTransform(
    String elementId, {
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) async {
    await (_db.update(_db.canvasElements)..where((e) => e.id.equals(elementId)))
        .write(CanvasElementsCompanion(
      x: x == null ? const Value.absent() : Value(x),
      y: y == null ? const Value.absent() : Value(y),
      width: width == null ? const Value.absent() : Value(width),
      height: height == null ? const Value.absent() : Value(height),
      rotation: rotation == null ? const Value.absent() : Value(rotation),
      updatedAt: Value(DateTime.now()),
      dirty: const Value(true),
    ));
  }

  Future<void> updateData(String elementId, ImageElementData data) async {
    await (_db.update(_db.canvasElements)..where((e) => e.id.equals(elementId)))
        .write(CanvasElementsCompanion(
      data: Value(data.toJson()),
      updatedAt: Value(DateTime.now()),
      dirty: const Value(true),
    ));
  }

  Future<void> deleteElement(String elementId) async {
    final now = DateTime.now();
    await (_db.update(_db.canvasElements)..where((e) => e.id.equals(elementId)))
        .write(CanvasElementsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
      dirty: const Value(true),
    ));
  }

  Future<ui.Size> _decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    return size;
  }
}
