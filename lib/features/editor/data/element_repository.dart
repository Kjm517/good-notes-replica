import 'dart:ui' show Offset;
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/image_element.dart';
import '../../../core/models/text_element.dart';
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
    final z = await _nextZ(pageId);
    await _db.transaction(() async {
      await _db
          .into(_db.canvasElements)
          .insert(
            CanvasElementsCompanion.insert(
              id: elementId,
              pageId: pageId,
              type: ElementType.image,
              data: ImageElementData(assetId: assetId).toJson(),
              x: Value(origin.dx),
              y: Value(origin.dy),
              width: Value(w),
              height: Value(h),
              z: Value(z),
            ),
          );
    });
    return (await (_db.select(
      _db.canvasElements,
    )..where((e) => e.id.equals(elementId))).getSingle());
  }

  /// Places an empty text box (or sticky note) on the page and returns it, so
  /// the caller can immediately open it for editing.
  Future<CanvasElement> insertText({
    required String pageId,
    required Offset at,
    bool sticky = false,
    double width = 220,
    TextElementData? data,
  }) async {
    // A sticky is a fixed-ish card; a plain text box grows with its contents.
    final w = sticky ? 170.0 : width;
    final h = sticky ? 150.0 : 48.0;
    final payload =
        data ??
        TextElementData(
          fontSize: sticky ? 14 : 16,
          colorValue: sticky ? 0xFF5F5322 : 0xFF1C1E26,
        );
    final elementId = _uuid.v4();
    final z = await _nextZ(pageId);
    await _db
        .into(_db.canvasElements)
        .insert(
          CanvasElementsCompanion.insert(
            id: elementId,
            pageId: pageId,
            type: sticky ? ElementType.sticky : ElementType.text,
            data: payload.toJson(),
            x: Value(at.dx),
            y: Value(at.dy),
            width: Value(w),
            height: Value(h),
            z: Value(z),
          ),
        );
    return (_db.select(
      _db.canvasElements,
    )..where((e) => e.id.equals(elementId))).getSingle();
  }

  /// Rewrites a text/sticky element's payload (content, colour, size…).
  Future<void> updateTextData(String elementId, TextElementData data) async {
    await (_db.update(
      _db.canvasElements,
    )..where((e) => e.id.equals(elementId))).write(
      CanvasElementsCompanion(
        data: Value(data.toJson()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> updateTransform(
    String elementId, {
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    String? pageId,
  }) async {
    await (_db.update(
      _db.canvasElements,
    )..where((e) => e.id.equals(elementId))).write(
      CanvasElementsCompanion(
        x: x == null ? const Value.absent() : Value(x),
        y: y == null ? const Value.absent() : Value(y),
        width: width == null ? const Value.absent() : Value(width),
        height: height == null ? const Value.absent() : Value(height),
        rotation: rotation == null ? const Value.absent() : Value(rotation),
        pageId: pageId == null ? const Value.absent() : Value(pageId),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<CanvasElement?> getElement(String elementId) {
    return (_db.select(_db.canvasElements)
          ..where((e) => e.id.equals(elementId) & e.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Next draw-order slot on [pageId] so a newly placed object sits on top.
  Future<int> _nextZ(String pageId) async {
    final rows = await getElements(pageId);
    if (rows.isEmpty) return 0;
    var max = 0;
    for (final row in rows) {
      if (row.z > max) max = row.z;
    }
    return max + 1;
  }

  /// Swaps [elementId] with the neighbour in front (or behind).
  ///
  /// Objects that still share the default z=0 are first packed into a unique
  /// sequence so the swap has something to act on.
  Future<void> shiftZ(String elementId, {required bool forward}) async {
    final element = await getElement(elementId);
    if (element == null) return;
    var siblings = await getElements(element.pageId);
    if (siblings.length < 2) return;

    final seen = <int>{};
    var packed = false;
    for (final row in siblings) {
      if (!seen.add(row.z)) {
        packed = true;
        break;
      }
    }
    if (packed) {
      for (var i = 0; i < siblings.length; i++) {
        if (siblings[i].z == i) continue;
        await (_db.update(
          _db.canvasElements,
        )..where((e) => e.id.equals(siblings[i].id))).write(
          CanvasElementsCompanion(
            z: Value(i),
            updatedAt: Value(DateTime.now()),
            dirty: const Value(true),
          ),
        );
      }
      siblings = await getElements(element.pageId);
    }

    final index = siblings.indexWhere((e) => e.id == elementId);
    if (index < 0) return;
    final otherIndex = forward ? index + 1 : index - 1;
    if (otherIndex < 0 || otherIndex >= siblings.length) return;
    final current = siblings[index];
    final other = siblings[otherIndex];
    final now = DateTime.now();
    await _db.batch((batch) {
      batch.update(
        _db.canvasElements,
        CanvasElementsCompanion(
          z: Value(other.z),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
        where: (e) => e.id.equals(current.id),
      );
      batch.update(
        _db.canvasElements,
        CanvasElementsCompanion(
          z: Value(current.z),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
        where: (e) => e.id.equals(other.id),
      );
    });
  }

  Future<void> updateData(String elementId, ImageElementData data) async {
    await (_db.update(
      _db.canvasElements,
    )..where((e) => e.id.equals(elementId))).write(
      CanvasElementsCompanion(
        data: Value(data.toJson()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> deleteElement(String elementId) async {
    final now = DateTime.now();
    await (_db.update(
      _db.canvasElements,
    )..where((e) => e.id.equals(elementId))).write(
      CanvasElementsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
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
