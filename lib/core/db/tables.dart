import 'package:drift/drift.dart';

import '../models/enums.dart';
import 'converters.dart';

/// Library items: folders, notebooks and imported PDFs. Folders nest via
/// [parentId]; notebooks/pdfs own [Pages].
class Documents extends Table {
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

  /// Null unless soft-deleted (in trash).
  DateTimeColumn get trashedAt => dateTime().nullable()();

  /// Manual ordering within a folder.
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single page inside a notebook/pdf document.
/// Named [NotePages] (not `Pages`) so the generated row class is `NotePage`,
/// avoiding a clash with Flutter's `Page` widget class.
class NotePages extends Table {
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

  TextColumn get bookmarkTitle => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A committed ink stroke. Points are packed as little-endian Float32 triples
/// (x, y, pressure) in the [points] blob for compact storage.
class Strokes extends Table {
  TextColumn get id => text()();
  TextColumn get pageId =>
      text().references(NotePages, #id, onDelete: KeyAction.cascade)();
  IntColumn get tool => intEnum<ToolType>()();

  /// ARGB colour.
  IntColumn get color => integer()();
  RealColumn get width => real()();
  RealColumn get opacity => real().withDefault(const Constant(1.0))();

  BlobColumn get points => blob()();

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
class CanvasElements extends Table {
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
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Binary assets on disk (imported images, PDFs). [kind]: 0=image, 1=pdf.
class Assets extends Table {
  TextColumn get id => text()();
  IntColumn get kind => integer()();
  TextColumn get path => text()();
  TextColumn get mime => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
