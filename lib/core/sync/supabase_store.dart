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
      };

  @override
  Future<List<RemoteRecord>> fetchChanged(
    RemoteCollection collection, {
    DateTime? since,
    String? parentId,
  }) async {
    var query = _client.from(_table(collection)).select();
    if (collection == RemoteCollection.pages && parentId != null) {
      query = query.eq('document_id', parentId);
    }
    if (collection == RemoteCollection.elements && parentId != null) {
      query = query.eq('page_id', parentId);
    }
    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }
    final rows = await query;
    return rows.map(_rowToRecord).toList();
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
        .select('bytes')
        .eq('page_id', pageId)
        .maybeSingle();
    if (row == null) return null;
    return _decodeBytes(row['bytes']);
  }

  @override
  Future<List<RemoteInk>> fetchInkChanged({
    DateTime? since,
    int limit = 50,
  }) async {
    var query = _client.from('ink').select('page_id, bytes, updated_at');
    if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }
    final rows = await query.order('updated_at').limit(limit);
    final out = <RemoteInk>[];
    for (final row in rows) {
      final bytes = _decodeBytes(row['bytes']);
      final stamp = _readTime(row['updated_at']);
      if (bytes == null || stamp == null) continue;
      out.add(
        RemoteInk(
          pageId: row['page_id'] as String,
          bytes: bytes,
          updatedAt: stamp,
        ),
      );
    }
    return out;
  }

  @override
  Future<bool> putInk(
    String pageId,
    Uint8List bytes,
    DateTime updatedAt,
  ) async {
    // Soft cap similar to Firestore (~1 MiB); huge pages can move to R2 later.
    if (bytes.lengthInBytes > 900 * 1024) {
      debugPrint(
        'Skipping ink upload for $pageId: '
        '${bytes.lengthInBytes} bytes exceeds soft cap',
      );
      return false;
    }
    await _client.from('ink').upsert({
      'page_id': pageId,
      'user_id': uid,
      'bytes': bytes,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });
    return true;
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
