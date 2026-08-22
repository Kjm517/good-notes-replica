import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notably/core/db/database.dart';
import 'package:notably/core/sync/file_sync.dart';

/// The second device's predicament, in one row.
///
/// Sync brings the asset *metadata* across long before the file itself: the
/// row lands with a hash and a size but no `remoteKey` and no bytes, because
/// the device that imported it has not finished uploading. That looks exactly
/// like "this device owes the cloud an upload" unless something checks whether
/// the bytes are actually here.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory temp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('notably_pending');
  });

  tearDown(() async {
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> addAsset(
    String id, {
    String? localPath,
    String? data,
    String? remoteKey,
  }) {
    return db.into(db.assets).insert(AssetsCompanion.insert(
          id: id,
          kind: 1,
          localPath: Value(localPath),
          data: Value(data),
          remoteKey: Value(remoteKey),
          sizeBytes: const Value(1024),
        ));
  }

  test('an asset with no bytes on this device is never queued for upload',
      () async {
    // Imported here: has a real file, not yet in R2. Ours to send.
    final file = File('${temp.path}/textbook.pdf')
      ..writeAsBytesSync(List<int>.filled(64, 7));
    await addAsset('mine', localPath: file.path);
    // Web-style row: bytes inline, not yet in R2. Also ours.
    await addAsset('mine-web', data: base64Encode(const [1, 2, 3]));
    // Arrived from the other device as metadata only. Not ours, and never
    // will be — this is the row that used to sit on "Waiting to upload".
    await addAsset('theirs');
    // Already uploaded.
    await addAsset('done', localPath: '/tmp/other.pdf', remoteKey: 'sha/x.pdf');

    final attempted = <String>[];
    final files = FileSync(
      db: db,
      endpoint: 'https://worker.test',
      idToken: () async => 'token',
      client: MockClient((request) async {
        attempted.add(request.url.queryParameters['key'] ?? '');
        return http.Response('{"ok":true}', 200);
      }),
    );

    final error = await files.uploadPending();

    expect(error, isNull);
    // 'theirs' must not have been attempted, and 'done' is already up.
    expect(attempted.length, 2);

    final stillPending = await (db.select(db.assets)
          ..where((a) => a.remoteKey.isNull()))
        .get();
    expect(
      stillPending.map((a) => a.id),
      ['theirs'],
      reason: 'the other device owes this one, so it stays keyless here',
    );
  });

  test('a failed upload reports why instead of looking merely slow', () async {
    await addAsset('mine', data: base64Encode(const [1, 2, 3]));

    final files = FileSync(
      db: db,
      endpoint: 'https://worker.test',
      idToken: () async => 'token',
      client: MockClient(
        (_) async => http.Response('{"error":"Quota exceeded"}', 507),
      ),
    );

    final error = await files.uploadPending();

    expect(error, isNotNull);
    expect(error, contains('Quota exceeded'));

    // Still keyless, so the next run retries it.
    final row = await (db.select(db.assets)..where((a) => a.id.equals('mine')))
        .getSingle();
    expect(row.remoteKey, isNull);
  });
}
