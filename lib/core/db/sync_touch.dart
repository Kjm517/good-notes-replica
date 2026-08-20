import 'package:drift/drift.dart';

import 'database.dart';

/// Marks a page — and its parent notebook — dirty so the next sync run
/// publishes them.
///
/// Incremental pull only walks documents that [fetchChanged] returns. Ink and
/// canvas objects live under pages, so a stroke or sticker that doesn't bump
/// the document never leaves this device.
Future<void> touchPageForSync(AppDatabase db, String pageId) async {
  final now = DateTime.now();
  await (db.update(db.notePages)..where((p) => p.id.equals(pageId))).write(
    NotePagesCompanion(
      updatedAt: Value(now),
      dirty: const Value(true),
    ),
  );
  final page = await (db.select(db.notePages)
        ..where((p) => p.id.equals(pageId)))
      .getSingleOrNull();
  if (page == null) return;
  await (db.update(db.documents)..where((d) => d.id.equals(page.documentId)))
      .write(
    DocumentsCompanion(
      updatedAt: Value(now),
      dirty: const Value(true),
    ),
  );
}
