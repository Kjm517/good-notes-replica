import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'remote_store.dart';

/// Firestore-backed [RemoteStore].
///
/// Everything hangs off `users/{uid}` so the security rules stay a single
/// clause and one user can never read another's notes.
class FirestoreStore implements RemoteStore {
  FirestoreStore({required this.uid, FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _collectionRef(
    RemoteCollection collection,
    String? parentId,
  ) {
    switch (collection) {
      case RemoteCollection.documents:
        return _user.collection('documents');
      case RemoteCollection.pages:
        // parentId = documentId
        return _user.collection('documents').doc(parentId).collection('pages');
      case RemoteCollection.elements:
        // parentId = pageId; elements are stored flat and filtered by page so
        // one query can fetch a document's elements without walking pages.
        return _user.collection('elements');
      case RemoteCollection.quizzes:
        return _user.collection('quizzes');
      case RemoteCollection.assets:
        return _user.collection('assets');
    }
  }

  @override
  Future<List<RemoteRecord>> fetchChanged(
    RemoteCollection collection, {
    DateTime? since,
    String? parentId,
  }) async {
    Query<Map<String, dynamic>> query = _collectionRef(collection, parentId);
    if (collection == RemoteCollection.elements && parentId != null) {
      query = query.where('pageId', isEqualTo: parentId);
    }
    if (since != null) {
      query = query.where('updatedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }
    final snap = await query.get();
    return snap.docs.map(_toRecord).toList();
  }

  RemoteRecord _toRecord(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, Object?>.from(doc.data());
    return RemoteRecord(
      id: doc.id,
      data: data,
      updatedAt: _readTime(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deletedAt: _readTime(data['deletedAt']),
    );
  }

  DateTime? _readTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  @override
  Future<void> upsert(
    RemoteCollection collection,
    List<RemoteRecord> records, {
    String? parentId,
  }) async {
    if (records.isEmpty) return;
    final ref = _collectionRef(collection, parentId);

    // Firestore caps a batch at 500 writes.
    const chunkSize = 400;
    for (var i = 0; i < records.length; i += chunkSize) {
      final batch = _db.batch();
      for (final record in records.skip(i).take(chunkSize)) {
        batch.set(
          ref.doc(record.id),
          {
            ...record.data,
            'updatedAt': Timestamp.fromDate(record.updatedAt),
            if (record.deletedAt != null)
              'deletedAt': Timestamp.fromDate(record.deletedAt!),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  @override
  Future<Uint8List?> fetchInk(String pageId) async {
    final doc = await _user.collection('ink').doc(pageId).get();
    final blob = doc.data()?['bytes'];
    return blob is Blob ? blob.bytes : null;
  }

  @override
  Future<List<RemoteInk>> fetchInkChanged({
    DateTime? since,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query =
        _user.collection('ink').orderBy('updatedAt');
    if (since != null) {
      query = query.where(
        'updatedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(since),
      );
    }
    final snap = await query.limit(limit).get();
    final out = <RemoteInk>[];
    for (final doc in snap.docs) {
      final blob = doc.data()['bytes'];
      final stamp = doc.data()['updatedAt'];
      if (blob is! Blob || stamp is! Timestamp) continue;
      out.add(
        RemoteInk(
          pageId: doc.id,
          bytes: blob.bytes,
          updatedAt: stamp.toDate(),
        ),
      );
    }
    return out;
  }

  @override
  Future<bool> putInk(
      String pageId, Uint8List bytes, DateTime updatedAt) async {
    // A Firestore document is capped at ~1 MiB. Normal pages are a few KB;
    // anything larger is dropped rather than failing the whole sync, and will
    // move to object storage with the rest of the files (phase 4).
    if (bytes.lengthInBytes > 900 * 1024) {
      debugPrint(
        'Skipping ink upload for $pageId: '
        '${bytes.lengthInBytes} bytes exceeds Firestore cap',
      );
      return false;
    }
    await _user.collection('ink').doc(pageId).set({
      'bytes': Blob(bytes),
      'updatedAt': Timestamp.fromDate(updatedAt),
    });
    return true;
  }

  @override
  Future<RemoteRecord?> fetchById(
    RemoteCollection collection,
    String id, {
    String? parentId,
  }) async {
    final snap = await _collectionRef(collection, parentId).doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    final data = Map<String, Object?>.from(snap.data()!);
    return RemoteRecord(
      id: snap.id,
      data: data,
      updatedAt:
          _readTime(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deletedAt: _readTime(data['deletedAt']),
    );
  }

  @override
  Stream<void> watchChanges() {
    late final StreamController<void> controller;
    final subs = <StreamSubscription<dynamic>>[];
    controller = StreamController<void>.broadcast(
      onListen: () {
        void ping(Object? _) {
          if (!controller.isClosed) controller.add(null);
        }

        // Every collection another device can change. Leaving assets and
        // quizzes out meant a file finishing its upload elsewhere, or a quiz
        // taken on a phone, waited for an unrelated ping before this device
        // noticed.
        subs.add(_user.collection('documents').snapshots().listen(ping));
        subs.add(_user.collection('elements').snapshots().listen(ping));
        subs.add(_user.collection('ink').snapshots().listen(ping));
        subs.add(_user.collection('assets').snapshots().listen(ping));
        subs.add(_user.collection('quizzes').snapshots().listen(ping));
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        subs.clear();
      },
    );
    return controller.stream;
  }
}
