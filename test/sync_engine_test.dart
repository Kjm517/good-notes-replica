import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/db/database.dart';
import 'package:notably/core/ink/ink_stroke.dart';
import 'package:notably/core/models/enums.dart';
import 'package:notably/core/models/image_element.dart';
import 'package:notably/core/sync/remote_store.dart';
import 'package:notably/core/sync/sync_engine.dart';
import 'package:notably/core/sync/sync_state.dart';
import 'package:notably/features/editor/data/stroke_repository.dart';

/// In-memory stand-in for Firestore so two engines can share a cloud.
class MemoryRemoteStore implements RemoteStore {
  final Map<String, RemoteRecord> documents = {};
  final Map<String, Map<String, RemoteRecord>> pages = {};
  final Map<String, RemoteRecord> elements = {};
  final Map<String, RemoteRecord> assets = {};
  final Map<String, Uint8List> ink = {};

  List<RemoteRecord> _filter(
    Iterable<RemoteRecord> records,
    DateTime? since,
  ) {
    if (since == null) return records.toList();
    return records.where((r) => !r.updatedAt.isBefore(since)).toList();
  }

  @override
  Future<List<RemoteRecord>> fetchChanged(
    RemoteCollection collection, {
    DateTime? since,
    String? parentId,
  }) async {
    switch (collection) {
      case RemoteCollection.documents:
        return _filter(documents.values, since);
      case RemoteCollection.pages:
        return _filter(pages[parentId]?.values ?? const [], since);
      case RemoteCollection.elements:
        var rows = elements.values;
        if (parentId != null) {
          rows = rows.where((r) => r.data['pageId'] == parentId);
        }
        return _filter(rows, since);
      case RemoteCollection.assets:
        return _filter(assets.values, since);
    }
  }

  @override
  Future<void> upsert(
    RemoteCollection collection,
    List<RemoteRecord> records, {
    String? parentId,
  }) async {
    for (final record in records) {
      switch (collection) {
        case RemoteCollection.documents:
          documents[record.id] = record;
        case RemoteCollection.pages:
          pages.putIfAbsent(parentId ?? '', () => {})[record.id] = record;
        case RemoteCollection.elements:
          elements[record.id] = record;
        case RemoteCollection.assets:
          assets[record.id] = record;
      }
    }
  }

  @override
  Future<Uint8List?> fetchInk(String pageId) async => ink[pageId];

  @override
  Future<bool> putInk(String pageId, Uint8List bytes, DateTime updatedAt) async {
    ink[pageId] = bytes;
    return true;
  }

  @override
  Future<RemoteRecord?> fetchById(
    RemoteCollection collection,
    String id, {
    String? parentId,
  }) async {
    switch (collection) {
      case RemoteCollection.documents:
        return documents[id];
      case RemoteCollection.pages:
        return pages[parentId]?[id];
      case RemoteCollection.elements:
        return elements[id];
      case RemoteCollection.assets:
        return assets[id];
    }
  }

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase deviceA;
  late AppDatabase deviceB;
  late MemoryRemoteStore cloud;

  setUp(() {
    deviceA = AppDatabase(NativeDatabase.memory());
    deviceB = AppDatabase(NativeDatabase.memory());
    cloud = MemoryRemoteStore();
  });

  tearDown(() async {
    await deviceA.close();
    await deviceB.close();
  });

  SyncEngine engine(AppDatabase db) => SyncEngine(
        db: db,
        remote: cloud,
        uid: 'user-1',
      );

  test('a PDF imported on one device appears in the other account library',
      () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-pdf',
          type: DocumentType.pdf,
          title: const Value('textbook'),
          ownerUid: const Value('user-1'),
        ));
    await deviceA.into(deviceA.assets).insert(AssetsCompanion.insert(
          id: 'asset-pdf',
          kind: 1,
          path: const Value('textbook.pdf'),
          remoteKey: const Value('sha/textbook.pdf'),
        ));
    await deviceA.into(deviceA.notePages).insert(NotePagesCompanion.insert(
          id: 'page-1',
          documentId: 'doc-pdf',
          pageIndex: 0,
          pdfAssetId: const Value('asset-pdf'),
        ));

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.syncNow();
    await b.syncNow();

    final pulled = await (deviceB.select(deviceB.documents)
          ..where((d) => d.id.equals('doc-pdf')))
        .getSingleOrNull();
    expect(pulled, isNotNull);
    expect(pulled!.title, 'textbook');
    expect(pulled.ownerUid, 'user-1');

    final pages = await (deviceB.select(deviceB.notePages)
          ..where((p) => p.documentId.equals('doc-pdf')))
        .get();
    expect(pages, hasLength(1));
    expect(pages.first.pdfAssetId, 'asset-pdf');

    final asset = await (deviceB.select(deviceB.assets)
          ..where((a) => a.id.equals('asset-pdf')))
        .getSingleOrNull();
    expect(asset, isNotNull);
    expect(asset!.remoteKey, 'sha/textbook.pdf');
  });

  test('unowned local documents are claimed and pushed on sign-in', () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'orphan',
          type: DocumentType.pdf,
          title: const Value('before-account'),
        ));

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.syncNow();
    await b.syncNow();

    final local = await (deviceA.select(deviceA.documents)
          ..where((d) => d.id.equals('orphan')))
        .getSingle();
    expect(local.ownerUid, 'user-1');

    final pulled = await (deviceB.select(deviceB.documents)
          ..where((d) => d.id.equals('orphan')))
        .getSingleOrNull();
    expect(pulled, isNotNull);
    expect(pulled!.title, 'before-account');
  });

  test('canvas elements replicate to the second device', () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-n',
          type: DocumentType.notebook,
          title: const Value('Notes'),
          ownerUid: const Value('user-1'),
        ));
    await deviceA.into(deviceA.notePages).insert(NotePagesCompanion.insert(
          id: 'page-n',
          documentId: 'doc-n',
          pageIndex: 0,
        ));
    await deviceA.into(deviceA.canvasElements).insert(
          CanvasElementsCompanion.insert(
            id: 'el-1',
            pageId: 'page-n',
            type: ElementType.text,
            data: '{"text":"hello"}',
            x: const Value(10),
            y: const Value(20),
          ),
        );

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.syncNow();
    await b.syncNow();

    final elements = await (deviceB.select(deviceB.canvasElements)
          ..where((e) => e.id.equals('el-1')))
        .get();
    expect(elements, hasLength(1));
    expect(elements.first.data, contains('hello'));
  });

  test('ink drawn after the notebook already synced appears on the other device',
      () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-ink',
          type: DocumentType.notebook,
          title: const Value('Sketch'),
          ownerUid: const Value('user-1'),
        ));
    await deviceA.into(deviceA.notePages).insert(NotePagesCompanion.insert(
          id: 'page-ink',
          documentId: 'doc-ink',
          pageIndex: 0,
        ));

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.syncNow();
    await b.syncNow();

    await StrokeRepository(deviceA).insertStroke(
      'page-ink',
      InkStroke(
        id: 'stroke-1',
        tool: ToolType.pen,
        color: 0xFF111111,
        width: 2,
        points: const [
          StrokePoint(10, 20, 0.8),
          StrokePoint(30, 40, 1),
        ],
      ),
    );

    await a.syncNow();
    await b.syncNow();

    final strokes = await (deviceB.select(deviceB.strokes)
          ..where((s) => s.pageId.equals('page-ink') & s.deletedAt.isNull()))
        .get();
    expect(strokes, hasLength(1));
    expect(strokes.first.id, 'stroke-1');
  });

  test('ink still pulls when the local notebook row is newer', () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-lww',
          type: DocumentType.notebook,
          title: const Value('Sketch'),
          ownerUid: const Value('user-1'),
        ));
    await deviceA.into(deviceA.notePages).insert(NotePagesCompanion.insert(
          id: 'page-lww',
          documentId: 'doc-lww',
          pageIndex: 0,
        ));

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.syncNow();
    await b.syncNow();

    await StrokeRepository(deviceA).insertStroke(
      'page-lww',
      InkStroke(
        id: 'stroke-lww',
        tool: ToolType.pen,
        color: 0xFF222222,
        width: 3,
        points: const [
          StrokePoint(1, 1, 1),
          StrokePoint(2, 2, 1),
        ],
      ),
    );
    await a.syncNow();

    await (deviceB.update(deviceB.documents)
          ..where((d) => d.id.equals('doc-lww')))
        .write(DocumentsCompanion(
      title: const Value('renamed locally'),
      updatedAt: Value(DateTime.now().add(const Duration(minutes: 2))),
      dirty: const Value(true),
    ));

    await b.syncNow();

    final strokes = await (deviceB.select(deviceB.strokes)
          ..where((s) => s.id.equals('stroke-lww')))
        .get();
    expect(strokes, hasLength(1));
    final localDoc = await (deviceB.select(deviceB.documents)
          ..where((d) => d.id.equals('doc-lww')))
        .getSingle();
    expect(localDoc.title, 'renamed locally');
  });

  test('image and sticker assets replicate with the canvas element', () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-img',
          type: DocumentType.notebook,
          title: const Value('Stickers'),
          ownerUid: const Value('user-1'),
        ));
    await deviceA.into(deviceA.notePages).insert(NotePagesCompanion.insert(
          id: 'page-img',
          documentId: 'doc-img',
          pageIndex: 0,
        ));

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.syncNow();
    await b.syncNow();

    await deviceA.into(deviceA.assets).insert(AssetsCompanion.insert(
          id: 'asset-sticker',
          kind: 0,
          path: const Value('star.png'),
          remoteKey: const Value('sha/star.img'),
        ));
    await deviceA.into(deviceA.canvasElements).insert(
          CanvasElementsCompanion.insert(
            id: 'el-sticker',
            pageId: 'page-img',
            type: ElementType.image,
            data: const ImageElementData(assetId: 'asset-sticker').toJson(),
            x: const Value(40),
            y: const Value(40),
            width: const Value(80),
            height: const Value(80),
          ),
        );

    await a.syncNow();
    await b.syncNow();

    final element = await (deviceB.select(deviceB.canvasElements)
          ..where((e) => e.id.equals('el-sticker')))
        .getSingleOrNull();
    expect(element, isNotNull);
    expect(element!.data, contains('asset-sticker'));

    final asset = await (deviceB.select(deviceB.assets)
          ..where((a) => a.id.equals('asset-sticker')))
        .getSingleOrNull();
    expect(asset, isNotNull);
    expect(asset!.remoteKey, 'sha/star.img');
  });

  test('syncNow does not push when there is no network', () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-offline',
          type: DocumentType.notebook,
          title: const Value('offline note'),
          ownerUid: const Value('user-1'),
        ));
    SyncStatus? last;
    final engine = SyncEngine(
      db: deviceA,
      remote: cloud,
      uid: 'user-1',
      isOnline: () async => false,
      onStatus: (s) => last = s,
    );
    addTearDown(engine.dispose);
    await engine.syncNow();
    expect(last?.phase, SyncPhase.offline);
    expect(cloud.documents.containsKey('doc-offline'), isFalse);
  });

  test('pause keeps syncNow from contacting the cloud', () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-paused',
          type: DocumentType.notebook,
          title: const Value('paused note'),
          ownerUid: const Value('user-1'),
        ));
    SyncStatus? last;
    final engine = SyncEngine(
      db: deviceA,
      remote: cloud,
      uid: 'user-1',
      onStatus: (s) => last = s,
    );
    addTearDown(engine.dispose);
    engine.pause();
    await engine.syncNow();
    expect(last?.phase, SyncPhase.paused);
    expect(cloud.documents.containsKey('doc-paused'), isFalse);
  });
}
