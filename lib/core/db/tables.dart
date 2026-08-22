import 'package:drift/drift.dart';

import '../models/enums.dart';
import 'converters.dart';

/// Columns every synced table carries.
///
/// * [updatedAt]  — last local change; the clock used for last-write-wins.
/// * [deletedAt]  — tombstone. Rows are never hard-deleted once sync is on,
///                  otherwise a delete on one device is silently resurrected
///                  by the next pull from another.
/// * [dirty]      — has local changes not yet pushed to the cloud.
/// * [remoteUpdatedAt] — the server timestamp we last reconciled with.
mixin SyncedTable on Table {
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get remoteUpdatedAt => dateTime().nullable()();
}

/// Library items: folders, notebooks and imported PDFs. Folders nest via
/// [parentId]; notebooks/pdfs own [Pages].
class Documents extends Table with SyncedTable {
  TextColumn get id => text()();
  IntColumn get type => intEnum<DocumentType>()();
  TextColumn get title => text().withDefault(const Constant('Untitled'))();
  TextColumn get parentId => text().nullable()();

  /// Index into the built-in cover palette (notebooks only).
  IntColumn get coverStyle => integer().withDefault(const Constant(0))();
  IntColumn get orientation =>
      intEnum<PageOrientation>().withDefault(const Constant(0))();
  IntColumn get pageSize =>
      intEnum<PageSizePreset>().withDefault(const Constant(0))();

  BoolColumn get starred => boolean().withDefault(const Constant(false))();

  /// Firebase uid of the account this belongs to.
  ///
  /// Null means "created on this device while signed out" — those stay
  /// visible to everyone and are claimed by the first account that signs in.
  /// Anything owned by an account is hidden unless that account is signed in;
  /// otherwise signing out would leave one user's notes on screen for the
  /// next person to open the app.
  TextColumn get ownerUid => text().nullable()();

  /// Small base64 PNG of the first page, rendered once at import.
  ///
  /// Without this the library has to open the whole source PDF just to draw a
  /// card-sized preview — a 150 MB textbook took over 20 seconds.
  TextColumn get coverThumb => text().nullable()();

  /// The PDF's embedded table of contents as a JSON list of [OutlineEntry].
  ///
  /// Extracted once in the background (alongside search-text indexing) so the
  /// outline sidebar can jump to sections like a browser PDF viewer. Null means
  /// "not extracted yet"; an empty list means the PDF genuinely has no outline.
  /// Derived data, so it isn't synced — each device regenerates it locally.
  TextColumn get outline => text().nullable()();

  /// Null unless soft-deleted (in trash).
  DateTimeColumn get trashedAt => dateTime().nullable()();

  /// Manual ordering within a folder.
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single page inside a notebook/pdf document.
/// Named [NotePages] (not `Pages`) so the generated row class is `NotePage`,
/// avoiding a clash with Flutter's `Page` widget class.
class NotePages extends Table with SyncedTable {
  TextColumn get id => text()();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageIndex => integer()();

  IntColumn get template =>
      intEnum<PaperTemplate>().withDefault(const Constant(0))();
  IntColumn get paperColor =>
      intEnum<PaperColor>().withDefault(const Constant(0))();

  /// Adjustable margins — the custom-feature seam. Stored as JSON.
  TextColumn get marginSpec =>
      text().map(const MarginSpecConverter()).withDefault(const Constant('{}'))();

  /// For PDF-backed pages: the source asset + which page of it.
  TextColumn get pdfAssetId => text().nullable()();
  IntColumn get pdfPageIndex => integer().nullable()();

  /// For image-backed pages: the source image asset.
  TextColumn get bgAssetId => text().nullable()();

  /// Per-page size override (points) for PDF/image pages whose dimensions
  /// differ from the document preset. Null = use the document preset size.
  RealColumn get pageW => real().nullable()();
  RealColumn get pageH => real().nullable()();

  TextColumn get bookmarkTitle => text().nullable()();

  /// Text extracted from the source PDF page, lower-cased for searching.
  ///
  /// Extracted once (in the background after import) so "find in document"
  /// never has to re-parse the file. Null means not extracted yet; empty
  /// means the page genuinely has no text (a scan, or a picture page).
  TextColumn get searchText => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A committed ink stroke. Points are packed as little-endian Float32 triples
/// (x, y, pressure) in the [points] blob for compact storage.
class Strokes extends Table with SyncedTable {
  TextColumn get id => text()();
  TextColumn get pageId =>
      text().references(NotePages, #id, onDelete: KeyAction.cascade)();
  IntColumn get tool => intEnum<ToolType>()();

  /// ARGB colour.
  IntColumn get color => integer()();
  RealColumn get width => real()();
  RealColumn get opacity => real().withDefault(const Constant(1.0))();

  BlobColumn get points => blob()();

  /// Solid / dashed / dotted line style.
  IntColumn get style =>
      intEnum<StrokeStyle>().withDefault(const Constant(0))();

  /// Shapes only: fill the closed outline with the stroke colour.
  BoolColumn get filled => boolean().withDefault(const Constant(false))();

  /// Nib shape: round or square (chisel). Mainly for highlighter and tape.
  IntColumn get tip => intEnum<StrokeTip>().withDefault(const Constant(0))();

  RealColumn get bboxL => real()();
  RealColumn get bboxT => real()();
  RealColumn get bboxR => real()();
  RealColumn get bboxB => real()();

  /// Draw order within the page.
  IntColumn get seq => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Non-ink canvas objects: text boxes, images, recognised shapes.
/// Named [CanvasElements] so the generated row class is `CanvasElement`,
/// avoiding a clash with Flutter's `Element` class.
class CanvasElements extends Table with SyncedTable {
  TextColumn get id => text()();
  TextColumn get pageId =>
      text().references(NotePages, #id, onDelete: KeyAction.cascade)();
  IntColumn get type => intEnum<ElementType>()();

  /// Type-specific payload as JSON (text content/style, asset id, shape spec).
  TextColumn get data => text()();

  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get width => real().withDefault(const Constant(100))();
  RealColumn get height => real().withDefault(const Constant(40))();
  RealColumn get scale => real().withDefault(const Constant(1))();
  RealColumn get rotation => real().withDefault(const Constant(0))();
  IntColumn get z => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Binary assets (imported images, PDFs). [kind]: 0=image, 1=pdf.
///
/// On native platforms the bytes live in a file at [localPath] — a 150 MB PDF
/// base64-encoded into SQLite became ~200 MB of text and made page loads
/// crawl. On web there is no filesystem, so [data] keeps the base64 fallback.
/// (Base64 rather than a BLOB because drift's web worker *transfers* typed
/// data, detaching the buffer and corrupting large binary writes.)
class Assets extends Table with SyncedTable {
  TextColumn get id => text()();
  IntColumn get kind => integer()();

  /// Original filename, for display.
  TextColumn get path => text().withDefault(const Constant(''))();
  TextColumn get mime => text().nullable()();

  /// Web-only fallback: base64 bytes.
  TextColumn get data => text().nullable()();

  /// Native: absolute path to the file on disk.
  TextColumn get localPath => text().nullable()();

  /// Content hash — dedupes identical imports and keys the remote object.
  TextColumn get sha256 => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();

  /// Object key once uploaded to R2 (null = not uploaded yet).
  TextColumn get remoteKey => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A finished quiz run, kept locally and synced when signed in.
class QuizAttempts extends Table with SyncedTable {
  TextColumn get id => text()();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();

  /// Shared across retakes of the same generated question set.
  TextColumn get familyId => text()();

  TextColumn get title => text()();
  TextColumn get sourceLabel => text().withDefault(const Constant(''))();
  IntColumn get questionCount => integer()();
  IntColumn get correctCount => integer()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get questionsJson => text()();
  TextColumn get answersJson => text()();
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// False until the user finishes (or times out of) this generated set.
  /// Existing rows were only written on finish, so they default to true.
  BoolColumn get completed =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
