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
import 'package:notably/features/editor/quiz/quiz_history_repository.dart';
import 'package:notably/features/editor/quiz/quiz_models.dart';
import 'package:uuid/uuid.dart';

/// In-memory stand-in for Firestore so two engines can share a cloud.
class MemoryRemoteStore implements RemoteStore {
  final Map<String, RemoteRecord> documents = {};
  final Map<String, Map<String, RemoteRecord>> pages = {};
  final Map<String, RemoteRecord> elements = {};
  final Map<String, RemoteRecord> assets = {};
  final Map<String, RemoteRecord> quizzes = {};
  final Map<String, Uint8List> ink = {};
  final Map<String, DateTime> inkUpdatedAt = {};

  /// Counts round trips so a regression back to one-request-per-page shows up
  /// as a number rather than as a slow app.
  int inkRequests = 0;

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
      case RemoteCollection.quizzes:
        return _filter(quizzes.values, since);
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
        case RemoteCollection.quizzes:
          quizzes[record.id] = record;
        case RemoteCollection.assets:
          assets[record.id] = record;
      }
    }
  }

  @override
  Future<Uint8List?> fetchInk(String pageId) async {
    inkRequests++;
    return ink[pageId];
  }

  @override
  Future<List<RemoteInk>> fetchInkChanged({
    DateTime? since,
    int limit = 50,
  }) async {
    inkRequests++;
    final rows = <RemoteInk>[
      for (final entry in ink.entries)
        RemoteInk(
          pageId: entry.key,
          bytes: entry.value,
          updatedAt: inkUpdatedAt[entry.key] ?? DateTime(2024),
        ),
    ]..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final changed = since == null
        ? rows
        : [for (final r in rows) if (!r.updatedAt.isBefore(since)) r];
    return changed.take(limit).toList();
  }

  @override
  Future<bool> putInk(String pageId, Uint8List bytes, DateTime updatedAt) async {
    ink[pageId] = bytes;
    inkUpdatedAt[pageId] = updatedAt;
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
      case RemoteCollection.quizzes:
        return quizzes[id];
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

  test('pulling a big book does not cost one request per page', () async {
    // The reported symptom: syncing took minutes. A pull asked the cloud for
    // every page's ink in turn, so a textbook spent hundreds of round trips
    // discovering that almost none of its pages had been drawn on.
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-big',
          type: DocumentType.pdf,
          title: const Value('Textbook'),
          ownerUid: const Value('user-1'),
        ));
    for (var i = 0; i < 200; i++) {
      await deviceA.into(deviceA.notePages).insert(NotePagesCompanion.insert(
            id: 'page-$i',
            documentId: 'doc-big',
            pageIndex: i,
          ));
    }

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.syncNow();
    cloud.inkRequests = 0;
    await b.syncNow();

    final pages = await (deviceB.select(deviceB.notePages)
          ..where((p) => p.documentId.equals('doc-big')))
        .get();
    expect(pages, hasLength(200), reason: 'the book still replicates');
    expect(
      cloud.inkRequests,
      lessThan(5),
      reason: 'ink is fetched in bulk, not once per page',
    );
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

  test('quiz history follows the account to another device', () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-quiz',
          type: DocumentType.pdf,
          title: const Value('Textbook'),
          ownerUid: const Value('user-1'),
        ));

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await QuizHistoryRepository(deviceA, const Uuid()).saveAttempt(
      documentId: 'doc-quiz',
      familyId: 'family-1',
      title: 'textbook quiz',
      sourceLabel: 'Pages 1-10',
      questions: const [
        QuizQuestion(
          kind: QuizKind.multipleChoice,
          prompt: 'What causes sepsis most often?',
          choices: ['Bacteria', 'Fungi', 'Viruses', 'Parasites'],
          correctIndex: 0,
          acceptedAnswer: 'Bacteria',
          explanation: 'Sepsis is most often caused by bacteria. See page 12.',
          pageIndex: 11,
          location: QuizAnswerLocation(
            pageIndex: 11,
            marks: [QuizHighlight(x: 0.1, y: 0.2, w: 0.3, h: 0.02, precise: true)],
            exact: true,
          ),
        ),
      ],
      answers: const {0: QuizAnswer(choiceIndex: 0, written: null, correct: true)},
      duration: const Duration(minutes: 3),
    );

    await a.syncNow();
    await b.syncNow();

    final history =
        await QuizHistoryRepository(deviceB, const Uuid()).watchForDocument('doc-quiz').first;
    expect(history, hasLength(1));
    expect(history.first.title, 'textbook quiz');
    expect(history.first.correctCount, 1);
    // The resolved highlight travels with the attempt, so the second device
    // opens the marked page without re-reading the PDF.
    expect(history.first.questions.single.location, isNotNull);
    expect(history.first.questions.single.location!.pageIndex, 11);
  });

  test('a deleted quiz stays deleted instead of being pulled back', () async {
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-del',
          type: DocumentType.pdf,
          title: const Value('Textbook'),
          ownerUid: const Value('user-1'),
        ));

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    final historyA = QuizHistoryRepository(deviceA, const Uuid());
    await historyA.saveAttempt(
      documentId: 'doc-del',
      familyId: 'family-del',
      title: 'quiz to delete',
      sourceLabel: '',
      questions: const [
        QuizQuestion(
          kind: QuizKind.trueFalse,
          prompt: 'Sepsis is dangerous.',
          choices: ['True', 'False'],
          correctIndex: 0,
          acceptedAnswer: 'True',
          explanation: 'Sepsis carries a high mortality. See page 3.',
          pageIndex: 2,
        ),
      ],
      answers: const {0: QuizAnswer(choiceIndex: 0, written: null, correct: true)},
      duration: const Duration(minutes: 1),
    );

    await a.syncNow();
    await b.syncNow();
    expect(
      await QuizHistoryRepository(deviceB, const Uuid())
          .watchForDocument('doc-del')
          .first,
      hasLength(1),
    );

    await historyA.deleteFamily(documentId: 'doc-del', familyId: 'family-del');
    await a.syncNow();
    await b.syncNow();

    // Hard-deleting instead of tombstoning would have let the next pull put
    // it straight back.
    expect(
      await QuizHistoryRepository(deviceB, const Uuid())
          .watchForDocument('doc-del')
          .first,
      isEmpty,
    );
    expect(
      await historyA.watchForDocument('doc-del').first,
      isEmpty,
    );
  });

  test('a PDF imported on one device is fetched by the next, once', () async {
    // Device A imports. The asset has bytes and no remote copy yet.
    await deviceA.into(deviceA.documents).insert(DocumentsCompanion.insert(
          id: 'doc-cloud',
          type: DocumentType.pdf,
          title: const Value('Textbook'),
          ownerUid: const Value('user-1'),
        ));
    await deviceA.into(deviceA.assets).insert(AssetsCompanion.insert(
          id: 'asset-cloud',
          kind: 1,
          path: const Value('textbook.pdf'),
          sha256: const Value('deadbeef'),
          sizeBytes: const Value(1024),
          remoteKey: const Value('sha/deadbeef.pdf'),
        ));
    await deviceA.into(deviceA.notePages).insert(NotePagesCompanion.insert(
          id: 'page-cloud',
          documentId: 'doc-cloud',
          pageIndex: 0,
          pdfAssetId: const Value('asset-cloud'),
        ));

    final a = engine(deviceA);
    final b = engine(deviceB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.syncNow();
    await b.syncNow();

    // Device B knows where the file lives without importing anything, which
    // is what lets it download instead of prompting.
    final asset = await (deviceB.select(deviceB.assets)
          ..where((a) => a.id.equals('asset-cloud')))
        .getSingle();
    expect(asset.remoteKey, 'sha/deadbeef.pdf');
    expect(asset.sha256, 'deadbeef');

    // And it is not queued for upload again — bytes only ever travel once.
    final pending = await (deviceB.select(deviceB.assets)
          ..where((a) => a.remoteKey.isNull() & a.deletedAt.isNull()))
        .get();
    expect(pending, isEmpty);
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
