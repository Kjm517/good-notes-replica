@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/storage/asset_store.dart';

/// Exercises the OPFS-backed browser asset store in a real browser.
///
/// This is the layer that replaced base64-in-the-database, and it cannot be
/// covered by a normal `flutter test`: the VM compiles the io implementation,
/// where `supportsFileStorage` is also true, so every web branch is
/// unreachable. Run with `flutter test --platform chrome`.
void main() {
  Uint8List bytes(int n, {int fill = 7}) =>
      Uint8List.fromList(List<int>.filled(n, fill));

  test('web reports real file storage now that OPFS backs it', () {
    expect(supportsFileStorage, isTrue);
  });

  test('a written asset comes back byte for byte', () async {
    const id = 'round-trip';
    final original = bytes(1024, fill: 42);
    final stored = await writeAsset(id, original, extension: 'pdf');

    // OPFS, not the database: localPath is set and base64 is not.
    expect(stored.localPath, isNotNull);
    expect(stored.base64, isNull);

    expect(await assetExists(localPath: stored.localPath), isTrue);
    expect(await assetFileSize(stored.localPath!), 1024);

    final read = await readAsset(localPath: stored.localPath);
    expect(read, isNotNull);
    expect(read!.length, original.length);
    expect(read.first, 42);
    expect(read.last, 42);

    await deleteAsset(stored.localPath);
    expect(await assetExists(localPath: stored.localPath), isFalse);
  });

  test('a stream is written chunk by chunk, never buffered whole', () async {
    const id = 'streamed';
    // Three chunks, so a single-write implementation would fail this.
    final chunks = [bytes(4096, fill: 1), bytes(4096, fill: 2), bytes(2048, fill: 3)];
    final stored = await writeAssetStream(
      id,
      Stream.fromIterable(chunks),
      extension: 'pdf',
    );
    expect(await assetFileSize(stored.localPath!), 4096 + 4096 + 2048);

    final read = await readAsset(localPath: stored.localPath);
    expect(read![0], 1);
    expect(read[4096], 2);
    expect(read[8192], 3);
    await deleteAsset(stored.localPath);
  });

  test('byte ranges come back — what multipart upload depends on', () async {
    const id = 'sliced';
    final payload = Uint8List.fromList(List<int>.generate(2048, (i) => i % 256));
    final stored = await writeAsset(id, payload, extension: 'bin');

    final collected = <int>[];
    await for (final chunk in readAssetSlice(stored.localPath!, 100, 356)) {
      collected.addAll(chunk);
    }
    expect(collected, hasLength(256));
    expect(collected.first, 100 % 256);
    expect(collected.last, 355 % 256);
    await deleteAsset(stored.localPath);
  });

  test('an interrupted write leaves nothing behind', () async {
    const id = 'aborted';
    Stream<List<int>> failing() async* {
      yield bytes(1024);
      throw StateError('connection dropped');
    }

    await expectLater(
      writeAssetStream(id, failing(), extension: 'pdf'),
      throwsA(isA<StateError>()),
    );
    // A half-file would look present to assetExists and then fail to parse,
    // which is indistinguishable from a corrupt download.
    expect(await assetExists(localPath: await plannedAssetPath(id, extension: 'pdf')),
        isFalse);
  });

  test('a lost localPath can be recovered from the id alone', () async {
    const id = 'recover-me';
    final stored = await writeAsset(id, bytes(512), extension: 'pdf');
    expect(await findStoredAssetPath(id), stored.localPath);
    await deleteAsset(stored.localPath);
    expect(await findStoredAssetPath(id), isNull);
  });

  test('deleting something that was never there is not an error', () async {
    await deleteAsset('nothing.pdf');
    await deleteAsset(null);
    await deleteAsset('');
  });

  test('legacy base64 rows still read, so old data is not stranded', () async {
    // Rows written before OPFS have data and no localPath.
    final read = await readAsset(base64: 'aGVsbG8=');
    expect(String.fromCharCodes(read!), 'hello');
  });

  test('the open ceiling is the renderer on web, not the Android heap', () {
    // pdfrx has no openCustom on web, so a PDF is read into memory to render.
    // The cap must reflect what a browser tab can hold, not a phone process.
    expect(maxOpenableAssetBytes, greaterThan(kMaxInMemoryAssetBytes));
  });
}
