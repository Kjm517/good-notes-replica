import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notably/core/db/database.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:notably/core/sync/file_sync.dart';
import 'package:notably/core/sync/sync_providers.dart';
import 'package:notably/core/storage/storage_quota.dart';
import 'package:notably/features/library/data/asset_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Points `path_provider` at a real temp directory so the asset store can
/// write files during the test.
class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory temp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('notably_file_sync');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A 20 MB file on disk — larger than one part, small enough to stay quick.
  Future<String> writeBigFile() async {
    final file = File('${temp.path}/textbook.pdf');
    final chunk = List<int>.filled(1024 * 1024, 7);
    final sink = file.openWrite();
    for (var i = 0; i < 20; i++) {
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();
    return file.path;
  }

  Future<void> insertAsset(String path, int size) async {
    await db.into(db.assets).insert(
          AssetsCompanion.insert(
            id: 'asset-big',
            kind: 1,
            localPath: Value(path),
            sizeBytes: Value(size),
            mime: const Value('application/pdf'),
            sha256: const Value('abc123'),
          ),
        );
  }

  test('a file too big for one request is uploaded in parts', () async {
    final path = await writeBigFile();
    final size = await File(path).length();
    await insertAsset(path, size);

    final partSizes = <int, int>{};
    var created = 0;
    var completed = 0;
    List<dynamic> completedParts = const [];

    final client = MockClient((request) async {
      final route = '${request.method} ${request.url.path}';
      switch (route) {
        case 'POST /multipart/create':
          created++;
          return http.Response(jsonEncode({'uploadId': 'upload-1'}), 200);
        case 'PUT /multipart/part':
          final part = int.parse(request.url.queryParameters['part']!);
          partSizes[part] = request.bodyBytes.length;
          return http.Response(jsonEncode({'etag': 'etag-$part'}), 200);
        case 'POST /multipart/complete':
          completed++;
          completedParts =
              (jsonDecode(request.body) as Map)['parts'] as List<dynamic>;
          return http.Response(jsonEncode({'ok': true}), 200);
        case 'PUT /file':
          fail('a 20 MB file must not be sent as one request');
        default:
          return http.Response('{}', 404);
      }
    });

    final sync = FileSync(
      db: db,
      endpoint: 'https://files.test',
      client: client,
      idToken: ({bool forceRefresh = false}) async => 'test-token',
    );

    await sync.uploadPending();

    // One create, three parts of 8/8/4 MB, one complete.
    expect(created, 1);
    expect(partSizes.length, 3);
    expect(partSizes[1], 8 * 1024 * 1024);
    expect(partSizes[2], 8 * 1024 * 1024);
    expect(partSizes[3], 4 * 1024 * 1024);
    expect(completed, 1);
    expect(completedParts, hasLength(3));

    // And the asset is now marked as living in the cloud, which is what tells
    // the other device it can be downloaded.
    final asset = await (db.select(db.assets)
          ..where((a) => a.id.equals('asset-big')))
        .getSingle();
    expect(asset.remoteKey, 'sha/abc123.pdf');
  });

  test('the worker endpoint comes from .env, without a trailing slash', () {
    // Every worker sits on its own account subdomain, so the endpoint has to
    // be configurable without a rebuild flag — pointing at the wrong one made
    // uploads and downloads fail silently.
    dotenv.clean();
    dotenv.loadFromString(
      envString: 'NOTABLY_FILE_ENDPOINT=https://notably-files.mine.workers.dev/',
    );
    expect(kFileEndpoint, 'https://notably-files.mine.workers.dev');

    // An explicit empty value still means "notes only".
    dotenv.clean();
    dotenv.loadFromString(envString: 'NOTABLY_FILE_ENDPOINT=');
    expect(kFileEndpoint, isEmpty);
  });

  test('replacing a PDF queues the new bytes for upload', () async {
    final path = await writeBigFile();
    final size = await File(path).length();
    await insertAsset(path, size);
    await (db.update(db.assets)..where((a) => a.id.equals('asset-big')))
        .write(const AssetsCompanion(remoteKey: Value('sha/abc123.pdf')));

    // Nothing pending while the cloud copy matches.
    var pending = await (db.select(db.assets)
          ..where((a) => a.remoteKey.isNull() & a.deletedAt.isNull()))
        .get();
    expect(pending, isEmpty);

    final replacement = File('${temp.path}/replacement.pdf')
      ..writeAsBytesSync(List<int>.filled(2048, 3));
    await AssetRepository(db, quotaBytes: kFreeStorageQuotaBytes).replaceFromFile(
      id: 'asset-big',
      sourcePath: replacement.path,
      kind: 1,
      filename: 'replacement.pdf',
      mime: 'application/pdf',
    );

    // The stale cloud copy is dropped, so the new file uploads on next sync.
    pending = await (db.select(db.assets)
          ..where((a) => a.remoteKey.isNull() & a.deletedAt.isNull()))
        .get();
    expect(pending, hasLength(1));
    expect(pending.single.id, 'asset-big');
  });
}
