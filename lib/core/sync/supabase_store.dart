import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/supabase_bootstrap.dart';
import 'remote_store.dart';

/// Postgres-backed [RemoteStore] via Supabase (RLS scoped to auth.uid()).
class SupabaseStore implements RemoteStore {
  SupabaseStore({required this.uid, SupabaseClient? client})
      : _client = client ?? supabase;

  final String uid;
  final SupabaseClient _client;

  String _table(RemoteCollection collection) => switch (collection) {
        RemoteCollection.documents => 'documents',
        RemoteCollection.pages => 'pages',
        RemoteCollection.elements => 'elements',
        RemoteCollection.assets => 'assets',
        RemoteCollection.quizzes => 'quizzes',
        RemoteCollection.userPrefs => 'user_prefs',
      };

  /// PostgREST's default max-rows is 1000. A textbook PDF is routinely past
  /// that, so a single `.select()` silently truncates and the other device
  /// never sees the rest of the pages — sync looks "stuck" forever.
  static const int _fetchPageSize = 500;

  @override
  Future<List<RemoteRecord>> fetchChanged(
    RemoteCollection collection, {
    DateTime? since,
    String? parentId,
  }) async {
    // RLS already hides other accounts, but Postgres cannot use the
    // (user_id, updated_at) indexes without the predicate spelled out, so a
    // library of any size degrades to a sequential scan on every pull.
    final out = <RemoteRecord>[];
    var from = 0;
    while (true) {
      var query =
          _client.from(_table(collection)).select().eq('user_id', uid);
      if (collection == RemoteCollection.pages && parentId != null) {
        query = query.eq('document_id', parentId);
      }
      if (collection == RemoteCollection.elements && parentId != null) {
        query = query.eq('page_id', parentId);
      }
      if (since != null) {
        query = query.gte('updated_at', since.toUtc().toIso8601String());
      }
      // Stable order so range pages don't skip/duplicate on ties.
      final rows = await query
          .order('updated_at', ascending: true)
          .order('id', ascending: true)
          .range(from, from + _fetchPageSize - 1);
      for (final row in rows) {
        out.add(_rowToRecord(row));
      }
      if (rows.length < _fetchPageSize) break;
      from += _fetchPageSize;
    }
    return out;
  }

  RemoteRecord _rowToRecord(Map<String, dynamic> row) {
    final rawData = row['data'];
    final data = <String, Object?>{};
    if (rawData is Map) {
      data.addAll(Map<String, Object?>.from(rawData));
    }
    // Ensure nested scopes are present for SyncEngine consumers.
    if (row['document_id'] != null) {
      data.putIfAbsent('documentId', () => row['document_id']);
    }
    if (row['page_id'] != null) {
      data.putIfAbsent('pageId', () => row['page_id']);
    }
    return RemoteRecord(
      id: row['id'] as String,
      data: data,
      updatedAt: _readTime(row['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deletedAt: _readTime(row['deleted_at']),
    );
  }

  DateTime? _readTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  @override
  Future<void> upsert(
    RemoteCollection collection,
    List<RemoteRecord> records, {
    String? parentId,
  }) async {
    if (records.isEmpty) return;
    final table = _table(collection);
    final payload = <Map<String, dynamic>>[];
    for (final record in records) {
      final row = <String, dynamic>{
        'id': record.id,
        'user_id': uid,
        'data': record.data,
        'updated_at': record.updatedAt.toUtc().toIso8601String(),
        'deleted_at': record.deletedAt?.toUtc().toIso8601String(),
      };
      if (collection == RemoteCollection.pages) {
        row['document_id'] =
            parentId ?? record.data['documentId'] as String? ?? '';
      }
      if (collection == RemoteCollection.elements) {
        row['page_id'] = record.data['pageId'] as String?;
      }
      payload.add(row);
    }
    // Chunk to avoid oversized requests.
    const chunkSize = 200;
    for (var i = 0; i < payload.length; i += chunkSize) {
      final chunk = payload.skip(i).take(chunkSize).toList();
      await _client.from(table).upsert(chunk);
    }
  }

  @override
  Future<Uint8List?> fetchInk(String pageId) async {
    final row = await _client
        .from('ink')
        .select('bytes, storage, remote_key')
        .eq('user_id', uid)
        .eq('page_id', pageId)
        .maybeSingle();
    if (row == null) return null;
    // R2-backed rows have empty inline bytes — caller must download remote_key.
    if ((row['storage'] as String?) == 'r2') return null;
    return _decodeBytes(row['bytes']);
  }

  @override
  Future<List<RemoteInk>> fetchInkChanged({
    DateTime? since,
    int limit = 50,
  }) async {
    var query = _client
        .from('ink')
        .select('page_id, bytes, storage, remote_key, updated_at')
        .eq('user_id', uid);
    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }
    final rows = await query.order('updated_at').limit(limit);
    return _readInkRows(rows).toList();
  }

  @override
  Future<bool> putInk(
    String pageId,
    DateTime updatedAt, {
    Uint8List? bytes,
    String? remoteKey,
  }) async {
    final useR2 = remoteKey != null && remoteKey.isNotEmpty;
    if (!useR2) {
      final payload = bytes;
      if (payload == null) return false;
      // Soft cap similar to Firestore (~1 MiB); SyncEngine routes larger
      // pages through R2 and calls again with remoteKey.
      if (payload.lengthInBytes > 900 * 1024) {
        debugPrint(
          'Skipping ink upload for $pageId: '
          '${payload.lengthInBytes} bytes exceeds soft cap',
        );
        return false;
      }
    }
    await _client.from('ink').upsert(
      {
        'page_id': pageId,
        'user_id': uid,
        // Empty bytea placeholder when the real payload lives on R2.
        'bytes': useR2 ? kEmptyBytea : encodeBytea(bytes!),
        'storage': useR2 ? 'r2' : 'inline',
        'remote_key': useR2 ? remoteKey : null,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      },
      // `ink` is keyed on (user_id, page_id). Without naming the conflict
      // target PostgREST guesses, and a page re-uploaded from a second device
      // is rejected as a duplicate instead of replacing the old blob.
      onConflict: 'user_id,page_id',
    );
    return true;
  }

  /// Empty bytea, for rows whose real payload lives on R2.
  static const String kEmptyBytea = r'\x';

  /// Renders [bytes] as a Postgres hex literal for a `bytea` column.
  ///
  /// The request body is JSON, and a [Uint8List] encodes as a JSON *array of
  /// integers*. Postgres then hands the text `[1,2,3,...]` to the bytea input
  /// function, which accepts it as escape-format ASCII — so the row stores the
  /// digits of the array rather than the ink. Nothing errors; the blob just
  /// decodes to zero strokes on every other device, which is what made
  /// drawings vanish after the move off Firestore. `\x...` is the one
  /// representation PostgREST round-trips intact.
  static String encodeBytea(Uint8List bytes) {
    const hex = '0123456789abcdef';
    // Preallocated: a 900 KB page is 1.8M characters, and growing a
    // StringBuffer a nibble at a time on a phone is not free.
    final chars = List<String>.filled(bytes.length * 2, '0');
    for (var i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      chars[i * 2] = hex[(byte >> 4) & 0xf];
      chars[i * 2 + 1] = hex[byte & 0xf];
    }
    return r'\x' + chars.join();
  }

  @override
  Future<List<RemoteInk>> fetchInkForPages(List<String> pageIds) async {
    if (pageIds.isEmpty) return const [];
    final out = <RemoteInk>[];
    // `in` travels in the URL, so a 1000-page textbook has to go in slices or
    // the request is rejected before it reaches Postgres.
    const chunkSize = 100;
    for (var i = 0; i < pageIds.length; i += chunkSize) {
      final chunk = pageIds.skip(i).take(chunkSize).toList();
      final rows = await _client
          .from('ink')
          .select('page_id, bytes, storage, remote_key, updated_at')
          .eq('user_id', uid)
          .inFilter('page_id', chunk);
      out.addAll(_readInkRows(rows));
    }
    return out;
  }

  Iterable<RemoteInk> _readInkRows(List<Map<String, dynamic>> rows) sync* {
    for (final row in rows) {
      final stamp = _readTime(row['updated_at']);
      if (stamp == null) continue;
      final storage = row['storage'] as String? ?? 'inline';
      final remoteKey = row['remote_key'] as String?;
      if (storage == 'r2' && remoteKey != null && remoteKey.isNotEmpty) {
        yield RemoteInk(
          pageId: row['page_id'] as String,
          remoteKey: remoteKey,
          updatedAt: stamp,
        );
        continue;
      }
      final bytes = _decodeBytes(row['bytes']);
      if (bytes == null) continue;
      yield RemoteInk(
        pageId: row['page_id'] as String,
        bytes: bytes,
        updatedAt: stamp,
      );
    }
  }

  Uint8List? _decodeBytes(Object? value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is String) {
      // PostgREST may return hex \x... or base64.
      if (value.startsWith(r'\x')) {
        final hex = value.substring(2);
        final out = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < out.length; i++) {
          out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return out;
      }
      try {
        return Uint8List.fromList(base64Decode(value));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<RemoteRecord?> fetchById(
    RemoteCollection collection,
    String id, {
    String? parentId,
  }) async {
    final row = await _client
        .from(_table(collection))
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _rowToRecord(row);
  }

  @override
  Stream<void> watchChanges() {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>.broadcast(
      onListen: () {
        void ping(PostgresChangePayload _) {
          if (!controller.isClosed) controller.add(null);
        }

        channel = _client
            .channel('notably-sync-$uid')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'documents',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'pages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'elements',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'ink',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'assets',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'quizzes',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'user_prefs',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: ping,
            )
            .subscribe();
      },
      onCancel: () async {
        final ch = channel;
        channel = null;
        if (ch != null) {
          await _client.removeChannel(ch);
        }
      },
    );
    return controller.stream;
  }
}
