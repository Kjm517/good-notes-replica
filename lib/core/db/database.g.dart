// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DocumentType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DocumentType>($DocumentsTable.$convertertype);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Untitled'),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverStyleMeta = const VerificationMeta(
    'coverStyle',
  );
  @override
  late final GeneratedColumn<int> coverStyle = GeneratedColumn<int>(
    'cover_style',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PageOrientation, int>
  orientation = GeneratedColumn<int>(
    'orientation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  ).withConverter<PageOrientation>($DocumentsTable.$converterorientation);
  @override
  late final GeneratedColumnWithTypeConverter<PageSizePreset, int> pageSize =
      GeneratedColumn<int>(
        'page_size',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<PageSizePreset>($DocumentsTable.$converterpageSize);
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _trashedAtMeta = const VerificationMeta(
    'trashedAt',
  );
  @override
  late final GeneratedColumn<DateTime> trashedAt = GeneratedColumn<DateTime>(
    'trashed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    parentId,
    coverStyle,
    orientation,
    pageSize,
    starred,
    trashedAt,
    sortIndex,
    createdAt,
    updatedAt,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('cover_style')) {
      context.handle(
        _coverStyleMeta,
        coverStyle.isAcceptableOrUnknown(data['cover_style']!, _coverStyleMeta),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('trashed_at')) {
      context.handle(
        _trashedAtMeta,
        trashedAt.isAcceptableOrUnknown(data['trashed_at']!, _trashedAtMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $DocumentsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      coverStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cover_style'],
      )!,
      orientation: $DocumentsTable.$converterorientation.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}orientation'],
        )!,
      ),
      pageSize: $DocumentsTable.$converterpageSize.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}page_size'],
        )!,
      ),
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      trashedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trashed_at'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DocumentType, int, int> $convertertype =
      const EnumIndexConverter<DocumentType>(DocumentType.values);
  static JsonTypeConverter2<PageOrientation, int, int> $converterorientation =
      const EnumIndexConverter<PageOrientation>(PageOrientation.values);
  static JsonTypeConverter2<PageSizePreset, int, int> $converterpageSize =
      const EnumIndexConverter<PageSizePreset>(PageSizePreset.values);
}

class Document extends DataClass implements Insertable<Document> {
  final String id;
  final DocumentType type;
  final String title;
  final String? parentId;

  /// Index into the built-in cover palette (notebooks only).
  final int coverStyle;
  final PageOrientation orientation;
  final PageSizePreset pageSize;
  final bool starred;

  /// Null unless soft-deleted (in trash).
  final DateTime? trashedAt;

  /// Manual ordering within a folder.
  final int sortIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  const Document({
    required this.id,
    required this.type,
    required this.title,
    this.parentId,
    required this.coverStyle,
    required this.orientation,
    required this.pageSize,
    required this.starred,
    this.trashedAt,
    required this.sortIndex,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<int>($DocumentsTable.$convertertype.toSql(type));
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['cover_style'] = Variable<int>(coverStyle);
    {
      map['orientation'] = Variable<int>(
        $DocumentsTable.$converterorientation.toSql(orientation),
      );
    }
    {
      map['page_size'] = Variable<int>(
        $DocumentsTable.$converterpageSize.toSql(pageSize),
      );
    }
    map['starred'] = Variable<bool>(starred);
    if (!nullToAbsent || trashedAt != null) {
      map['trashed_at'] = Variable<DateTime>(trashedAt);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      coverStyle: Value(coverStyle),
      orientation: Value(orientation),
      pageSize: Value(pageSize),
      starred: Value(starred),
      trashedAt: trashedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(trashedAt),
      sortIndex: Value(sortIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      id: serializer.fromJson<String>(json['id']),
      type: $DocumentsTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      title: serializer.fromJson<String>(json['title']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      coverStyle: serializer.fromJson<int>(json['coverStyle']),
      orientation: $DocumentsTable.$converterorientation.fromJson(
        serializer.fromJson<int>(json['orientation']),
      ),
      pageSize: $DocumentsTable.$converterpageSize.fromJson(
        serializer.fromJson<int>(json['pageSize']),
      ),
      starred: serializer.fromJson<bool>(json['starred']),
      trashedAt: serializer.fromJson<DateTime?>(json['trashedAt']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<int>(
        $DocumentsTable.$convertertype.toJson(type),
      ),
      'title': serializer.toJson<String>(title),
      'parentId': serializer.toJson<String?>(parentId),
      'coverStyle': serializer.toJson<int>(coverStyle),
      'orientation': serializer.toJson<int>(
        $DocumentsTable.$converterorientation.toJson(orientation),
      ),
      'pageSize': serializer.toJson<int>(
        $DocumentsTable.$converterpageSize.toJson(pageSize),
      ),
      'starred': serializer.toJson<bool>(starred),
      'trashedAt': serializer.toJson<DateTime?>(trashedAt),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
    };
  }

  Document copyWith({
    String? id,
    DocumentType? type,
    String? title,
    Value<String?> parentId = const Value.absent(),
    int? coverStyle,
    PageOrientation? orientation,
    PageSizePreset? pageSize,
    bool? starred,
    Value<DateTime?> trashedAt = const Value.absent(),
    int? sortIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
  }) => Document(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    parentId: parentId.present ? parentId.value : this.parentId,
    coverStyle: coverStyle ?? this.coverStyle,
    orientation: orientation ?? this.orientation,
    pageSize: pageSize ?? this.pageSize,
    starred: starred ?? this.starred,
    trashedAt: trashedAt.present ? trashedAt.value : this.trashedAt,
    sortIndex: sortIndex ?? this.sortIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      coverStyle: data.coverStyle.present
          ? data.coverStyle.value
          : this.coverStyle,
      orientation: data.orientation.present
          ? data.orientation.value
          : this.orientation,
      pageSize: data.pageSize.present ? data.pageSize.value : this.pageSize,
      starred: data.starred.present ? data.starred.value : this.starred,
      trashedAt: data.trashedAt.present ? data.trashedAt.value : this.trashedAt,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('parentId: $parentId, ')
          ..write('coverStyle: $coverStyle, ')
          ..write('orientation: $orientation, ')
          ..write('pageSize: $pageSize, ')
          ..write('starred: $starred, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    parentId,
    coverStyle,
    orientation,
    pageSize,
    starred,
    trashedAt,
    sortIndex,
    createdAt,
    updatedAt,
    lastOpenedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.parentId == this.parentId &&
          other.coverStyle == this.coverStyle &&
          other.orientation == this.orientation &&
          other.pageSize == this.pageSize &&
          other.starred == this.starred &&
          other.trashedAt == this.trashedAt &&
          other.sortIndex == this.sortIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<String> id;
  final Value<DocumentType> type;
  final Value<String> title;
  final Value<String?> parentId;
  final Value<int> coverStyle;
  final Value<PageOrientation> orientation;
  final Value<PageSizePreset> pageSize;
  final Value<bool> starred;
  final Value<DateTime?> trashedAt;
  final Value<int> sortIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.parentId = const Value.absent(),
    this.coverStyle = const Value.absent(),
    this.orientation = const Value.absent(),
    this.pageSize = const Value.absent(),
    this.starred = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String id,
    required DocumentType type,
    this.title = const Value.absent(),
    this.parentId = const Value.absent(),
    this.coverStyle = const Value.absent(),
    this.orientation = const Value.absent(),
    this.pageSize = const Value.absent(),
    this.starred = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type);
  static Insertable<Document> custom({
    Expression<String>? id,
    Expression<int>? type,
    Expression<String>? title,
    Expression<String>? parentId,
    Expression<int>? coverStyle,
    Expression<int>? orientation,
    Expression<int>? pageSize,
    Expression<bool>? starred,
    Expression<DateTime>? trashedAt,
    Expression<int>? sortIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (parentId != null) 'parent_id': parentId,
      if (coverStyle != null) 'cover_style': coverStyle,
      if (orientation != null) 'orientation': orientation,
      if (pageSize != null) 'page_size': pageSize,
      if (starred != null) 'starred': starred,
      if (trashedAt != null) 'trashed_at': trashedAt,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? id,
    Value<DocumentType>? type,
    Value<String>? title,
    Value<String?>? parentId,
    Value<int>? coverStyle,
    Value<PageOrientation>? orientation,
    Value<PageSizePreset>? pageSize,
    Value<bool>? starred,
    Value<DateTime?>? trashedAt,
    Value<int>? sortIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      parentId: parentId ?? this.parentId,
      coverStyle: coverStyle ?? this.coverStyle,
      orientation: orientation ?? this.orientation,
      pageSize: pageSize ?? this.pageSize,
      starred: starred ?? this.starred,
      trashedAt: trashedAt ?? this.trashedAt,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $DocumentsTable.$convertertype.toSql(type.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (coverStyle.present) {
      map['cover_style'] = Variable<int>(coverStyle.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<int>(
        $DocumentsTable.$converterorientation.toSql(orientation.value),
      );
    }
    if (pageSize.present) {
      map['page_size'] = Variable<int>(
        $DocumentsTable.$converterpageSize.toSql(pageSize.value),
      );
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (trashedAt.present) {
      map['trashed_at'] = Variable<DateTime>(trashedAt.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('parentId: $parentId, ')
          ..write('coverStyle: $coverStyle, ')
          ..write('orientation: $orientation, ')
          ..write('pageSize: $pageSize, ')
          ..write('starred: $starred, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotePagesTable extends NotePages
    with TableInfo<$NotePagesTable, NotePage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotePagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PaperTemplate, int> template =
      GeneratedColumn<int>(
        'template',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<PaperTemplate>($NotePagesTable.$convertertemplate);
  @override
  late final GeneratedColumnWithTypeConverter<PaperColor, int> paperColor =
      GeneratedColumn<int>(
        'paper_color',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<PaperColor>($NotePagesTable.$converterpaperColor);
  @override
  late final GeneratedColumnWithTypeConverter<MarginSpec, String> marginSpec =
      GeneratedColumn<String>(
        'margin_spec',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      ).withConverter<MarginSpec>($NotePagesTable.$convertermarginSpec);
  static const VerificationMeta _pdfAssetIdMeta = const VerificationMeta(
    'pdfAssetId',
  );
  @override
  late final GeneratedColumn<String> pdfAssetId = GeneratedColumn<String>(
    'pdf_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pdfPageIndexMeta = const VerificationMeta(
    'pdfPageIndex',
  );
  @override
  late final GeneratedColumn<int> pdfPageIndex = GeneratedColumn<int>(
    'pdf_page_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookmarkTitleMeta = const VerificationMeta(
    'bookmarkTitle',
  );
  @override
  late final GeneratedColumn<String> bookmarkTitle = GeneratedColumn<String>(
    'bookmark_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    pageIndex,
    template,
    paperColor,
    marginSpec,
    pdfAssetId,
    pdfPageIndex,
    bookmarkTitle,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotePage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('pdf_asset_id')) {
      context.handle(
        _pdfAssetIdMeta,
        pdfAssetId.isAcceptableOrUnknown(
          data['pdf_asset_id']!,
          _pdfAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('pdf_page_index')) {
      context.handle(
        _pdfPageIndexMeta,
        pdfPageIndex.isAcceptableOrUnknown(
          data['pdf_page_index']!,
          _pdfPageIndexMeta,
        ),
      );
    }
    if (data.containsKey('bookmark_title')) {
      context.handle(
        _bookmarkTitleMeta,
        bookmarkTitle.isAcceptableOrUnknown(
          data['bookmark_title']!,
          _bookmarkTitleMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotePage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotePage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      template: $NotePagesTable.$convertertemplate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}template'],
        )!,
      ),
      paperColor: $NotePagesTable.$converterpaperColor.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}paper_color'],
        )!,
      ),
      marginSpec: $NotePagesTable.$convertermarginSpec.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}margin_spec'],
        )!,
      ),
      pdfAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_asset_id'],
      ),
      pdfPageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pdf_page_index'],
      ),
      bookmarkTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bookmark_title'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotePagesTable createAlias(String alias) {
    return $NotePagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PaperTemplate, int, int> $convertertemplate =
      const EnumIndexConverter<PaperTemplate>(PaperTemplate.values);
  static JsonTypeConverter2<PaperColor, int, int> $converterpaperColor =
      const EnumIndexConverter<PaperColor>(PaperColor.values);
  static TypeConverter<MarginSpec, String> $convertermarginSpec =
      const MarginSpecConverter();
}

class NotePage extends DataClass implements Insertable<NotePage> {
  final String id;
  final String documentId;
  final int pageIndex;
  final PaperTemplate template;
  final PaperColor paperColor;

  /// Adjustable margins — the custom-feature seam. Stored as JSON.
  final MarginSpec marginSpec;

  /// For PDF-backed pages: the source asset + which page of it.
  final String? pdfAssetId;
  final int? pdfPageIndex;
  final String? bookmarkTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  const NotePage({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.template,
    required this.paperColor,
    required this.marginSpec,
    this.pdfAssetId,
    this.pdfPageIndex,
    this.bookmarkTitle,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['page_index'] = Variable<int>(pageIndex);
    {
      map['template'] = Variable<int>(
        $NotePagesTable.$convertertemplate.toSql(template),
      );
    }
    {
      map['paper_color'] = Variable<int>(
        $NotePagesTable.$converterpaperColor.toSql(paperColor),
      );
    }
    {
      map['margin_spec'] = Variable<String>(
        $NotePagesTable.$convertermarginSpec.toSql(marginSpec),
      );
    }
    if (!nullToAbsent || pdfAssetId != null) {
      map['pdf_asset_id'] = Variable<String>(pdfAssetId);
    }
    if (!nullToAbsent || pdfPageIndex != null) {
      map['pdf_page_index'] = Variable<int>(pdfPageIndex);
    }
    if (!nullToAbsent || bookmarkTitle != null) {
      map['bookmark_title'] = Variable<String>(bookmarkTitle);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotePagesCompanion toCompanion(bool nullToAbsent) {
    return NotePagesCompanion(
      id: Value(id),
      documentId: Value(documentId),
      pageIndex: Value(pageIndex),
      template: Value(template),
      paperColor: Value(paperColor),
      marginSpec: Value(marginSpec),
      pdfAssetId: pdfAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfAssetId),
      pdfPageIndex: pdfPageIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfPageIndex),
      bookmarkTitle: bookmarkTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(bookmarkTitle),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NotePage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotePage(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      template: $NotePagesTable.$convertertemplate.fromJson(
        serializer.fromJson<int>(json['template']),
      ),
      paperColor: $NotePagesTable.$converterpaperColor.fromJson(
        serializer.fromJson<int>(json['paperColor']),
      ),
      marginSpec: serializer.fromJson<MarginSpec>(json['marginSpec']),
      pdfAssetId: serializer.fromJson<String?>(json['pdfAssetId']),
      pdfPageIndex: serializer.fromJson<int?>(json['pdfPageIndex']),
      bookmarkTitle: serializer.fromJson<String?>(json['bookmarkTitle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'template': serializer.toJson<int>(
        $NotePagesTable.$convertertemplate.toJson(template),
      ),
      'paperColor': serializer.toJson<int>(
        $NotePagesTable.$converterpaperColor.toJson(paperColor),
      ),
      'marginSpec': serializer.toJson<MarginSpec>(marginSpec),
      'pdfAssetId': serializer.toJson<String?>(pdfAssetId),
      'pdfPageIndex': serializer.toJson<int?>(pdfPageIndex),
      'bookmarkTitle': serializer.toJson<String?>(bookmarkTitle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NotePage copyWith({
    String? id,
    String? documentId,
    int? pageIndex,
    PaperTemplate? template,
    PaperColor? paperColor,
    MarginSpec? marginSpec,
    Value<String?> pdfAssetId = const Value.absent(),
    Value<int?> pdfPageIndex = const Value.absent(),
    Value<String?> bookmarkTitle = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NotePage(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    pageIndex: pageIndex ?? this.pageIndex,
    template: template ?? this.template,
    paperColor: paperColor ?? this.paperColor,
    marginSpec: marginSpec ?? this.marginSpec,
    pdfAssetId: pdfAssetId.present ? pdfAssetId.value : this.pdfAssetId,
    pdfPageIndex: pdfPageIndex.present ? pdfPageIndex.value : this.pdfPageIndex,
    bookmarkTitle: bookmarkTitle.present
        ? bookmarkTitle.value
        : this.bookmarkTitle,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NotePage copyWithCompanion(NotePagesCompanion data) {
    return NotePage(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      template: data.template.present ? data.template.value : this.template,
      paperColor: data.paperColor.present
          ? data.paperColor.value
          : this.paperColor,
      marginSpec: data.marginSpec.present
          ? data.marginSpec.value
          : this.marginSpec,
      pdfAssetId: data.pdfAssetId.present
          ? data.pdfAssetId.value
          : this.pdfAssetId,
      pdfPageIndex: data.pdfPageIndex.present
          ? data.pdfPageIndex.value
          : this.pdfPageIndex,
      bookmarkTitle: data.bookmarkTitle.present
          ? data.bookmarkTitle.value
          : this.bookmarkTitle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotePage(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('template: $template, ')
          ..write('paperColor: $paperColor, ')
          ..write('marginSpec: $marginSpec, ')
          ..write('pdfAssetId: $pdfAssetId, ')
          ..write('pdfPageIndex: $pdfPageIndex, ')
          ..write('bookmarkTitle: $bookmarkTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    pageIndex,
    template,
    paperColor,
    marginSpec,
    pdfAssetId,
    pdfPageIndex,
    bookmarkTitle,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotePage &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.pageIndex == this.pageIndex &&
          other.template == this.template &&
          other.paperColor == this.paperColor &&
          other.marginSpec == this.marginSpec &&
          other.pdfAssetId == this.pdfAssetId &&
          other.pdfPageIndex == this.pdfPageIndex &&
          other.bookmarkTitle == this.bookmarkTitle &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotePagesCompanion extends UpdateCompanion<NotePage> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<int> pageIndex;
  final Value<PaperTemplate> template;
  final Value<PaperColor> paperColor;
  final Value<MarginSpec> marginSpec;
  final Value<String?> pdfAssetId;
  final Value<int?> pdfPageIndex;
  final Value<String?> bookmarkTitle;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotePagesCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.template = const Value.absent(),
    this.paperColor = const Value.absent(),
    this.marginSpec = const Value.absent(),
    this.pdfAssetId = const Value.absent(),
    this.pdfPageIndex = const Value.absent(),
    this.bookmarkTitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotePagesCompanion.insert({
    required String id,
    required String documentId,
    required int pageIndex,
    this.template = const Value.absent(),
    this.paperColor = const Value.absent(),
    this.marginSpec = const Value.absent(),
    this.pdfAssetId = const Value.absent(),
    this.pdfPageIndex = const Value.absent(),
    this.bookmarkTitle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       pageIndex = Value(pageIndex);
  static Insertable<NotePage> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<int>? pageIndex,
    Expression<int>? template,
    Expression<int>? paperColor,
    Expression<String>? marginSpec,
    Expression<String>? pdfAssetId,
    Expression<int>? pdfPageIndex,
    Expression<String>? bookmarkTitle,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (template != null) 'template': template,
      if (paperColor != null) 'paper_color': paperColor,
      if (marginSpec != null) 'margin_spec': marginSpec,
      if (pdfAssetId != null) 'pdf_asset_id': pdfAssetId,
      if (pdfPageIndex != null) 'pdf_page_index': pdfPageIndex,
      if (bookmarkTitle != null) 'bookmark_title': bookmarkTitle,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotePagesCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<int>? pageIndex,
    Value<PaperTemplate>? template,
    Value<PaperColor>? paperColor,
    Value<MarginSpec>? marginSpec,
    Value<String?>? pdfAssetId,
    Value<int?>? pdfPageIndex,
    Value<String?>? bookmarkTitle,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotePagesCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      template: template ?? this.template,
      paperColor: paperColor ?? this.paperColor,
      marginSpec: marginSpec ?? this.marginSpec,
      pdfAssetId: pdfAssetId ?? this.pdfAssetId,
      pdfPageIndex: pdfPageIndex ?? this.pdfPageIndex,
      bookmarkTitle: bookmarkTitle ?? this.bookmarkTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (template.present) {
      map['template'] = Variable<int>(
        $NotePagesTable.$convertertemplate.toSql(template.value),
      );
    }
    if (paperColor.present) {
      map['paper_color'] = Variable<int>(
        $NotePagesTable.$converterpaperColor.toSql(paperColor.value),
      );
    }
    if (marginSpec.present) {
      map['margin_spec'] = Variable<String>(
        $NotePagesTable.$convertermarginSpec.toSql(marginSpec.value),
      );
    }
    if (pdfAssetId.present) {
      map['pdf_asset_id'] = Variable<String>(pdfAssetId.value);
    }
    if (pdfPageIndex.present) {
      map['pdf_page_index'] = Variable<int>(pdfPageIndex.value);
    }
    if (bookmarkTitle.present) {
      map['bookmark_title'] = Variable<String>(bookmarkTitle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotePagesCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('template: $template, ')
          ..write('paperColor: $paperColor, ')
          ..write('marginSpec: $marginSpec, ')
          ..write('pdfAssetId: $pdfAssetId, ')
          ..write('pdfPageIndex: $pdfPageIndex, ')
          ..write('bookmarkTitle: $bookmarkTitle, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StrokesTable extends Strokes with TableInfo<$StrokesTable, Stroke> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StrokesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIdMeta = const VerificationMeta('pageId');
  @override
  late final GeneratedColumn<String> pageId = GeneratedColumn<String>(
    'page_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES note_pages (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ToolType, int> tool =
      GeneratedColumn<int>(
        'tool',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ToolType>($StrokesTable.$convertertool);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opacityMeta = const VerificationMeta(
    'opacity',
  );
  @override
  late final GeneratedColumn<double> opacity = GeneratedColumn<double>(
    'opacity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<Uint8List> points = GeneratedColumn<Uint8List>(
    'points',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bboxLMeta = const VerificationMeta('bboxL');
  @override
  late final GeneratedColumn<double> bboxL = GeneratedColumn<double>(
    'bbox_l',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bboxTMeta = const VerificationMeta('bboxT');
  @override
  late final GeneratedColumn<double> bboxT = GeneratedColumn<double>(
    'bbox_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bboxRMeta = const VerificationMeta('bboxR');
  @override
  late final GeneratedColumn<double> bboxR = GeneratedColumn<double>(
    'bbox_r',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bboxBMeta = const VerificationMeta('bboxB');
  @override
  late final GeneratedColumn<double> bboxB = GeneratedColumn<double>(
    'bbox_b',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pageId,
    tool,
    color,
    width,
    opacity,
    points,
    bboxL,
    bboxT,
    bboxR,
    bboxB,
    seq,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'strokes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Stroke> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('page_id')) {
      context.handle(
        _pageIdMeta,
        pageId.isAcceptableOrUnknown(data['page_id']!, _pageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIdMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('opacity')) {
      context.handle(
        _opacityMeta,
        opacity.isAcceptableOrUnknown(data['opacity']!, _opacityMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsMeta);
    }
    if (data.containsKey('bbox_l')) {
      context.handle(
        _bboxLMeta,
        bboxL.isAcceptableOrUnknown(data['bbox_l']!, _bboxLMeta),
      );
    } else if (isInserting) {
      context.missing(_bboxLMeta);
    }
    if (data.containsKey('bbox_t')) {
      context.handle(
        _bboxTMeta,
        bboxT.isAcceptableOrUnknown(data['bbox_t']!, _bboxTMeta),
      );
    } else if (isInserting) {
      context.missing(_bboxTMeta);
    }
    if (data.containsKey('bbox_r')) {
      context.handle(
        _bboxRMeta,
        bboxR.isAcceptableOrUnknown(data['bbox_r']!, _bboxRMeta),
      );
    } else if (isInserting) {
      context.missing(_bboxRMeta);
    }
    if (data.containsKey('bbox_b')) {
      context.handle(
        _bboxBMeta,
        bboxB.isAcceptableOrUnknown(data['bbox_b']!, _bboxBMeta),
      );
    } else if (isInserting) {
      context.missing(_bboxBMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Stroke map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Stroke(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_id'],
      )!,
      tool: $StrokesTable.$convertertool.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}tool'],
        )!,
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      opacity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}opacity'],
      )!,
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}points'],
      )!,
      bboxL: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bbox_l'],
      )!,
      bboxT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bbox_t'],
      )!,
      bboxR: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bbox_r'],
      )!,
      bboxB: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bbox_b'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StrokesTable createAlias(String alias) {
    return $StrokesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ToolType, int, int> $convertertool =
      const EnumIndexConverter<ToolType>(ToolType.values);
}

class Stroke extends DataClass implements Insertable<Stroke> {
  final String id;
  final String pageId;
  final ToolType tool;

  /// ARGB colour.
  final int color;
  final double width;
  final double opacity;
  final Uint8List points;
  final double bboxL;
  final double bboxT;
  final double bboxR;
  final double bboxB;

  /// Draw order within the page.
  final int seq;
  final DateTime createdAt;
  const Stroke({
    required this.id,
    required this.pageId,
    required this.tool,
    required this.color,
    required this.width,
    required this.opacity,
    required this.points,
    required this.bboxL,
    required this.bboxT,
    required this.bboxR,
    required this.bboxB,
    required this.seq,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['page_id'] = Variable<String>(pageId);
    {
      map['tool'] = Variable<int>($StrokesTable.$convertertool.toSql(tool));
    }
    map['color'] = Variable<int>(color);
    map['width'] = Variable<double>(width);
    map['opacity'] = Variable<double>(opacity);
    map['points'] = Variable<Uint8List>(points);
    map['bbox_l'] = Variable<double>(bboxL);
    map['bbox_t'] = Variable<double>(bboxT);
    map['bbox_r'] = Variable<double>(bboxR);
    map['bbox_b'] = Variable<double>(bboxB);
    map['seq'] = Variable<int>(seq);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StrokesCompanion toCompanion(bool nullToAbsent) {
    return StrokesCompanion(
      id: Value(id),
      pageId: Value(pageId),
      tool: Value(tool),
      color: Value(color),
      width: Value(width),
      opacity: Value(opacity),
      points: Value(points),
      bboxL: Value(bboxL),
      bboxT: Value(bboxT),
      bboxR: Value(bboxR),
      bboxB: Value(bboxB),
      seq: Value(seq),
      createdAt: Value(createdAt),
    );
  }

  factory Stroke.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Stroke(
      id: serializer.fromJson<String>(json['id']),
      pageId: serializer.fromJson<String>(json['pageId']),
      tool: $StrokesTable.$convertertool.fromJson(
        serializer.fromJson<int>(json['tool']),
      ),
      color: serializer.fromJson<int>(json['color']),
      width: serializer.fromJson<double>(json['width']),
      opacity: serializer.fromJson<double>(json['opacity']),
      points: serializer.fromJson<Uint8List>(json['points']),
      bboxL: serializer.fromJson<double>(json['bboxL']),
      bboxT: serializer.fromJson<double>(json['bboxT']),
      bboxR: serializer.fromJson<double>(json['bboxR']),
      bboxB: serializer.fromJson<double>(json['bboxB']),
      seq: serializer.fromJson<int>(json['seq']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pageId': serializer.toJson<String>(pageId),
      'tool': serializer.toJson<int>($StrokesTable.$convertertool.toJson(tool)),
      'color': serializer.toJson<int>(color),
      'width': serializer.toJson<double>(width),
      'opacity': serializer.toJson<double>(opacity),
      'points': serializer.toJson<Uint8List>(points),
      'bboxL': serializer.toJson<double>(bboxL),
      'bboxT': serializer.toJson<double>(bboxT),
      'bboxR': serializer.toJson<double>(bboxR),
      'bboxB': serializer.toJson<double>(bboxB),
      'seq': serializer.toJson<int>(seq),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Stroke copyWith({
    String? id,
    String? pageId,
    ToolType? tool,
    int? color,
    double? width,
    double? opacity,
    Uint8List? points,
    double? bboxL,
    double? bboxT,
    double? bboxR,
    double? bboxB,
    int? seq,
    DateTime? createdAt,
  }) => Stroke(
    id: id ?? this.id,
    pageId: pageId ?? this.pageId,
    tool: tool ?? this.tool,
    color: color ?? this.color,
    width: width ?? this.width,
    opacity: opacity ?? this.opacity,
    points: points ?? this.points,
    bboxL: bboxL ?? this.bboxL,
    bboxT: bboxT ?? this.bboxT,
    bboxR: bboxR ?? this.bboxR,
    bboxB: bboxB ?? this.bboxB,
    seq: seq ?? this.seq,
    createdAt: createdAt ?? this.createdAt,
  );
  Stroke copyWithCompanion(StrokesCompanion data) {
    return Stroke(
      id: data.id.present ? data.id.value : this.id,
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      tool: data.tool.present ? data.tool.value : this.tool,
      color: data.color.present ? data.color.value : this.color,
      width: data.width.present ? data.width.value : this.width,
      opacity: data.opacity.present ? data.opacity.value : this.opacity,
      points: data.points.present ? data.points.value : this.points,
      bboxL: data.bboxL.present ? data.bboxL.value : this.bboxL,
      bboxT: data.bboxT.present ? data.bboxT.value : this.bboxT,
      bboxR: data.bboxR.present ? data.bboxR.value : this.bboxR,
      bboxB: data.bboxB.present ? data.bboxB.value : this.bboxB,
      seq: data.seq.present ? data.seq.value : this.seq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Stroke(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('tool: $tool, ')
          ..write('color: $color, ')
          ..write('width: $width, ')
          ..write('opacity: $opacity, ')
          ..write('points: $points, ')
          ..write('bboxL: $bboxL, ')
          ..write('bboxT: $bboxT, ')
          ..write('bboxR: $bboxR, ')
          ..write('bboxB: $bboxB, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pageId,
    tool,
    color,
    width,
    opacity,
    $driftBlobEquality.hash(points),
    bboxL,
    bboxT,
    bboxR,
    bboxB,
    seq,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Stroke &&
          other.id == this.id &&
          other.pageId == this.pageId &&
          other.tool == this.tool &&
          other.color == this.color &&
          other.width == this.width &&
          other.opacity == this.opacity &&
          $driftBlobEquality.equals(other.points, this.points) &&
          other.bboxL == this.bboxL &&
          other.bboxT == this.bboxT &&
          other.bboxR == this.bboxR &&
          other.bboxB == this.bboxB &&
          other.seq == this.seq &&
          other.createdAt == this.createdAt);
}

class StrokesCompanion extends UpdateCompanion<Stroke> {
  final Value<String> id;
  final Value<String> pageId;
  final Value<ToolType> tool;
  final Value<int> color;
  final Value<double> width;
  final Value<double> opacity;
  final Value<Uint8List> points;
  final Value<double> bboxL;
  final Value<double> bboxT;
  final Value<double> bboxR;
  final Value<double> bboxB;
  final Value<int> seq;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StrokesCompanion({
    this.id = const Value.absent(),
    this.pageId = const Value.absent(),
    this.tool = const Value.absent(),
    this.color = const Value.absent(),
    this.width = const Value.absent(),
    this.opacity = const Value.absent(),
    this.points = const Value.absent(),
    this.bboxL = const Value.absent(),
    this.bboxT = const Value.absent(),
    this.bboxR = const Value.absent(),
    this.bboxB = const Value.absent(),
    this.seq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StrokesCompanion.insert({
    required String id,
    required String pageId,
    required ToolType tool,
    required int color,
    required double width,
    this.opacity = const Value.absent(),
    required Uint8List points,
    required double bboxL,
    required double bboxT,
    required double bboxR,
    required double bboxB,
    required int seq,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pageId = Value(pageId),
       tool = Value(tool),
       color = Value(color),
       width = Value(width),
       points = Value(points),
       bboxL = Value(bboxL),
       bboxT = Value(bboxT),
       bboxR = Value(bboxR),
       bboxB = Value(bboxB),
       seq = Value(seq);
  static Insertable<Stroke> custom({
    Expression<String>? id,
    Expression<String>? pageId,
    Expression<int>? tool,
    Expression<int>? color,
    Expression<double>? width,
    Expression<double>? opacity,
    Expression<Uint8List>? points,
    Expression<double>? bboxL,
    Expression<double>? bboxT,
    Expression<double>? bboxR,
    Expression<double>? bboxB,
    Expression<int>? seq,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pageId != null) 'page_id': pageId,
      if (tool != null) 'tool': tool,
      if (color != null) 'color': color,
      if (width != null) 'width': width,
      if (opacity != null) 'opacity': opacity,
      if (points != null) 'points': points,
      if (bboxL != null) 'bbox_l': bboxL,
      if (bboxT != null) 'bbox_t': bboxT,
      if (bboxR != null) 'bbox_r': bboxR,
      if (bboxB != null) 'bbox_b': bboxB,
      if (seq != null) 'seq': seq,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StrokesCompanion copyWith({
    Value<String>? id,
    Value<String>? pageId,
    Value<ToolType>? tool,
    Value<int>? color,
    Value<double>? width,
    Value<double>? opacity,
    Value<Uint8List>? points,
    Value<double>? bboxL,
    Value<double>? bboxT,
    Value<double>? bboxR,
    Value<double>? bboxB,
    Value<int>? seq,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StrokesCompanion(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      tool: tool ?? this.tool,
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      points: points ?? this.points,
      bboxL: bboxL ?? this.bboxL,
      bboxT: bboxT ?? this.bboxT,
      bboxR: bboxR ?? this.bboxR,
      bboxB: bboxB ?? this.bboxB,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pageId.present) {
      map['page_id'] = Variable<String>(pageId.value);
    }
    if (tool.present) {
      map['tool'] = Variable<int>(
        $StrokesTable.$convertertool.toSql(tool.value),
      );
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (opacity.present) {
      map['opacity'] = Variable<double>(opacity.value);
    }
    if (points.present) {
      map['points'] = Variable<Uint8List>(points.value);
    }
    if (bboxL.present) {
      map['bbox_l'] = Variable<double>(bboxL.value);
    }
    if (bboxT.present) {
      map['bbox_t'] = Variable<double>(bboxT.value);
    }
    if (bboxR.present) {
      map['bbox_r'] = Variable<double>(bboxR.value);
    }
    if (bboxB.present) {
      map['bbox_b'] = Variable<double>(bboxB.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StrokesCompanion(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('tool: $tool, ')
          ..write('color: $color, ')
          ..write('width: $width, ')
          ..write('opacity: $opacity, ')
          ..write('points: $points, ')
          ..write('bboxL: $bboxL, ')
          ..write('bboxT: $bboxT, ')
          ..write('bboxR: $bboxR, ')
          ..write('bboxB: $bboxB, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CanvasElementsTable extends CanvasElements
    with TableInfo<$CanvasElementsTable, CanvasElement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CanvasElementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIdMeta = const VerificationMeta('pageId');
  @override
  late final GeneratedColumn<String> pageId = GeneratedColumn<String>(
    'page_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES note_pages (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ElementType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ElementType>($CanvasElementsTable.$convertertype);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(40),
  );
  static const VerificationMeta _scaleMeta = const VerificationMeta('scale');
  @override
  late final GeneratedColumn<double> scale = GeneratedColumn<double>(
    'scale',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _rotationMeta = const VerificationMeta(
    'rotation',
  );
  @override
  late final GeneratedColumn<double> rotation = GeneratedColumn<double>(
    'rotation',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _zMeta = const VerificationMeta('z');
  @override
  late final GeneratedColumn<int> z = GeneratedColumn<int>(
    'z',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pageId,
    type,
    data,
    x,
    y,
    width,
    height,
    scale,
    rotation,
    z,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'canvas_elements';
  @override
  VerificationContext validateIntegrity(
    Insertable<CanvasElement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('page_id')) {
      context.handle(
        _pageIdMeta,
        pageId.isAcceptableOrUnknown(data['page_id']!, _pageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('scale')) {
      context.handle(
        _scaleMeta,
        scale.isAcceptableOrUnknown(data['scale']!, _scaleMeta),
      );
    }
    if (data.containsKey('rotation')) {
      context.handle(
        _rotationMeta,
        rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta),
      );
    }
    if (data.containsKey('z')) {
      context.handle(_zMeta, z.isAcceptableOrUnknown(data['z']!, _zMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CanvasElement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CanvasElement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      pageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_id'],
      )!,
      type: $CanvasElementsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      scale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scale'],
      )!,
      rotation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rotation'],
      )!,
      z: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}z'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CanvasElementsTable createAlias(String alias) {
    return $CanvasElementsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ElementType, int, int> $convertertype =
      const EnumIndexConverter<ElementType>(ElementType.values);
}

class CanvasElement extends DataClass implements Insertable<CanvasElement> {
  final String id;
  final String pageId;
  final ElementType type;

  /// Type-specific payload as JSON (text content/style, asset id, shape spec).
  final String data;
  final double x;
  final double y;
  final double width;
  final double height;
  final double scale;
  final double rotation;
  final int z;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CanvasElement({
    required this.id,
    required this.pageId,
    required this.type,
    required this.data,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.scale,
    required this.rotation,
    required this.z,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['page_id'] = Variable<String>(pageId);
    {
      map['type'] = Variable<int>(
        $CanvasElementsTable.$convertertype.toSql(type),
      );
    }
    map['data'] = Variable<String>(data);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['scale'] = Variable<double>(scale);
    map['rotation'] = Variable<double>(rotation);
    map['z'] = Variable<int>(z);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CanvasElementsCompanion toCompanion(bool nullToAbsent) {
    return CanvasElementsCompanion(
      id: Value(id),
      pageId: Value(pageId),
      type: Value(type),
      data: Value(data),
      x: Value(x),
      y: Value(y),
      width: Value(width),
      height: Value(height),
      scale: Value(scale),
      rotation: Value(rotation),
      z: Value(z),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CanvasElement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CanvasElement(
      id: serializer.fromJson<String>(json['id']),
      pageId: serializer.fromJson<String>(json['pageId']),
      type: $CanvasElementsTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      data: serializer.fromJson<String>(json['data']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      scale: serializer.fromJson<double>(json['scale']),
      rotation: serializer.fromJson<double>(json['rotation']),
      z: serializer.fromJson<int>(json['z']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'pageId': serializer.toJson<String>(pageId),
      'type': serializer.toJson<int>(
        $CanvasElementsTable.$convertertype.toJson(type),
      ),
      'data': serializer.toJson<String>(data),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'scale': serializer.toJson<double>(scale),
      'rotation': serializer.toJson<double>(rotation),
      'z': serializer.toJson<int>(z),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CanvasElement copyWith({
    String? id,
    String? pageId,
    ElementType? type,
    String? data,
    double? x,
    double? y,
    double? width,
    double? height,
    double? scale,
    double? rotation,
    int? z,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CanvasElement(
    id: id ?? this.id,
    pageId: pageId ?? this.pageId,
    type: type ?? this.type,
    data: data ?? this.data,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    z: z ?? this.z,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CanvasElement copyWithCompanion(CanvasElementsCompanion data) {
    return CanvasElement(
      id: data.id.present ? data.id.value : this.id,
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      type: data.type.present ? data.type.value : this.type,
      data: data.data.present ? data.data.value : this.data,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      scale: data.scale.present ? data.scale.value : this.scale,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      z: data.z.present ? data.z.value : this.z,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CanvasElement(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('type: $type, ')
          ..write('data: $data, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('scale: $scale, ')
          ..write('rotation: $rotation, ')
          ..write('z: $z, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pageId,
    type,
    data,
    x,
    y,
    width,
    height,
    scale,
    rotation,
    z,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CanvasElement &&
          other.id == this.id &&
          other.pageId == this.pageId &&
          other.type == this.type &&
          other.data == this.data &&
          other.x == this.x &&
          other.y == this.y &&
          other.width == this.width &&
          other.height == this.height &&
          other.scale == this.scale &&
          other.rotation == this.rotation &&
          other.z == this.z &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CanvasElementsCompanion extends UpdateCompanion<CanvasElement> {
  final Value<String> id;
  final Value<String> pageId;
  final Value<ElementType> type;
  final Value<String> data;
  final Value<double> x;
  final Value<double> y;
  final Value<double> width;
  final Value<double> height;
  final Value<double> scale;
  final Value<double> rotation;
  final Value<int> z;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CanvasElementsCompanion({
    this.id = const Value.absent(),
    this.pageId = const Value.absent(),
    this.type = const Value.absent(),
    this.data = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.scale = const Value.absent(),
    this.rotation = const Value.absent(),
    this.z = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CanvasElementsCompanion.insert({
    required String id,
    required String pageId,
    required ElementType type,
    required String data,
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.scale = const Value.absent(),
    this.rotation = const Value.absent(),
    this.z = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pageId = Value(pageId),
       type = Value(type),
       data = Value(data);
  static Insertable<CanvasElement> custom({
    Expression<String>? id,
    Expression<String>? pageId,
    Expression<int>? type,
    Expression<String>? data,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? width,
    Expression<double>? height,
    Expression<double>? scale,
    Expression<double>? rotation,
    Expression<int>? z,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pageId != null) 'page_id': pageId,
      if (type != null) 'type': type,
      if (data != null) 'data': data,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (scale != null) 'scale': scale,
      if (rotation != null) 'rotation': rotation,
      if (z != null) 'z': z,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CanvasElementsCompanion copyWith({
    Value<String>? id,
    Value<String>? pageId,
    Value<ElementType>? type,
    Value<String>? data,
    Value<double>? x,
    Value<double>? y,
    Value<double>? width,
    Value<double>? height,
    Value<double>? scale,
    Value<double>? rotation,
    Value<int>? z,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CanvasElementsCompanion(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      type: type ?? this.type,
      data: data ?? this.data,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      z: z ?? this.z,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pageId.present) {
      map['page_id'] = Variable<String>(pageId.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $CanvasElementsTable.$convertertype.toSql(type.value),
      );
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (scale.present) {
      map['scale'] = Variable<double>(scale.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<double>(rotation.value);
    }
    if (z.present) {
      map['z'] = Variable<int>(z.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CanvasElementsCompanion(')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('type: $type, ')
          ..write('data: $data, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('scale: $scale, ')
          ..write('rotation: $rotation, ')
          ..write('z: $z, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssetsTable extends Assets with TableInfo<$AssetsTable, Asset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, path, mime, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Asset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Asset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Asset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AssetsTable createAlias(String alias) {
    return $AssetsTable(attachedDatabase, alias);
  }
}

class Asset extends DataClass implements Insertable<Asset> {
  final String id;
  final int kind;
  final String path;
  final String? mime;
  final DateTime createdAt;
  const Asset({
    required this.id,
    required this.kind,
    required this.path,
    this.mime,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<int>(kind);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AssetsCompanion toCompanion(bool nullToAbsent) {
    return AssetsCompanion(
      id: Value(id),
      kind: Value(kind),
      path: Value(path),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      createdAt: Value(createdAt),
    );
  }

  factory Asset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Asset(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<int>(json['kind']),
      path: serializer.fromJson<String>(json['path']),
      mime: serializer.fromJson<String?>(json['mime']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>(kind),
      'path': serializer.toJson<String>(path),
      'mime': serializer.toJson<String?>(mime),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Asset copyWith({
    String? id,
    int? kind,
    String? path,
    Value<String?> mime = const Value.absent(),
    DateTime? createdAt,
  }) => Asset(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    path: path ?? this.path,
    mime: mime.present ? mime.value : this.mime,
    createdAt: createdAt ?? this.createdAt,
  );
  Asset copyWithCompanion(AssetsCompanion data) {
    return Asset(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      path: data.path.present ? data.path.value : this.path,
      mime: data.mime.present ? data.mime.value : this.mime,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Asset(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, path, mime, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Asset &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.path == this.path &&
          other.mime == this.mime &&
          other.createdAt == this.createdAt);
}

class AssetsCompanion extends UpdateCompanion<Asset> {
  final Value<String> id;
  final Value<int> kind;
  final Value<String> path;
  final Value<String?> mime;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AssetsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.path = const Value.absent(),
    this.mime = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetsCompanion.insert({
    required String id,
    required int kind,
    required String path,
    this.mime = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       path = Value(path);
  static Insertable<Asset> custom({
    Expression<String>? id,
    Expression<int>? kind,
    Expression<String>? path,
    Expression<String>? mime,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (path != null) 'path': path,
      if (mime != null) 'mime': mime,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetsCompanion copyWith({
    Value<String>? id,
    Value<int>? kind,
    Value<String>? path,
    Value<String?>? mime,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AssetsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      mime: mime ?? this.mime,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $NotePagesTable notePages = $NotePagesTable(this);
  late final $StrokesTable strokes = $StrokesTable(this);
  late final $CanvasElementsTable canvasElements = $CanvasElementsTable(this);
  late final $AssetsTable assets = $AssetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    documents,
    notePages,
    strokes,
    canvasElements,
    assets,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('note_pages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'note_pages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('strokes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'note_pages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('canvas_elements', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      required String id,
      required DocumentType type,
      Value<String> title,
      Value<String?> parentId,
      Value<int> coverStyle,
      Value<PageOrientation> orientation,
      Value<PageSizePreset> pageSize,
      Value<bool> starred,
      Value<DateTime?> trashedAt,
      Value<int> sortIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<String> id,
      Value<DocumentType> type,
      Value<String> title,
      Value<String?> parentId,
      Value<int> coverStyle,
      Value<PageOrientation> orientation,
      Value<PageSizePreset> pageSize,
      Value<bool> starred,
      Value<DateTime?> trashedAt,
      Value<int> sortIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });

final class $$DocumentsTableReferences
    extends BaseReferences<_$AppDatabase, $DocumentsTable, Document> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NotePagesTable, List<NotePage>>
  _notePagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.notePages,
    aliasName: 'documents__id__note_pages__document_id',
  );

  $$NotePagesTableProcessedTableManager get notePagesRefs {
    final manager = $$NotePagesTableTableManager(
      $_db,
      $_db.notePages,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notePagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DocumentType, DocumentType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coverStyle => $composableBuilder(
    column: $table.coverStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PageOrientation, PageOrientation, int>
  get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PageSizePreset, PageSizePreset, int>
  get pageSize => $composableBuilder(
    column: $table.pageSize,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> notePagesRefs(
    Expression<bool> Function($$NotePagesTableFilterComposer f) f,
  ) {
    final $$NotePagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notePages,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePagesTableFilterComposer(
            $db: $db,
            $table: $db.notePages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coverStyle => $composableBuilder(
    column: $table.coverStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageSize => $composableBuilder(
    column: $table.pageSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get trashedAt => $composableBuilder(
    column: $table.trashedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DocumentType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get coverStyle => $composableBuilder(
    column: $table.coverStyle,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PageOrientation, int> get orientation =>
      $composableBuilder(
        column: $table.orientation,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<PageSizePreset, int> get pageSize =>
      $composableBuilder(column: $table.pageSize, builder: (column) => column);

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<DateTime> get trashedAt =>
      $composableBuilder(column: $table.trashedAt, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  Expression<T> notePagesRefs<T extends Object>(
    Expression<T> Function($$NotePagesTableAnnotationComposer a) f,
  ) {
    final $$NotePagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notePages,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePagesTableAnnotationComposer(
            $db: $db,
            $table: $db.notePages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, $$DocumentsTableReferences),
          Document,
          PrefetchHooks Function({bool notePagesRefs})
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DocumentType> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> coverStyle = const Value.absent(),
                Value<PageOrientation> orientation = const Value.absent(),
                Value<PageSizePreset> pageSize = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                type: type,
                title: title,
                parentId: parentId,
                coverStyle: coverStyle,
                orientation: orientation,
                pageSize: pageSize,
                starred: starred,
                trashedAt: trashedAt,
                sortIndex: sortIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DocumentType type,
                Value<String> title = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> coverStyle = const Value.absent(),
                Value<PageOrientation> orientation = const Value.absent(),
                Value<PageSizePreset> pageSize = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                type: type,
                title: title,
                parentId: parentId,
                coverStyle: coverStyle,
                orientation: orientation,
                pageSize: pageSize,
                starred: starred,
                trashedAt: trashedAt,
                sortIndex: sortIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({notePagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (notePagesRefs) db.notePages],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (notePagesRefs)
                    await $_getPrefetchedData<
                      Document,
                      $DocumentsTable,
                      NotePage
                    >(
                      currentTable: table,
                      referencedTable: $$DocumentsTableReferences
                          ._notePagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DocumentsTableReferences(
                            db,
                            table,
                            p0,
                          ).notePagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.documentId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, $$DocumentsTableReferences),
      Document,
      PrefetchHooks Function({bool notePagesRefs})
    >;
typedef $$NotePagesTableCreateCompanionBuilder =
    NotePagesCompanion Function({
      required String id,
      required String documentId,
      required int pageIndex,
      Value<PaperTemplate> template,
      Value<PaperColor> paperColor,
      Value<MarginSpec> marginSpec,
      Value<String?> pdfAssetId,
      Value<int?> pdfPageIndex,
      Value<String?> bookmarkTitle,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$NotePagesTableUpdateCompanionBuilder =
    NotePagesCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<int> pageIndex,
      Value<PaperTemplate> template,
      Value<PaperColor> paperColor,
      Value<MarginSpec> marginSpec,
      Value<String?> pdfAssetId,
      Value<int?> pdfPageIndex,
      Value<String?> bookmarkTitle,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$NotePagesTableReferences
    extends BaseReferences<_$AppDatabase, $NotePagesTable, NotePage> {
  $$NotePagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias('note_pages__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StrokesTable, List<Stroke>> _strokesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.strokes,
    aliasName: 'note_pages__id__strokes__page_id',
  );

  $$StrokesTableProcessedTableManager get strokesRefs {
    final manager = $$StrokesTableTableManager(
      $_db,
      $_db.strokes,
    ).filter((f) => f.pageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_strokesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CanvasElementsTable, List<CanvasElement>>
  _canvasElementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.canvasElements,
    aliasName: 'note_pages__id__canvas_elements__page_id',
  );

  $$CanvasElementsTableProcessedTableManager get canvasElementsRefs {
    final manager = $$CanvasElementsTableTableManager(
      $_db,
      $_db.canvasElements,
    ).filter((f) => f.pageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_canvasElementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotePagesTableFilterComposer
    extends Composer<_$AppDatabase, $NotePagesTable> {
  $$NotePagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PaperTemplate, PaperTemplate, int>
  get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PaperColor, PaperColor, int> get paperColor =>
      $composableBuilder(
        column: $table.paperColor,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<MarginSpec, MarginSpec, String>
  get marginSpec => $composableBuilder(
    column: $table.marginSpec,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get pdfAssetId => $composableBuilder(
    column: $table.pdfAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pdfPageIndex => $composableBuilder(
    column: $table.pdfPageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookmarkTitle => $composableBuilder(
    column: $table.bookmarkTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> strokesRefs(
    Expression<bool> Function($$StrokesTableFilterComposer f) f,
  ) {
    final $$StrokesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.strokes,
      getReferencedColumn: (t) => t.pageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StrokesTableFilterComposer(
            $db: $db,
            $table: $db.strokes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> canvasElementsRefs(
    Expression<bool> Function($$CanvasElementsTableFilterComposer f) f,
  ) {
    final $$CanvasElementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.canvasElements,
      getReferencedColumn: (t) => t.pageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CanvasElementsTableFilterComposer(
            $db: $db,
            $table: $db.canvasElements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotePagesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotePagesTable> {
  $$NotePagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paperColor => $composableBuilder(
    column: $table.paperColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get marginSpec => $composableBuilder(
    column: $table.marginSpec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfAssetId => $composableBuilder(
    column: $table.pdfAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pdfPageIndex => $composableBuilder(
    column: $table.pdfPageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookmarkTitle => $composableBuilder(
    column: $table.bookmarkTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotePagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotePagesTable> {
  $$NotePagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PaperTemplate, int> get template =>
      $composableBuilder(column: $table.template, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PaperColor, int> get paperColor =>
      $composableBuilder(
        column: $table.paperColor,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<MarginSpec, String> get marginSpec =>
      $composableBuilder(
        column: $table.marginSpec,
        builder: (column) => column,
      );

  GeneratedColumn<String> get pdfAssetId => $composableBuilder(
    column: $table.pdfAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pdfPageIndex => $composableBuilder(
    column: $table.pdfPageIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bookmarkTitle => $composableBuilder(
    column: $table.bookmarkTitle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> strokesRefs<T extends Object>(
    Expression<T> Function($$StrokesTableAnnotationComposer a) f,
  ) {
    final $$StrokesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.strokes,
      getReferencedColumn: (t) => t.pageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StrokesTableAnnotationComposer(
            $db: $db,
            $table: $db.strokes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> canvasElementsRefs<T extends Object>(
    Expression<T> Function($$CanvasElementsTableAnnotationComposer a) f,
  ) {
    final $$CanvasElementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.canvasElements,
      getReferencedColumn: (t) => t.pageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CanvasElementsTableAnnotationComposer(
            $db: $db,
            $table: $db.canvasElements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotePagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotePagesTable,
          NotePage,
          $$NotePagesTableFilterComposer,
          $$NotePagesTableOrderingComposer,
          $$NotePagesTableAnnotationComposer,
          $$NotePagesTableCreateCompanionBuilder,
          $$NotePagesTableUpdateCompanionBuilder,
          (NotePage, $$NotePagesTableReferences),
          NotePage,
          PrefetchHooks Function({
            bool documentId,
            bool strokesRefs,
            bool canvasElementsRefs,
          })
        > {
  $$NotePagesTableTableManager(_$AppDatabase db, $NotePagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotePagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotePagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotePagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<PaperTemplate> template = const Value.absent(),
                Value<PaperColor> paperColor = const Value.absent(),
                Value<MarginSpec> marginSpec = const Value.absent(),
                Value<String?> pdfAssetId = const Value.absent(),
                Value<int?> pdfPageIndex = const Value.absent(),
                Value<String?> bookmarkTitle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotePagesCompanion(
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                template: template,
                paperColor: paperColor,
                marginSpec: marginSpec,
                pdfAssetId: pdfAssetId,
                pdfPageIndex: pdfPageIndex,
                bookmarkTitle: bookmarkTitle,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                required int pageIndex,
                Value<PaperTemplate> template = const Value.absent(),
                Value<PaperColor> paperColor = const Value.absent(),
                Value<MarginSpec> marginSpec = const Value.absent(),
                Value<String?> pdfAssetId = const Value.absent(),
                Value<int?> pdfPageIndex = const Value.absent(),
                Value<String?> bookmarkTitle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotePagesCompanion.insert(
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                template: template,
                paperColor: paperColor,
                marginSpec: marginSpec,
                pdfAssetId: pdfAssetId,
                pdfPageIndex: pdfPageIndex,
                bookmarkTitle: bookmarkTitle,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NotePagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                documentId = false,
                strokesRefs = false,
                canvasElementsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (strokesRefs) db.strokes,
                    if (canvasElementsRefs) db.canvasElements,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (documentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.documentId,
                                    referencedTable: $$NotePagesTableReferences
                                        ._documentIdTable(db),
                                    referencedColumn: $$NotePagesTableReferences
                                        ._documentIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (strokesRefs)
                        await $_getPrefetchedData<
                          NotePage,
                          $NotePagesTable,
                          Stroke
                        >(
                          currentTable: table,
                          referencedTable: $$NotePagesTableReferences
                              ._strokesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotePagesTableReferences(
                                db,
                                table,
                                p0,
                              ).strokesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pageId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (canvasElementsRefs)
                        await $_getPrefetchedData<
                          NotePage,
                          $NotePagesTable,
                          CanvasElement
                        >(
                          currentTable: table,
                          referencedTable: $$NotePagesTableReferences
                              ._canvasElementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NotePagesTableReferences(
                                db,
                                table,
                                p0,
                              ).canvasElementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pageId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NotePagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotePagesTable,
      NotePage,
      $$NotePagesTableFilterComposer,
      $$NotePagesTableOrderingComposer,
      $$NotePagesTableAnnotationComposer,
      $$NotePagesTableCreateCompanionBuilder,
      $$NotePagesTableUpdateCompanionBuilder,
      (NotePage, $$NotePagesTableReferences),
      NotePage,
      PrefetchHooks Function({
        bool documentId,
        bool strokesRefs,
        bool canvasElementsRefs,
      })
    >;
typedef $$StrokesTableCreateCompanionBuilder =
    StrokesCompanion Function({
      required String id,
      required String pageId,
      required ToolType tool,
      required int color,
      required double width,
      Value<double> opacity,
      required Uint8List points,
      required double bboxL,
      required double bboxT,
      required double bboxR,
      required double bboxB,
      required int seq,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$StrokesTableUpdateCompanionBuilder =
    StrokesCompanion Function({
      Value<String> id,
      Value<String> pageId,
      Value<ToolType> tool,
      Value<int> color,
      Value<double> width,
      Value<double> opacity,
      Value<Uint8List> points,
      Value<double> bboxL,
      Value<double> bboxT,
      Value<double> bboxR,
      Value<double> bboxB,
      Value<int> seq,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$StrokesTableReferences
    extends BaseReferences<_$AppDatabase, $StrokesTable, Stroke> {
  $$StrokesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotePagesTable _pageIdTable(_$AppDatabase db) =>
      db.notePages.createAlias('strokes__page_id__note_pages__id');

  $$NotePagesTableProcessedTableManager get pageId {
    final $_column = $_itemColumn<String>('page_id')!;

    final manager = $$NotePagesTableTableManager(
      $_db,
      $_db.notePages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StrokesTableFilterComposer
    extends Composer<_$AppDatabase, $StrokesTable> {
  $$StrokesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ToolType, ToolType, int> get tool =>
      $composableBuilder(
        column: $table.tool,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get opacity => $composableBuilder(
    column: $table.opacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bboxL => $composableBuilder(
    column: $table.bboxL,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bboxT => $composableBuilder(
    column: $table.bboxT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bboxR => $composableBuilder(
    column: $table.bboxR,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bboxB => $composableBuilder(
    column: $table.bboxB,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NotePagesTableFilterComposer get pageId {
    final $$NotePagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.notePages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePagesTableFilterComposer(
            $db: $db,
            $table: $db.notePages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StrokesTableOrderingComposer
    extends Composer<_$AppDatabase, $StrokesTable> {
  $$StrokesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tool => $composableBuilder(
    column: $table.tool,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get opacity => $composableBuilder(
    column: $table.opacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bboxL => $composableBuilder(
    column: $table.bboxL,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bboxT => $composableBuilder(
    column: $table.bboxT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bboxR => $composableBuilder(
    column: $table.bboxR,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bboxB => $composableBuilder(
    column: $table.bboxB,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotePagesTableOrderingComposer get pageId {
    final $$NotePagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.notePages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePagesTableOrderingComposer(
            $db: $db,
            $table: $db.notePages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StrokesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StrokesTable> {
  $$StrokesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ToolType, int> get tool =>
      $composableBuilder(column: $table.tool, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get opacity =>
      $composableBuilder(column: $table.opacity, builder: (column) => column);

  GeneratedColumn<Uint8List> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<double> get bboxL =>
      $composableBuilder(column: $table.bboxL, builder: (column) => column);

  GeneratedColumn<double> get bboxT =>
      $composableBuilder(column: $table.bboxT, builder: (column) => column);

  GeneratedColumn<double> get bboxR =>
      $composableBuilder(column: $table.bboxR, builder: (column) => column);

  GeneratedColumn<double> get bboxB =>
      $composableBuilder(column: $table.bboxB, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$NotePagesTableAnnotationComposer get pageId {
    final $$NotePagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.notePages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePagesTableAnnotationComposer(
            $db: $db,
            $table: $db.notePages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StrokesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StrokesTable,
          Stroke,
          $$StrokesTableFilterComposer,
          $$StrokesTableOrderingComposer,
          $$StrokesTableAnnotationComposer,
          $$StrokesTableCreateCompanionBuilder,
          $$StrokesTableUpdateCompanionBuilder,
          (Stroke, $$StrokesTableReferences),
          Stroke,
          PrefetchHooks Function({bool pageId})
        > {
  $$StrokesTableTableManager(_$AppDatabase db, $StrokesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StrokesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StrokesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StrokesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pageId = const Value.absent(),
                Value<ToolType> tool = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> opacity = const Value.absent(),
                Value<Uint8List> points = const Value.absent(),
                Value<double> bboxL = const Value.absent(),
                Value<double> bboxT = const Value.absent(),
                Value<double> bboxR = const Value.absent(),
                Value<double> bboxB = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StrokesCompanion(
                id: id,
                pageId: pageId,
                tool: tool,
                color: color,
                width: width,
                opacity: opacity,
                points: points,
                bboxL: bboxL,
                bboxT: bboxT,
                bboxR: bboxR,
                bboxB: bboxB,
                seq: seq,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String pageId,
                required ToolType tool,
                required int color,
                required double width,
                Value<double> opacity = const Value.absent(),
                required Uint8List points,
                required double bboxL,
                required double bboxT,
                required double bboxR,
                required double bboxB,
                required int seq,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StrokesCompanion.insert(
                id: id,
                pageId: pageId,
                tool: tool,
                color: color,
                width: width,
                opacity: opacity,
                points: points,
                bboxL: bboxL,
                bboxT: bboxT,
                bboxR: bboxR,
                bboxB: bboxB,
                seq: seq,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StrokesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (pageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.pageId,
                                referencedTable: $$StrokesTableReferences
                                    ._pageIdTable(db),
                                referencedColumn: $$StrokesTableReferences
                                    ._pageIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StrokesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StrokesTable,
      Stroke,
      $$StrokesTableFilterComposer,
      $$StrokesTableOrderingComposer,
      $$StrokesTableAnnotationComposer,
      $$StrokesTableCreateCompanionBuilder,
      $$StrokesTableUpdateCompanionBuilder,
      (Stroke, $$StrokesTableReferences),
      Stroke,
      PrefetchHooks Function({bool pageId})
    >;
typedef $$CanvasElementsTableCreateCompanionBuilder =
    CanvasElementsCompanion Function({
      required String id,
      required String pageId,
      required ElementType type,
      required String data,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<double> height,
      Value<double> scale,
      Value<double> rotation,
      Value<int> z,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CanvasElementsTableUpdateCompanionBuilder =
    CanvasElementsCompanion Function({
      Value<String> id,
      Value<String> pageId,
      Value<ElementType> type,
      Value<String> data,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<double> height,
      Value<double> scale,
      Value<double> rotation,
      Value<int> z,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CanvasElementsTableReferences
    extends BaseReferences<_$AppDatabase, $CanvasElementsTable, CanvasElement> {
  $$CanvasElementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NotePagesTable _pageIdTable(_$AppDatabase db) =>
      db.notePages.createAlias('canvas_elements__page_id__note_pages__id');

  $$NotePagesTableProcessedTableManager get pageId {
    final $_column = $_itemColumn<String>('page_id')!;

    final manager = $$NotePagesTableTableManager(
      $_db,
      $_db.notePages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CanvasElementsTableFilterComposer
    extends Composer<_$AppDatabase, $CanvasElementsTable> {
  $$CanvasElementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ElementType, ElementType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scale => $composableBuilder(
    column: $table.scale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get z => $composableBuilder(
    column: $table.z,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NotePagesTableFilterComposer get pageId {
    final $$NotePagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.notePages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePagesTableFilterComposer(
            $db: $db,
            $table: $db.notePages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CanvasElementsTableOrderingComposer
    extends Composer<_$AppDatabase, $CanvasElementsTable> {
  $$CanvasElementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scale => $composableBuilder(
    column: $table.scale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get z => $composableBuilder(
    column: $table.z,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotePagesTableOrderingComposer get pageId {
    final $$NotePagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.notePages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePagesTableOrderingComposer(
            $db: $db,
            $table: $db.notePages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CanvasElementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CanvasElementsTable> {
  $$CanvasElementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ElementType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get scale =>
      $composableBuilder(column: $table.scale, builder: (column) => column);

  GeneratedColumn<double> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<int> get z =>
      $composableBuilder(column: $table.z, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$NotePagesTableAnnotationComposer get pageId {
    final $$NotePagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pageId,
      referencedTable: $db.notePages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotePagesTableAnnotationComposer(
            $db: $db,
            $table: $db.notePages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CanvasElementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CanvasElementsTable,
          CanvasElement,
          $$CanvasElementsTableFilterComposer,
          $$CanvasElementsTableOrderingComposer,
          $$CanvasElementsTableAnnotationComposer,
          $$CanvasElementsTableCreateCompanionBuilder,
          $$CanvasElementsTableUpdateCompanionBuilder,
          (CanvasElement, $$CanvasElementsTableReferences),
          CanvasElement,
          PrefetchHooks Function({bool pageId})
        > {
  $$CanvasElementsTableTableManager(
    _$AppDatabase db,
    $CanvasElementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CanvasElementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CanvasElementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CanvasElementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> pageId = const Value.absent(),
                Value<ElementType> type = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> scale = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<int> z = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CanvasElementsCompanion(
                id: id,
                pageId: pageId,
                type: type,
                data: data,
                x: x,
                y: y,
                width: width,
                height: height,
                scale: scale,
                rotation: rotation,
                z: z,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String pageId,
                required ElementType type,
                required String data,
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> scale = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<int> z = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CanvasElementsCompanion.insert(
                id: id,
                pageId: pageId,
                type: type,
                data: data,
                x: x,
                y: y,
                width: width,
                height: height,
                scale: scale,
                rotation: rotation,
                z: z,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CanvasElementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (pageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.pageId,
                                referencedTable: $$CanvasElementsTableReferences
                                    ._pageIdTable(db),
                                referencedColumn:
                                    $$CanvasElementsTableReferences
                                        ._pageIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CanvasElementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CanvasElementsTable,
      CanvasElement,
      $$CanvasElementsTableFilterComposer,
      $$CanvasElementsTableOrderingComposer,
      $$CanvasElementsTableAnnotationComposer,
      $$CanvasElementsTableCreateCompanionBuilder,
      $$CanvasElementsTableUpdateCompanionBuilder,
      (CanvasElement, $$CanvasElementsTableReferences),
      CanvasElement,
      PrefetchHooks Function({bool pageId})
    >;
typedef $$AssetsTableCreateCompanionBuilder =
    AssetsCompanion Function({
      required String id,
      required int kind,
      required String path,
      Value<String?> mime,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$AssetsTableUpdateCompanionBuilder =
    AssetsCompanion Function({
      Value<String> id,
      Value<int> kind,
      Value<String> path,
      Value<String?> mime,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AssetsTableFilterComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetsTable> {
  $$AssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssetsTable,
          Asset,
          $$AssetsTableFilterComposer,
          $$AssetsTableOrderingComposer,
          $$AssetsTableAnnotationComposer,
          $$AssetsTableCreateCompanionBuilder,
          $$AssetsTableUpdateCompanionBuilder,
          (Asset, BaseReferences<_$AppDatabase, $AssetsTable, Asset>),
          Asset,
          PrefetchHooks Function()
        > {
  $$AssetsTableTableManager(_$AppDatabase db, $AssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetsCompanion(
                id: id,
                kind: kind,
                path: path,
                mime: mime,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int kind,
                required String path,
                Value<String?> mime = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetsCompanion.insert(
                id: id,
                kind: kind,
                path: path,
                mime: mime,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssetsTable,
      Asset,
      $$AssetsTableFilterComposer,
      $$AssetsTableOrderingComposer,
      $$AssetsTableAnnotationComposer,
      $$AssetsTableCreateCompanionBuilder,
      $$AssetsTableUpdateCompanionBuilder,
      (Asset, BaseReferences<_$AppDatabase, $AssetsTable, Asset>),
      Asset,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$NotePagesTableTableManager get notePages =>
      $$NotePagesTableTableManager(_db, _db.notePages);
  $$StrokesTableTableManager get strokes =>
      $$StrokesTableTableManager(_db, _db.strokes);
  $$CanvasElementsTableTableManager get canvasElements =>
      $$CanvasElementsTableTableManager(_db, _db.canvasElements);
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db, _db.assets);
}
