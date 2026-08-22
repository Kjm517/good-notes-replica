// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
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
  static const VerificationMeta _ownerUidMeta = const VerificationMeta(
    'ownerUid',
  );
  @override
  late final GeneratedColumn<String> ownerUid = GeneratedColumn<String>(
    'owner_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverThumbMeta = const VerificationMeta(
    'coverThumb',
  );
  @override
  late final GeneratedColumn<String> coverThumb = GeneratedColumn<String>(
    'cover_thumb',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outlineMeta = const VerificationMeta(
    'outline',
  );
  @override
  late final GeneratedColumn<String> outline = GeneratedColumn<String>(
    'outline',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    type,
    title,
    parentId,
    coverStyle,
    orientation,
    pageSize,
    starred,
    ownerUid,
    coverThumb,
    outline,
    trashedAt,
    sortIndex,
    createdAt,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
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
    if (data.containsKey('owner_uid')) {
      context.handle(
        _ownerUidMeta,
        ownerUid.isAcceptableOrUnknown(data['owner_uid']!, _ownerUidMeta),
      );
    }
    if (data.containsKey('cover_thumb')) {
      context.handle(
        _coverThumbMeta,
        coverThumb.isAcceptableOrUnknown(data['cover_thumb']!, _coverThumbMeta),
      );
    }
    if (data.containsKey('outline')) {
      context.handle(
        _outlineMeta,
        outline.isAcceptableOrUnknown(data['outline']!, _outlineMeta),
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
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
      ownerUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_uid'],
      ),
      coverThumb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_thumb'],
      ),
      outline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outline'],
      ),
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
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final DateTime? remoteUpdatedAt;
  final String id;
  final DocumentType type;
  final String title;
  final String? parentId;

  /// Index into the built-in cover palette (notebooks only).
  final int coverStyle;
  final PageOrientation orientation;
  final PageSizePreset pageSize;
  final bool starred;

  /// Firebase uid of the account this belongs to.
  ///
  /// Null means "created on this device while signed out" — those stay
  /// visible to everyone and are claimed by the first account that signs in.
  /// Anything owned by an account is hidden unless that account is signed in;
  /// otherwise signing out would leave one user's notes on screen for the
  /// next person to open the app.
  final String? ownerUid;

  /// Small base64 PNG of the first page, rendered once at import.
  ///
  /// Without this the library has to open the whole source PDF just to draw a
  /// card-sized preview — a 150 MB textbook took over 20 seconds.
  final String? coverThumb;

  /// The PDF's embedded table of contents as a JSON list of [OutlineEntry].
  ///
  /// Extracted once in the background (alongside search-text indexing) so the
  /// outline sidebar can jump to sections like a browser PDF viewer. Null means
  /// "not extracted yet"; an empty list means the PDF genuinely has no outline.
  /// Derived data, so it isn't synced — each device regenerates it locally.
  final String? outline;

  /// Null unless soft-deleted (in trash).
  final DateTime? trashedAt;

  /// Manual ordering within a folder.
  final int sortIndex;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;
  const Document({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    this.remoteUpdatedAt,
    required this.id,
    required this.type,
    required this.title,
    this.parentId,
    required this.coverStyle,
    required this.orientation,
    required this.pageSize,
    required this.starred,
    this.ownerUid,
    this.coverThumb,
    this.outline,
    this.trashedAt,
    required this.sortIndex,
    required this.createdAt,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
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
    if (!nullToAbsent || ownerUid != null) {
      map['owner_uid'] = Variable<String>(ownerUid);
    }
    if (!nullToAbsent || coverThumb != null) {
      map['cover_thumb'] = Variable<String>(coverThumb);
    }
    if (!nullToAbsent || outline != null) {
      map['outline'] = Variable<String>(outline);
    }
    if (!nullToAbsent || trashedAt != null) {
      map['trashed_at'] = Variable<DateTime>(trashedAt);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
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
      ownerUid: ownerUid == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUid),
      coverThumb: coverThumb == null && nullToAbsent
          ? const Value.absent()
          : Value(coverThumb),
      outline: outline == null && nullToAbsent
          ? const Value.absent()
          : Value(outline),
      trashedAt: trashedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(trashedAt),
      sortIndex: Value(sortIndex),
      createdAt: Value(createdAt),
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
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
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
      ownerUid: serializer.fromJson<String?>(json['ownerUid']),
      coverThumb: serializer.fromJson<String?>(json['coverThumb']),
      outline: serializer.fromJson<String?>(json['outline']),
      trashedAt: serializer.fromJson<DateTime?>(json['trashedAt']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
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
      'ownerUid': serializer.toJson<String?>(ownerUid),
      'coverThumb': serializer.toJson<String?>(coverThumb),
      'outline': serializer.toJson<String?>(outline),
      'trashedAt': serializer.toJson<DateTime?>(trashedAt),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
    };
  }

  Document copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? id,
    DocumentType? type,
    String? title,
    Value<String?> parentId = const Value.absent(),
    int? coverStyle,
    PageOrientation? orientation,
    PageSizePreset? pageSize,
    bool? starred,
    Value<String?> ownerUid = const Value.absent(),
    Value<String?> coverThumb = const Value.absent(),
    Value<String?> outline = const Value.absent(),
    Value<DateTime?> trashedAt = const Value.absent(),
    int? sortIndex,
    DateTime? createdAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
  }) => Document(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    parentId: parentId.present ? parentId.value : this.parentId,
    coverStyle: coverStyle ?? this.coverStyle,
    orientation: orientation ?? this.orientation,
    pageSize: pageSize ?? this.pageSize,
    starred: starred ?? this.starred,
    ownerUid: ownerUid.present ? ownerUid.value : this.ownerUid,
    coverThumb: coverThumb.present ? coverThumb.value : this.coverThumb,
    outline: outline.present ? outline.value : this.outline,
    trashedAt: trashedAt.present ? trashedAt.value : this.trashedAt,
    sortIndex: sortIndex ?? this.sortIndex,
    createdAt: createdAt ?? this.createdAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
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
      ownerUid: data.ownerUid.present ? data.ownerUid.value : this.ownerUid,
      coverThumb: data.coverThumb.present
          ? data.coverThumb.value
          : this.coverThumb,
      outline: data.outline.present ? data.outline.value : this.outline,
      trashedAt: data.trashedAt.present ? data.trashedAt.value : this.trashedAt,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('parentId: $parentId, ')
          ..write('coverStyle: $coverStyle, ')
          ..write('orientation: $orientation, ')
          ..write('pageSize: $pageSize, ')
          ..write('starred: $starred, ')
          ..write('ownerUid: $ownerUid, ')
          ..write('coverThumb: $coverThumb, ')
          ..write('outline: $outline, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    type,
    title,
    parentId,
    coverStyle,
    orientation,
    pageSize,
    starred,
    ownerUid,
    coverThumb,
    outline,
    trashedAt,
    sortIndex,
    createdAt,
    lastOpenedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.parentId == this.parentId &&
          other.coverStyle == this.coverStyle &&
          other.orientation == this.orientation &&
          other.pageSize == this.pageSize &&
          other.starred == this.starred &&
          other.ownerUid == this.ownerUid &&
          other.coverThumb == this.coverThumb &&
          other.outline == this.outline &&
          other.trashedAt == this.trashedAt &&
          other.sortIndex == this.sortIndex &&
          other.createdAt == this.createdAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> id;
  final Value<DocumentType> type;
  final Value<String> title;
  final Value<String?> parentId;
  final Value<int> coverStyle;
  final Value<PageOrientation> orientation;
  final Value<PageSizePreset> pageSize;
  final Value<bool> starred;
  final Value<String?> ownerUid;
  final Value<String?> coverThumb;
  final Value<String?> outline;
  final Value<DateTime?> trashedAt;
  final Value<int> sortIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.parentId = const Value.absent(),
    this.coverStyle = const Value.absent(),
    this.orientation = const Value.absent(),
    this.pageSize = const Value.absent(),
    this.starred = const Value.absent(),
    this.ownerUid = const Value.absent(),
    this.coverThumb = const Value.absent(),
    this.outline = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String id,
    required DocumentType type,
    this.title = const Value.absent(),
    this.parentId = const Value.absent(),
    this.coverStyle = const Value.absent(),
    this.orientation = const Value.absent(),
    this.pageSize = const Value.absent(),
    this.starred = const Value.absent(),
    this.ownerUid = const Value.absent(),
    this.coverThumb = const Value.absent(),
    this.outline = const Value.absent(),
    this.trashedAt = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type);
  static Insertable<Document> custom({
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? id,
    Expression<int>? type,
    Expression<String>? title,
    Expression<String>? parentId,
    Expression<int>? coverStyle,
    Expression<int>? orientation,
    Expression<int>? pageSize,
    Expression<bool>? starred,
    Expression<String>? ownerUid,
    Expression<String>? coverThumb,
    Expression<String>? outline,
    Expression<DateTime>? trashedAt,
    Expression<int>? sortIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (parentId != null) 'parent_id': parentId,
      if (coverStyle != null) 'cover_style': coverStyle,
      if (orientation != null) 'orientation': orientation,
      if (pageSize != null) 'page_size': pageSize,
      if (starred != null) 'starred': starred,
      if (ownerUid != null) 'owner_uid': ownerUid,
      if (coverThumb != null) 'cover_thumb': coverThumb,
      if (outline != null) 'outline': outline,
      if (trashedAt != null) 'trashed_at': trashedAt,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? id,
    Value<DocumentType>? type,
    Value<String>? title,
    Value<String?>? parentId,
    Value<int>? coverStyle,
    Value<PageOrientation>? orientation,
    Value<PageSizePreset>? pageSize,
    Value<bool>? starred,
    Value<String?>? ownerUid,
    Value<String?>? coverThumb,
    Value<String?>? outline,
    Value<DateTime?>? trashedAt,
    Value<int>? sortIndex,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      parentId: parentId ?? this.parentId,
      coverStyle: coverStyle ?? this.coverStyle,
      orientation: orientation ?? this.orientation,
      pageSize: pageSize ?? this.pageSize,
      starred: starred ?? this.starred,
      ownerUid: ownerUid ?? this.ownerUid,
      coverThumb: coverThumb ?? this.coverThumb,
      outline: outline ?? this.outline,
      trashedAt: trashedAt ?? this.trashedAt,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
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
    if (ownerUid.present) {
      map['owner_uid'] = Variable<String>(ownerUid.value);
    }
    if (coverThumb.present) {
      map['cover_thumb'] = Variable<String>(coverThumb.value);
    }
    if (outline.present) {
      map['outline'] = Variable<String>(outline.value);
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
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('parentId: $parentId, ')
          ..write('coverStyle: $coverStyle, ')
          ..write('orientation: $orientation, ')
          ..write('pageSize: $pageSize, ')
          ..write('starred: $starred, ')
          ..write('ownerUid: $ownerUid, ')
          ..write('coverThumb: $coverThumb, ')
          ..write('outline: $outline, ')
          ..write('trashedAt: $trashedAt, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
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
  static const VerificationMeta _bgAssetIdMeta = const VerificationMeta(
    'bgAssetId',
  );
  @override
  late final GeneratedColumn<String> bgAssetId = GeneratedColumn<String>(
    'bg_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageWMeta = const VerificationMeta('pageW');
  @override
  late final GeneratedColumn<double> pageW = GeneratedColumn<double>(
    'page_w',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageHMeta = const VerificationMeta('pageH');
  @override
  late final GeneratedColumn<double> pageH = GeneratedColumn<double>(
    'page_h',
    aliasedName,
    true,
    type: DriftSqlType.double,
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
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
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
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    documentId,
    pageIndex,
    template,
    paperColor,
    marginSpec,
    pdfAssetId,
    pdfPageIndex,
    bgAssetId,
    pageW,
    pageH,
    bookmarkTitle,
    searchText,
    createdAt,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
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
    if (data.containsKey('bg_asset_id')) {
      context.handle(
        _bgAssetIdMeta,
        bgAssetId.isAcceptableOrUnknown(data['bg_asset_id']!, _bgAssetIdMeta),
      );
    }
    if (data.containsKey('page_w')) {
      context.handle(
        _pageWMeta,
        pageW.isAcceptableOrUnknown(data['page_w']!, _pageWMeta),
      );
    }
    if (data.containsKey('page_h')) {
      context.handle(
        _pageHMeta,
        pageH.isAcceptableOrUnknown(data['page_h']!, _pageHMeta),
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
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
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
  NotePage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotePage(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
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
      bgAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bg_asset_id'],
      ),
      pageW: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}page_w'],
      ),
      pageH: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}page_h'],
      ),
      bookmarkTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bookmark_title'],
      ),
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
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
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final DateTime? remoteUpdatedAt;
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

  /// For image-backed pages: the source image asset.
  final String? bgAssetId;

  /// Per-page size override (points) for PDF/image pages whose dimensions
  /// differ from the document preset. Null = use the document preset size.
  final double? pageW;
  final double? pageH;
  final String? bookmarkTitle;

  /// Text extracted from the source PDF page, lower-cased for searching.
  ///
  /// Extracted once (in the background after import) so "find in document"
  /// never has to re-parse the file. Null means not extracted yet; empty
  /// means the page genuinely has no text (a scan, or a picture page).
  final String? searchText;
  final DateTime createdAt;
  const NotePage({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    this.remoteUpdatedAt,
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.template,
    required this.paperColor,
    required this.marginSpec,
    this.pdfAssetId,
    this.pdfPageIndex,
    this.bgAssetId,
    this.pageW,
    this.pageH,
    this.bookmarkTitle,
    this.searchText,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
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
    if (!nullToAbsent || bgAssetId != null) {
      map['bg_asset_id'] = Variable<String>(bgAssetId);
    }
    if (!nullToAbsent || pageW != null) {
      map['page_w'] = Variable<double>(pageW);
    }
    if (!nullToAbsent || pageH != null) {
      map['page_h'] = Variable<double>(pageH);
    }
    if (!nullToAbsent || bookmarkTitle != null) {
      map['bookmark_title'] = Variable<String>(bookmarkTitle);
    }
    if (!nullToAbsent || searchText != null) {
      map['search_text'] = Variable<String>(searchText);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NotePagesCompanion toCompanion(bool nullToAbsent) {
    return NotePagesCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
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
      bgAssetId: bgAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(bgAssetId),
      pageW: pageW == null && nullToAbsent
          ? const Value.absent()
          : Value(pageW),
      pageH: pageH == null && nullToAbsent
          ? const Value.absent()
          : Value(pageH),
      bookmarkTitle: bookmarkTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(bookmarkTitle),
      searchText: searchText == null && nullToAbsent
          ? const Value.absent()
          : Value(searchText),
      createdAt: Value(createdAt),
    );
  }

  factory NotePage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotePage(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
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
      bgAssetId: serializer.fromJson<String?>(json['bgAssetId']),
      pageW: serializer.fromJson<double?>(json['pageW']),
      pageH: serializer.fromJson<double?>(json['pageH']),
      bookmarkTitle: serializer.fromJson<String?>(json['bookmarkTitle']),
      searchText: serializer.fromJson<String?>(json['searchText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
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
      'bgAssetId': serializer.toJson<String?>(bgAssetId),
      'pageW': serializer.toJson<double?>(pageW),
      'pageH': serializer.toJson<double?>(pageH),
      'bookmarkTitle': serializer.toJson<String?>(bookmarkTitle),
      'searchText': serializer.toJson<String?>(searchText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  NotePage copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? id,
    String? documentId,
    int? pageIndex,
    PaperTemplate? template,
    PaperColor? paperColor,
    MarginSpec? marginSpec,
    Value<String?> pdfAssetId = const Value.absent(),
    Value<int?> pdfPageIndex = const Value.absent(),
    Value<String?> bgAssetId = const Value.absent(),
    Value<double?> pageW = const Value.absent(),
    Value<double?> pageH = const Value.absent(),
    Value<String?> bookmarkTitle = const Value.absent(),
    Value<String?> searchText = const Value.absent(),
    DateTime? createdAt,
  }) => NotePage(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    pageIndex: pageIndex ?? this.pageIndex,
    template: template ?? this.template,
    paperColor: paperColor ?? this.paperColor,
    marginSpec: marginSpec ?? this.marginSpec,
    pdfAssetId: pdfAssetId.present ? pdfAssetId.value : this.pdfAssetId,
    pdfPageIndex: pdfPageIndex.present ? pdfPageIndex.value : this.pdfPageIndex,
    bgAssetId: bgAssetId.present ? bgAssetId.value : this.bgAssetId,
    pageW: pageW.present ? pageW.value : this.pageW,
    pageH: pageH.present ? pageH.value : this.pageH,
    bookmarkTitle: bookmarkTitle.present
        ? bookmarkTitle.value
        : this.bookmarkTitle,
    searchText: searchText.present ? searchText.value : this.searchText,
    createdAt: createdAt ?? this.createdAt,
  );
  NotePage copyWithCompanion(NotePagesCompanion data) {
    return NotePage(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
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
      bgAssetId: data.bgAssetId.present ? data.bgAssetId.value : this.bgAssetId,
      pageW: data.pageW.present ? data.pageW.value : this.pageW,
      pageH: data.pageH.present ? data.pageH.value : this.pageH,
      bookmarkTitle: data.bookmarkTitle.present
          ? data.bookmarkTitle.value
          : this.bookmarkTitle,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotePage(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('template: $template, ')
          ..write('paperColor: $paperColor, ')
          ..write('marginSpec: $marginSpec, ')
          ..write('pdfAssetId: $pdfAssetId, ')
          ..write('pdfPageIndex: $pdfPageIndex, ')
          ..write('bgAssetId: $bgAssetId, ')
          ..write('pageW: $pageW, ')
          ..write('pageH: $pageH, ')
          ..write('bookmarkTitle: $bookmarkTitle, ')
          ..write('searchText: $searchText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    documentId,
    pageIndex,
    template,
    paperColor,
    marginSpec,
    pdfAssetId,
    pdfPageIndex,
    bgAssetId,
    pageW,
    pageH,
    bookmarkTitle,
    searchText,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotePage &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.pageIndex == this.pageIndex &&
          other.template == this.template &&
          other.paperColor == this.paperColor &&
          other.marginSpec == this.marginSpec &&
          other.pdfAssetId == this.pdfAssetId &&
          other.pdfPageIndex == this.pdfPageIndex &&
          other.bgAssetId == this.bgAssetId &&
          other.pageW == this.pageW &&
          other.pageH == this.pageH &&
          other.bookmarkTitle == this.bookmarkTitle &&
          other.searchText == this.searchText &&
          other.createdAt == this.createdAt);
}

class NotePagesCompanion extends UpdateCompanion<NotePage> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> id;
  final Value<String> documentId;
  final Value<int> pageIndex;
  final Value<PaperTemplate> template;
  final Value<PaperColor> paperColor;
  final Value<MarginSpec> marginSpec;
  final Value<String?> pdfAssetId;
  final Value<int?> pdfPageIndex;
  final Value<String?> bgAssetId;
  final Value<double?> pageW;
  final Value<double?> pageH;
  final Value<String?> bookmarkTitle;
  final Value<String?> searchText;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const NotePagesCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.template = const Value.absent(),
    this.paperColor = const Value.absent(),
    this.marginSpec = const Value.absent(),
    this.pdfAssetId = const Value.absent(),
    this.pdfPageIndex = const Value.absent(),
    this.bgAssetId = const Value.absent(),
    this.pageW = const Value.absent(),
    this.pageH = const Value.absent(),
    this.bookmarkTitle = const Value.absent(),
    this.searchText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotePagesCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String id,
    required String documentId,
    required int pageIndex,
    this.template = const Value.absent(),
    this.paperColor = const Value.absent(),
    this.marginSpec = const Value.absent(),
    this.pdfAssetId = const Value.absent(),
    this.pdfPageIndex = const Value.absent(),
    this.bgAssetId = const Value.absent(),
    this.pageW = const Value.absent(),
    this.pageH = const Value.absent(),
    this.bookmarkTitle = const Value.absent(),
    this.searchText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       pageIndex = Value(pageIndex);
  static Insertable<NotePage> custom({
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<int>? pageIndex,
    Expression<int>? template,
    Expression<int>? paperColor,
    Expression<String>? marginSpec,
    Expression<String>? pdfAssetId,
    Expression<int>? pdfPageIndex,
    Expression<String>? bgAssetId,
    Expression<double>? pageW,
    Expression<double>? pageH,
    Expression<String>? bookmarkTitle,
    Expression<String>? searchText,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (template != null) 'template': template,
      if (paperColor != null) 'paper_color': paperColor,
      if (marginSpec != null) 'margin_spec': marginSpec,
      if (pdfAssetId != null) 'pdf_asset_id': pdfAssetId,
      if (pdfPageIndex != null) 'pdf_page_index': pdfPageIndex,
      if (bgAssetId != null) 'bg_asset_id': bgAssetId,
      if (pageW != null) 'page_w': pageW,
      if (pageH != null) 'page_h': pageH,
      if (bookmarkTitle != null) 'bookmark_title': bookmarkTitle,
      if (searchText != null) 'search_text': searchText,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotePagesCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? id,
    Value<String>? documentId,
    Value<int>? pageIndex,
    Value<PaperTemplate>? template,
    Value<PaperColor>? paperColor,
    Value<MarginSpec>? marginSpec,
    Value<String?>? pdfAssetId,
    Value<int?>? pdfPageIndex,
    Value<String?>? bgAssetId,
    Value<double?>? pageW,
    Value<double?>? pageH,
    Value<String?>? bookmarkTitle,
    Value<String?>? searchText,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return NotePagesCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      template: template ?? this.template,
      paperColor: paperColor ?? this.paperColor,
      marginSpec: marginSpec ?? this.marginSpec,
      pdfAssetId: pdfAssetId ?? this.pdfAssetId,
      pdfPageIndex: pdfPageIndex ?? this.pdfPageIndex,
      bgAssetId: bgAssetId ?? this.bgAssetId,
      pageW: pageW ?? this.pageW,
      pageH: pageH ?? this.pageH,
      bookmarkTitle: bookmarkTitle ?? this.bookmarkTitle,
      searchText: searchText ?? this.searchText,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
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
    if (bgAssetId.present) {
      map['bg_asset_id'] = Variable<String>(bgAssetId.value);
    }
    if (pageW.present) {
      map['page_w'] = Variable<double>(pageW.value);
    }
    if (pageH.present) {
      map['page_h'] = Variable<double>(pageH.value);
    }
    if (bookmarkTitle.present) {
      map['bookmark_title'] = Variable<String>(bookmarkTitle.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
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
    return (StringBuffer('NotePagesCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('template: $template, ')
          ..write('paperColor: $paperColor, ')
          ..write('marginSpec: $marginSpec, ')
          ..write('pdfAssetId: $pdfAssetId, ')
          ..write('pdfPageIndex: $pdfPageIndex, ')
          ..write('bgAssetId: $bgAssetId, ')
          ..write('pageW: $pageW, ')
          ..write('pageH: $pageH, ')
          ..write('bookmarkTitle: $bookmarkTitle, ')
          ..write('searchText: $searchText, ')
          ..write('createdAt: $createdAt, ')
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
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
  @override
  late final GeneratedColumnWithTypeConverter<StrokeStyle, int> style =
      GeneratedColumn<int>(
        'style',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<StrokeStyle>($StrokesTable.$converterstyle);
  static const VerificationMeta _filledMeta = const VerificationMeta('filled');
  @override
  late final GeneratedColumn<bool> filled = GeneratedColumn<bool>(
    'filled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("filled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<StrokeTip, int> tip =
      GeneratedColumn<int>(
        'tip',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<StrokeTip>($StrokesTable.$convertertip);
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
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    pageId,
    tool,
    color,
    width,
    opacity,
    points,
    style,
    filled,
    tip,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
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
    if (data.containsKey('filled')) {
      context.handle(
        _filledMeta,
        filled.isAcceptableOrUnknown(data['filled']!, _filledMeta),
      );
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
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
      style: $StrokesTable.$converterstyle.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}style'],
        )!,
      ),
      filled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}filled'],
      )!,
      tip: $StrokesTable.$convertertip.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}tip'],
        )!,
      ),
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
  static JsonTypeConverter2<StrokeStyle, int, int> $converterstyle =
      const EnumIndexConverter<StrokeStyle>(StrokeStyle.values);
  static JsonTypeConverter2<StrokeTip, int, int> $convertertip =
      const EnumIndexConverter<StrokeTip>(StrokeTip.values);
}

class Stroke extends DataClass implements Insertable<Stroke> {
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final DateTime? remoteUpdatedAt;
  final String id;
  final String pageId;
  final ToolType tool;

  /// ARGB colour.
  final int color;
  final double width;
  final double opacity;
  final Uint8List points;

  /// Solid / dashed / dotted line style.
  final StrokeStyle style;

  /// Shapes only: fill the closed outline with the stroke colour.
  final bool filled;

  /// Nib shape: round or square (chisel). Mainly for highlighter and tape.
  final StrokeTip tip;
  final double bboxL;
  final double bboxT;
  final double bboxR;
  final double bboxB;

  /// Draw order within the page.
  final int seq;
  final DateTime createdAt;
  const Stroke({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    this.remoteUpdatedAt,
    required this.id,
    required this.pageId,
    required this.tool,
    required this.color,
    required this.width,
    required this.opacity,
    required this.points,
    required this.style,
    required this.filled,
    required this.tip,
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
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['id'] = Variable<String>(id);
    map['page_id'] = Variable<String>(pageId);
    {
      map['tool'] = Variable<int>($StrokesTable.$convertertool.toSql(tool));
    }
    map['color'] = Variable<int>(color);
    map['width'] = Variable<double>(width);
    map['opacity'] = Variable<double>(opacity);
    map['points'] = Variable<Uint8List>(points);
    {
      map['style'] = Variable<int>($StrokesTable.$converterstyle.toSql(style));
    }
    map['filled'] = Variable<bool>(filled);
    {
      map['tip'] = Variable<int>($StrokesTable.$convertertip.toSql(tip));
    }
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
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      id: Value(id),
      pageId: Value(pageId),
      tool: Value(tool),
      color: Value(color),
      width: Value(width),
      opacity: Value(opacity),
      points: Value(points),
      style: Value(style),
      filled: Value(filled),
      tip: Value(tip),
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
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      id: serializer.fromJson<String>(json['id']),
      pageId: serializer.fromJson<String>(json['pageId']),
      tool: $StrokesTable.$convertertool.fromJson(
        serializer.fromJson<int>(json['tool']),
      ),
      color: serializer.fromJson<int>(json['color']),
      width: serializer.fromJson<double>(json['width']),
      opacity: serializer.fromJson<double>(json['opacity']),
      points: serializer.fromJson<Uint8List>(json['points']),
      style: $StrokesTable.$converterstyle.fromJson(
        serializer.fromJson<int>(json['style']),
      ),
      filled: serializer.fromJson<bool>(json['filled']),
      tip: $StrokesTable.$convertertip.fromJson(
        serializer.fromJson<int>(json['tip']),
      ),
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
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'id': serializer.toJson<String>(id),
      'pageId': serializer.toJson<String>(pageId),
      'tool': serializer.toJson<int>($StrokesTable.$convertertool.toJson(tool)),
      'color': serializer.toJson<int>(color),
      'width': serializer.toJson<double>(width),
      'opacity': serializer.toJson<double>(opacity),
      'points': serializer.toJson<Uint8List>(points),
      'style': serializer.toJson<int>(
        $StrokesTable.$converterstyle.toJson(style),
      ),
      'filled': serializer.toJson<bool>(filled),
      'tip': serializer.toJson<int>($StrokesTable.$convertertip.toJson(tip)),
      'bboxL': serializer.toJson<double>(bboxL),
      'bboxT': serializer.toJson<double>(bboxT),
      'bboxR': serializer.toJson<double>(bboxR),
      'bboxB': serializer.toJson<double>(bboxB),
      'seq': serializer.toJson<int>(seq),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Stroke copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? id,
    String? pageId,
    ToolType? tool,
    int? color,
    double? width,
    double? opacity,
    Uint8List? points,
    StrokeStyle? style,
    bool? filled,
    StrokeTip? tip,
    double? bboxL,
    double? bboxT,
    double? bboxR,
    double? bboxB,
    int? seq,
    DateTime? createdAt,
  }) => Stroke(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    id: id ?? this.id,
    pageId: pageId ?? this.pageId,
    tool: tool ?? this.tool,
    color: color ?? this.color,
    width: width ?? this.width,
    opacity: opacity ?? this.opacity,
    points: points ?? this.points,
    style: style ?? this.style,
    filled: filled ?? this.filled,
    tip: tip ?? this.tip,
    bboxL: bboxL ?? this.bboxL,
    bboxT: bboxT ?? this.bboxT,
    bboxR: bboxR ?? this.bboxR,
    bboxB: bboxB ?? this.bboxB,
    seq: seq ?? this.seq,
    createdAt: createdAt ?? this.createdAt,
  );
  Stroke copyWithCompanion(StrokesCompanion data) {
    return Stroke(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      id: data.id.present ? data.id.value : this.id,
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      tool: data.tool.present ? data.tool.value : this.tool,
      color: data.color.present ? data.color.value : this.color,
      width: data.width.present ? data.width.value : this.width,
      opacity: data.opacity.present ? data.opacity.value : this.opacity,
      points: data.points.present ? data.points.value : this.points,
      style: data.style.present ? data.style.value : this.style,
      filled: data.filled.present ? data.filled.value : this.filled,
      tip: data.tip.present ? data.tip.value : this.tip,
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
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('tool: $tool, ')
          ..write('color: $color, ')
          ..write('width: $width, ')
          ..write('opacity: $opacity, ')
          ..write('points: $points, ')
          ..write('style: $style, ')
          ..write('filled: $filled, ')
          ..write('tip: $tip, ')
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
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    pageId,
    tool,
    color,
    width,
    opacity,
    $driftBlobEquality.hash(points),
    style,
    filled,
    tip,
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
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.id == this.id &&
          other.pageId == this.pageId &&
          other.tool == this.tool &&
          other.color == this.color &&
          other.width == this.width &&
          other.opacity == this.opacity &&
          $driftBlobEquality.equals(other.points, this.points) &&
          other.style == this.style &&
          other.filled == this.filled &&
          other.tip == this.tip &&
          other.bboxL == this.bboxL &&
          other.bboxT == this.bboxT &&
          other.bboxR == this.bboxR &&
          other.bboxB == this.bboxB &&
          other.seq == this.seq &&
          other.createdAt == this.createdAt);
}

class StrokesCompanion extends UpdateCompanion<Stroke> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> id;
  final Value<String> pageId;
  final Value<ToolType> tool;
  final Value<int> color;
  final Value<double> width;
  final Value<double> opacity;
  final Value<Uint8List> points;
  final Value<StrokeStyle> style;
  final Value<bool> filled;
  final Value<StrokeTip> tip;
  final Value<double> bboxL;
  final Value<double> bboxT;
  final Value<double> bboxR;
  final Value<double> bboxB;
  final Value<int> seq;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StrokesCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.pageId = const Value.absent(),
    this.tool = const Value.absent(),
    this.color = const Value.absent(),
    this.width = const Value.absent(),
    this.opacity = const Value.absent(),
    this.points = const Value.absent(),
    this.style = const Value.absent(),
    this.filled = const Value.absent(),
    this.tip = const Value.absent(),
    this.bboxL = const Value.absent(),
    this.bboxT = const Value.absent(),
    this.bboxR = const Value.absent(),
    this.bboxB = const Value.absent(),
    this.seq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StrokesCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String id,
    required String pageId,
    required ToolType tool,
    required int color,
    required double width,
    this.opacity = const Value.absent(),
    required Uint8List points,
    this.style = const Value.absent(),
    this.filled = const Value.absent(),
    this.tip = const Value.absent(),
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
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? id,
    Expression<String>? pageId,
    Expression<int>? tool,
    Expression<int>? color,
    Expression<double>? width,
    Expression<double>? opacity,
    Expression<Uint8List>? points,
    Expression<int>? style,
    Expression<bool>? filled,
    Expression<int>? tip,
    Expression<double>? bboxL,
    Expression<double>? bboxT,
    Expression<double>? bboxR,
    Expression<double>? bboxB,
    Expression<int>? seq,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (id != null) 'id': id,
      if (pageId != null) 'page_id': pageId,
      if (tool != null) 'tool': tool,
      if (color != null) 'color': color,
      if (width != null) 'width': width,
      if (opacity != null) 'opacity': opacity,
      if (points != null) 'points': points,
      if (style != null) 'style': style,
      if (filled != null) 'filled': filled,
      if (tip != null) 'tip': tip,
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
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? id,
    Value<String>? pageId,
    Value<ToolType>? tool,
    Value<int>? color,
    Value<double>? width,
    Value<double>? opacity,
    Value<Uint8List>? points,
    Value<StrokeStyle>? style,
    Value<bool>? filled,
    Value<StrokeTip>? tip,
    Value<double>? bboxL,
    Value<double>? bboxT,
    Value<double>? bboxR,
    Value<double>? bboxB,
    Value<int>? seq,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StrokesCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      tool: tool ?? this.tool,
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      points: points ?? this.points,
      style: style ?? this.style,
      filled: filled ?? this.filled,
      tip: tip ?? this.tip,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
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
    if (style.present) {
      map['style'] = Variable<int>(
        $StrokesTable.$converterstyle.toSql(style.value),
      );
    }
    if (filled.present) {
      map['filled'] = Variable<bool>(filled.value);
    }
    if (tip.present) {
      map['tip'] = Variable<int>($StrokesTable.$convertertip.toSql(tip.value));
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
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('pageId: $pageId, ')
          ..write('tool: $tool, ')
          ..write('color: $color, ')
          ..write('width: $width, ')
          ..write('opacity: $opacity, ')
          ..write('points: $points, ')
          ..write('style: $style, ')
          ..write('filled: $filled, ')
          ..write('tip: $tip, ')
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
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
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CanvasElement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CanvasElement(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
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
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final DateTime? remoteUpdatedAt;
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
  const CanvasElement({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    this.remoteUpdatedAt,
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
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
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
    return map;
  }

  CanvasElementsCompanion toCompanion(bool nullToAbsent) {
    return CanvasElementsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
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
    );
  }

  factory CanvasElement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CanvasElement(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
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
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
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
    };
  }

  CanvasElement copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
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
  }) => CanvasElement(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
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
  );
  CanvasElement copyWithCompanion(CanvasElementsCompanion data) {
    return CanvasElement(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('CanvasElement(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
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
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
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
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CanvasElement &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
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
          other.createdAt == this.createdAt);
}

class CanvasElementsCompanion extends UpdateCompanion<CanvasElement> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<DateTime?> remoteUpdatedAt;
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
  final Value<int> rowid;
  const CanvasElementsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
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
    this.rowid = const Value.absent(),
  });
  CanvasElementsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
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
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pageId = Value(pageId),
       type = Value(type),
       data = Value(data);
  static Insertable<CanvasElement> custom({
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<DateTime>? remoteUpdatedAt,
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
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
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
      if (rowid != null) 'rowid': rowid,
    });
  }

  CanvasElementsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<DateTime?>? remoteUpdatedAt,
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
    Value<int>? rowid,
  }) {
    return CanvasElementsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
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
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CanvasElementsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteKeyMeta = const VerificationMeta(
    'remoteKey',
  );
  @override
  late final GeneratedColumn<String> remoteKey = GeneratedColumn<String>(
    'remote_key',
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
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    kind,
    path,
    mime,
    data,
    localPath,
    sha256,
    sizeBytes,
    remoteKey,
    createdAt,
  ];
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
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
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('remote_key')) {
      context.handle(
        _remoteKeyMeta,
        remoteKey.isAcceptableOrUnknown(data['remote_key']!, _remoteKeyMeta),
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
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
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      remoteKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_key'],
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
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final DateTime? remoteUpdatedAt;
  final String id;
  final int kind;

  /// Original filename, for display.
  final String path;
  final String? mime;

  /// Web-only fallback: base64 bytes.
  final String? data;

  /// Native: absolute path to the file on disk.
  final String? localPath;

  /// Content hash — dedupes identical imports and keys the remote object.
  final String? sha256;
  final int? sizeBytes;

  /// Object key once uploaded to R2 (null = not uploaded yet).
  final String? remoteKey;
  final DateTime createdAt;
  const Asset({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    this.remoteUpdatedAt,
    required this.id,
    required this.kind,
    required this.path,
    this.mime,
    this.data,
    this.localPath,
    this.sha256,
    this.sizeBytes,
    this.remoteKey,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<int>(kind);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    if (!nullToAbsent || data != null) {
      map['data'] = Variable<String>(data);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || remoteKey != null) {
      map['remote_key'] = Variable<String>(remoteKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AssetsCompanion toCompanion(bool nullToAbsent) {
    return AssetsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      id: Value(id),
      kind: Value(kind),
      path: Value(path),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      data: data == null && nullToAbsent ? const Value.absent() : Value(data),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      remoteKey: remoteKey == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteKey),
      createdAt: Value(createdAt),
    );
  }

  factory Asset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Asset(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<int>(json['kind']),
      path: serializer.fromJson<String>(json['path']),
      mime: serializer.fromJson<String?>(json['mime']),
      data: serializer.fromJson<String?>(json['data']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      remoteKey: serializer.fromJson<String?>(json['remoteKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>(kind),
      'path': serializer.toJson<String>(path),
      'mime': serializer.toJson<String?>(mime),
      'data': serializer.toJson<String?>(data),
      'localPath': serializer.toJson<String?>(localPath),
      'sha256': serializer.toJson<String?>(sha256),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'remoteKey': serializer.toJson<String?>(remoteKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Asset copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? id,
    int? kind,
    String? path,
    Value<String?> mime = const Value.absent(),
    Value<String?> data = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<String?> sha256 = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<String?> remoteKey = const Value.absent(),
    DateTime? createdAt,
  }) => Asset(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    id: id ?? this.id,
    kind: kind ?? this.kind,
    path: path ?? this.path,
    mime: mime.present ? mime.value : this.mime,
    data: data.present ? data.value : this.data,
    localPath: localPath.present ? localPath.value : this.localPath,
    sha256: sha256.present ? sha256.value : this.sha256,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    remoteKey: remoteKey.present ? remoteKey.value : this.remoteKey,
    createdAt: createdAt ?? this.createdAt,
  );
  Asset copyWithCompanion(AssetsCompanion data) {
    return Asset(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      path: data.path.present ? data.path.value : this.path,
      mime: data.mime.present ? data.mime.value : this.mime,
      data: data.data.present ? data.data.value : this.data,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      remoteKey: data.remoteKey.present ? data.remoteKey.value : this.remoteKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Asset(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('data: $data, ')
          ..write('localPath: $localPath, ')
          ..write('sha256: $sha256, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    kind,
    path,
    mime,
    data,
    localPath,
    sha256,
    sizeBytes,
    remoteKey,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Asset &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.path == this.path &&
          other.mime == this.mime &&
          other.data == this.data &&
          other.localPath == this.localPath &&
          other.sha256 == this.sha256 &&
          other.sizeBytes == this.sizeBytes &&
          other.remoteKey == this.remoteKey &&
          other.createdAt == this.createdAt);
}

class AssetsCompanion extends UpdateCompanion<Asset> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> id;
  final Value<int> kind;
  final Value<String> path;
  final Value<String?> mime;
  final Value<String?> data;
  final Value<String?> localPath;
  final Value<String?> sha256;
  final Value<int?> sizeBytes;
  final Value<String?> remoteKey;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AssetsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.path = const Value.absent(),
    this.mime = const Value.absent(),
    this.data = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String id,
    required int kind,
    this.path = const Value.absent(),
    this.mime = const Value.absent(),
    this.data = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.remoteKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind);
  static Insertable<Asset> custom({
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? id,
    Expression<int>? kind,
    Expression<String>? path,
    Expression<String>? mime,
    Expression<String>? data,
    Expression<String>? localPath,
    Expression<String>? sha256,
    Expression<int>? sizeBytes,
    Expression<String>? remoteKey,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (path != null) 'path': path,
      if (mime != null) 'mime': mime,
      if (data != null) 'data': data,
      if (localPath != null) 'local_path': localPath,
      if (sha256 != null) 'sha256': sha256,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (remoteKey != null) 'remote_key': remoteKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? id,
    Value<int>? kind,
    Value<String>? path,
    Value<String?>? mime,
    Value<String?>? data,
    Value<String?>? localPath,
    Value<String?>? sha256,
    Value<int?>? sizeBytes,
    Value<String?>? remoteKey,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AssetsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      mime: mime ?? this.mime,
      data: data ?? this.data,
      localPath: localPath ?? this.localPath,
      sha256: sha256 ?? this.sha256,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      remoteKey: remoteKey ?? this.remoteKey,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
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
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (remoteKey.present) {
      map['remote_key'] = Variable<String>(remoteKey.value);
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
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('mime: $mime, ')
          ..write('data: $data, ')
          ..write('localPath: $localPath, ')
          ..write('sha256: $sha256, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('remoteKey: $remoteKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuizAttemptsTable extends QuizAttempts
    with TableInfo<$QuizAttemptsTable, QuizAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizAttemptsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _remoteUpdatedAtMeta = const VerificationMeta(
    'remoteUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteUpdatedAt =
      GeneratedColumn<DateTime>(
        'remote_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
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
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceLabelMeta = const VerificationMeta(
    'sourceLabel',
  );
  @override
  late final GeneratedColumn<String> sourceLabel = GeneratedColumn<String>(
    'source_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _questionCountMeta = const VerificationMeta(
    'questionCount',
  );
  @override
  late final GeneratedColumn<int> questionCount = GeneratedColumn<int>(
    'question_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _questionsJsonMeta = const VerificationMeta(
    'questionsJson',
  );
  @override
  late final GeneratedColumn<String> questionsJson = GeneratedColumn<String>(
    'questions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answersJsonMeta = const VerificationMeta(
    'answersJson',
  );
  @override
  late final GeneratedColumn<String> answersJson = GeneratedColumn<String>(
    'answers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    documentId,
    familyId,
    title,
    sourceLabel,
    questionCount,
    correctCount,
    durationMs,
    questionsJson,
    answersJson,
    completedAt,
    completed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('remote_updated_at')) {
      context.handle(
        _remoteUpdatedAtMeta,
        remoteUpdatedAt.isAcceptableOrUnknown(
          data['remote_updated_at']!,
          _remoteUpdatedAtMeta,
        ),
      );
    }
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
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_label')) {
      context.handle(
        _sourceLabelMeta,
        sourceLabel.isAcceptableOrUnknown(
          data['source_label']!,
          _sourceLabelMeta,
        ),
      );
    }
    if (data.containsKey('question_count')) {
      context.handle(
        _questionCountMeta,
        questionCount.isAcceptableOrUnknown(
          data['question_count']!,
          _questionCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionCountMeta);
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctCountMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('questions_json')) {
      context.handle(
        _questionsJsonMeta,
        questionsJson.isAcceptableOrUnknown(
          data['questions_json']!,
          _questionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionsJsonMeta);
    }
    if (data.containsKey('answers_json')) {
      context.handle(
        _answersJsonMeta,
        answersJson.isAcceptableOrUnknown(
          data['answers_json']!,
          _answersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_answersJsonMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizAttempt(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      remoteUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_updated_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_label'],
      )!,
      questionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_count'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      questionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}questions_json'],
      )!,
      answersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answers_json'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $QuizAttemptsTable createAlias(String alias) {
    return $QuizAttemptsTable(attachedDatabase, alias);
  }
}

class QuizAttempt extends DataClass implements Insertable<QuizAttempt> {
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final DateTime? remoteUpdatedAt;
  final String id;
  final String documentId;

  /// Shared across retakes of the same generated question set.
  final String familyId;
  final String title;
  final String sourceLabel;
  final int questionCount;
  final int correctCount;
  final int durationMs;
  final String questionsJson;
  final String answersJson;
  final DateTime completedAt;

  /// False until the user finishes (or times out of) this generated set.
  /// Existing rows were only written on finish, so they default to true.
  final bool completed;
  const QuizAttempt({
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    this.remoteUpdatedAt,
    required this.id,
    required this.documentId,
    required this.familyId,
    required this.title,
    required this.sourceLabel,
    required this.questionCount,
    required this.correctCount,
    required this.durationMs,
    required this.questionsJson,
    required this.answersJson,
    required this.completedAt,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || remoteUpdatedAt != null) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt);
    }
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['family_id'] = Variable<String>(familyId);
    map['title'] = Variable<String>(title);
    map['source_label'] = Variable<String>(sourceLabel);
    map['question_count'] = Variable<int>(questionCount);
    map['correct_count'] = Variable<int>(correctCount);
    map['duration_ms'] = Variable<int>(durationMs);
    map['questions_json'] = Variable<String>(questionsJson);
    map['answers_json'] = Variable<String>(answersJson);
    map['completed_at'] = Variable<DateTime>(completedAt);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  QuizAttemptsCompanion toCompanion(bool nullToAbsent) {
    return QuizAttemptsCompanion(
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      remoteUpdatedAt: remoteUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUpdatedAt),
      id: Value(id),
      documentId: Value(documentId),
      familyId: Value(familyId),
      title: Value(title),
      sourceLabel: Value(sourceLabel),
      questionCount: Value(questionCount),
      correctCount: Value(correctCount),
      durationMs: Value(durationMs),
      questionsJson: Value(questionsJson),
      answersJson: Value(answersJson),
      completedAt: Value(completedAt),
      completed: Value(completed),
    );
  }

  factory QuizAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizAttempt(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      remoteUpdatedAt: serializer.fromJson<DateTime?>(json['remoteUpdatedAt']),
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      familyId: serializer.fromJson<String>(json['familyId']),
      title: serializer.fromJson<String>(json['title']),
      sourceLabel: serializer.fromJson<String>(json['sourceLabel']),
      questionCount: serializer.fromJson<int>(json['questionCount']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      questionsJson: serializer.fromJson<String>(json['questionsJson']),
      answersJson: serializer.fromJson<String>(json['answersJson']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'remoteUpdatedAt': serializer.toJson<DateTime?>(remoteUpdatedAt),
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'familyId': serializer.toJson<String>(familyId),
      'title': serializer.toJson<String>(title),
      'sourceLabel': serializer.toJson<String>(sourceLabel),
      'questionCount': serializer.toJson<int>(questionCount),
      'correctCount': serializer.toJson<int>(correctCount),
      'durationMs': serializer.toJson<int>(durationMs),
      'questionsJson': serializer.toJson<String>(questionsJson),
      'answersJson': serializer.toJson<String>(answersJson),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  QuizAttempt copyWith({
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    Value<DateTime?> remoteUpdatedAt = const Value.absent(),
    String? id,
    String? documentId,
    String? familyId,
    String? title,
    String? sourceLabel,
    int? questionCount,
    int? correctCount,
    int? durationMs,
    String? questionsJson,
    String? answersJson,
    DateTime? completedAt,
    bool? completed,
  }) => QuizAttempt(
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    remoteUpdatedAt: remoteUpdatedAt.present
        ? remoteUpdatedAt.value
        : this.remoteUpdatedAt,
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    familyId: familyId ?? this.familyId,
    title: title ?? this.title,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    questionCount: questionCount ?? this.questionCount,
    correctCount: correctCount ?? this.correctCount,
    durationMs: durationMs ?? this.durationMs,
    questionsJson: questionsJson ?? this.questionsJson,
    answersJson: answersJson ?? this.answersJson,
    completedAt: completedAt ?? this.completedAt,
    completed: completed ?? this.completed,
  );
  QuizAttempt copyWithCompanion(QuizAttemptsCompanion data) {
    return QuizAttempt(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      remoteUpdatedAt: data.remoteUpdatedAt.present
          ? data.remoteUpdatedAt.value
          : this.remoteUpdatedAt,
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      title: data.title.present ? data.title.value : this.title,
      sourceLabel: data.sourceLabel.present
          ? data.sourceLabel.value
          : this.sourceLabel,
      questionCount: data.questionCount.present
          ? data.questionCount.value
          : this.questionCount,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      questionsJson: data.questionsJson.present
          ? data.questionsJson.value
          : this.questionsJson,
      answersJson: data.answersJson.present
          ? data.answersJson.value
          : this.answersJson,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizAttempt(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('familyId: $familyId, ')
          ..write('title: $title, ')
          ..write('sourceLabel: $sourceLabel, ')
          ..write('questionCount: $questionCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('durationMs: $durationMs, ')
          ..write('questionsJson: $questionsJson, ')
          ..write('answersJson: $answersJson, ')
          ..write('completedAt: $completedAt, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deletedAt,
    dirty,
    remoteUpdatedAt,
    id,
    documentId,
    familyId,
    title,
    sourceLabel,
    questionCount,
    correctCount,
    durationMs,
    questionsJson,
    answersJson,
    completedAt,
    completed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizAttempt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.remoteUpdatedAt == this.remoteUpdatedAt &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.familyId == this.familyId &&
          other.title == this.title &&
          other.sourceLabel == this.sourceLabel &&
          other.questionCount == this.questionCount &&
          other.correctCount == this.correctCount &&
          other.durationMs == this.durationMs &&
          other.questionsJson == this.questionsJson &&
          other.answersJson == this.answersJson &&
          other.completedAt == this.completedAt &&
          other.completed == this.completed);
}

class QuizAttemptsCompanion extends UpdateCompanion<QuizAttempt> {
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<DateTime?> remoteUpdatedAt;
  final Value<String> id;
  final Value<String> documentId;
  final Value<String> familyId;
  final Value<String> title;
  final Value<String> sourceLabel;
  final Value<int> questionCount;
  final Value<int> correctCount;
  final Value<int> durationMs;
  final Value<String> questionsJson;
  final Value<String> answersJson;
  final Value<DateTime> completedAt;
  final Value<bool> completed;
  final Value<int> rowid;
  const QuizAttemptsCompanion({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.familyId = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceLabel = const Value.absent(),
    this.questionCount = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.questionsJson = const Value.absent(),
    this.answersJson = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuizAttemptsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.remoteUpdatedAt = const Value.absent(),
    required String id,
    required String documentId,
    required String familyId,
    required String title,
    this.sourceLabel = const Value.absent(),
    required int questionCount,
    required int correctCount,
    this.durationMs = const Value.absent(),
    required String questionsJson,
    required String answersJson,
    this.completedAt = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       familyId = Value(familyId),
       title = Value(title),
       questionCount = Value(questionCount),
       correctCount = Value(correctCount),
       questionsJson = Value(questionsJson),
       answersJson = Value(answersJson);
  static Insertable<QuizAttempt> custom({
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<DateTime>? remoteUpdatedAt,
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? familyId,
    Expression<String>? title,
    Expression<String>? sourceLabel,
    Expression<int>? questionCount,
    Expression<int>? correctCount,
    Expression<int>? durationMs,
    Expression<String>? questionsJson,
    Expression<String>? answersJson,
    Expression<DateTime>? completedAt,
    Expression<bool>? completed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (familyId != null) 'family_id': familyId,
      if (title != null) 'title': title,
      if (sourceLabel != null) 'source_label': sourceLabel,
      if (questionCount != null) 'question_count': questionCount,
      if (correctCount != null) 'correct_count': correctCount,
      if (durationMs != null) 'duration_ms': durationMs,
      if (questionsJson != null) 'questions_json': questionsJson,
      if (answersJson != null) 'answers_json': answersJson,
      if (completedAt != null) 'completed_at': completedAt,
      if (completed != null) 'completed': completed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuizAttemptsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<DateTime?>? remoteUpdatedAt,
    Value<String>? id,
    Value<String>? documentId,
    Value<String>? familyId,
    Value<String>? title,
    Value<String>? sourceLabel,
    Value<int>? questionCount,
    Value<int>? correctCount,
    Value<int>? durationMs,
    Value<String>? questionsJson,
    Value<String>? answersJson,
    Value<DateTime>? completedAt,
    Value<bool>? completed,
    Value<int>? rowid,
  }) {
    return QuizAttemptsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      familyId: familyId ?? this.familyId,
      title: title ?? this.title,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      questionCount: questionCount ?? this.questionCount,
      correctCount: correctCount ?? this.correctCount,
      durationMs: durationMs ?? this.durationMs,
      questionsJson: questionsJson ?? this.questionsJson,
      answersJson: answersJson ?? this.answersJson,
      completedAt: completedAt ?? this.completedAt,
      completed: completed ?? this.completed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (remoteUpdatedAt.present) {
      map['remote_updated_at'] = Variable<DateTime>(remoteUpdatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceLabel.present) {
      map['source_label'] = Variable<String>(sourceLabel.value);
    }
    if (questionCount.present) {
      map['question_count'] = Variable<int>(questionCount.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (questionsJson.present) {
      map['questions_json'] = Variable<String>(questionsJson.value);
    }
    if (answersJson.present) {
      map['answers_json'] = Variable<String>(answersJson.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizAttemptsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('remoteUpdatedAt: $remoteUpdatedAt, ')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('familyId: $familyId, ')
          ..write('title: $title, ')
          ..write('sourceLabel: $sourceLabel, ')
          ..write('questionCount: $questionCount, ')
          ..write('correctCount: $correctCount, ')
          ..write('durationMs: $durationMs, ')
          ..write('questionsJson: $questionsJson, ')
          ..write('answersJson: $answersJson, ')
          ..write('completedAt: $completedAt, ')
          ..write('completed: $completed, ')
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
  late final $QuizAttemptsTable quizAttempts = $QuizAttemptsTable(this);
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
    quizAttempts,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('quiz_attempts', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      required String id,
      required DocumentType type,
      Value<String> title,
      Value<String?> parentId,
      Value<int> coverStyle,
      Value<PageOrientation> orientation,
      Value<PageSizePreset> pageSize,
      Value<bool> starred,
      Value<String?> ownerUid,
      Value<String?> coverThumb,
      Value<String?> outline,
      Value<DateTime?> trashedAt,
      Value<int> sortIndex,
      Value<DateTime> createdAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> id,
      Value<DocumentType> type,
      Value<String> title,
      Value<String?> parentId,
      Value<int> coverStyle,
      Value<PageOrientation> orientation,
      Value<PageSizePreset> pageSize,
      Value<bool> starred,
      Value<String?> ownerUid,
      Value<String?> coverThumb,
      Value<String?> outline,
      Value<DateTime?> trashedAt,
      Value<int> sortIndex,
      Value<DateTime> createdAt,
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

  static MultiTypedResultKey<$QuizAttemptsTable, List<QuizAttempt>>
  _quizAttemptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.quizAttempts,
    aliasName: 'documents__id__quiz_attempts__document_id',
  );

  $$QuizAttemptsTableProcessedTableManager get quizAttemptsRefs {
    final manager = $$QuizAttemptsTableTableManager(
      $_db,
      $_db.quizAttempts,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_quizAttemptsRefsTable($_db));
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
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

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

  ColumnFilters<String> get ownerUid => $composableBuilder(
    column: $table.ownerUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverThumb => $composableBuilder(
    column: $table.coverThumb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outline => $composableBuilder(
    column: $table.outline,
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

  Expression<bool> quizAttemptsRefs(
    Expression<bool> Function($$QuizAttemptsTableFilterComposer f) f,
  ) {
    final $$QuizAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizAttempts,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.quizAttempts,
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
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

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

  ColumnOrderings<String> get ownerUid => $composableBuilder(
    column: $table.ownerUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverThumb => $composableBuilder(
    column: $table.coverThumb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outline => $composableBuilder(
    column: $table.outline,
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
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

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

  GeneratedColumn<String> get ownerUid =>
      $composableBuilder(column: $table.ownerUid, builder: (column) => column);

  GeneratedColumn<String> get coverThumb => $composableBuilder(
    column: $table.coverThumb,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outline =>
      $composableBuilder(column: $table.outline, builder: (column) => column);

  GeneratedColumn<DateTime> get trashedAt =>
      $composableBuilder(column: $table.trashedAt, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

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

  Expression<T> quizAttemptsRefs<T extends Object>(
    Expression<T> Function($$QuizAttemptsTableAnnotationComposer a) f,
  ) {
    final $$QuizAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizAttempts,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.quizAttempts,
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
          PrefetchHooks Function({bool notePagesRefs, bool quizAttemptsRefs})
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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<DocumentType> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> coverStyle = const Value.absent(),
                Value<PageOrientation> orientation = const Value.absent(),
                Value<PageSizePreset> pageSize = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<String?> ownerUid = const Value.absent(),
                Value<String?> coverThumb = const Value.absent(),
                Value<String?> outline = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                type: type,
                title: title,
                parentId: parentId,
                coverStyle: coverStyle,
                orientation: orientation,
                pageSize: pageSize,
                starred: starred,
                ownerUid: ownerUid,
                coverThumb: coverThumb,
                outline: outline,
                trashedAt: trashedAt,
                sortIndex: sortIndex,
                createdAt: createdAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String id,
                required DocumentType type,
                Value<String> title = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> coverStyle = const Value.absent(),
                Value<PageOrientation> orientation = const Value.absent(),
                Value<PageSizePreset> pageSize = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<String?> ownerUid = const Value.absent(),
                Value<String?> coverThumb = const Value.absent(),
                Value<String?> outline = const Value.absent(),
                Value<DateTime?> trashedAt = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                type: type,
                title: title,
                parentId: parentId,
                coverStyle: coverStyle,
                orientation: orientation,
                pageSize: pageSize,
                starred: starred,
                ownerUid: ownerUid,
                coverThumb: coverThumb,
                outline: outline,
                trashedAt: trashedAt,
                sortIndex: sortIndex,
                createdAt: createdAt,
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
          prefetchHooksCallback:
              ({notePagesRefs = false, quizAttemptsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (notePagesRefs) db.notePages,
                    if (quizAttemptsRefs) db.quizAttempts,
                  ],
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
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (quizAttemptsRefs)
                        await $_getPrefetchedData<
                          Document,
                          $DocumentsTable,
                          QuizAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._quizAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).quizAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
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
      PrefetchHooks Function({bool notePagesRefs, bool quizAttemptsRefs})
    >;
typedef $$NotePagesTableCreateCompanionBuilder =
    NotePagesCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      required String id,
      required String documentId,
      required int pageIndex,
      Value<PaperTemplate> template,
      Value<PaperColor> paperColor,
      Value<MarginSpec> marginSpec,
      Value<String?> pdfAssetId,
      Value<int?> pdfPageIndex,
      Value<String?> bgAssetId,
      Value<double?> pageW,
      Value<double?> pageH,
      Value<String?> bookmarkTitle,
      Value<String?> searchText,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$NotePagesTableUpdateCompanionBuilder =
    NotePagesCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> id,
      Value<String> documentId,
      Value<int> pageIndex,
      Value<PaperTemplate> template,
      Value<PaperColor> paperColor,
      Value<MarginSpec> marginSpec,
      Value<String?> pdfAssetId,
      Value<int?> pdfPageIndex,
      Value<String?> bgAssetId,
      Value<double?> pageW,
      Value<double?> pageH,
      Value<String?> bookmarkTitle,
      Value<String?> searchText,
      Value<DateTime> createdAt,
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
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

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

  ColumnFilters<String> get bgAssetId => $composableBuilder(
    column: $table.bgAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pageW => $composableBuilder(
    column: $table.pageW,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pageH => $composableBuilder(
    column: $table.pageH,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookmarkTitle => $composableBuilder(
    column: $table.bookmarkTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

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

  ColumnOrderings<String> get bgAssetId => $composableBuilder(
    column: $table.bgAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pageW => $composableBuilder(
    column: $table.pageW,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pageH => $composableBuilder(
    column: $table.pageH,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookmarkTitle => $composableBuilder(
    column: $table.bookmarkTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

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

  GeneratedColumn<String> get bgAssetId =>
      $composableBuilder(column: $table.bgAssetId, builder: (column) => column);

  GeneratedColumn<double> get pageW =>
      $composableBuilder(column: $table.pageW, builder: (column) => column);

  GeneratedColumn<double> get pageH =>
      $composableBuilder(column: $table.pageH, builder: (column) => column);

  GeneratedColumn<String> get bookmarkTitle => $composableBuilder(
    column: $table.bookmarkTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<PaperTemplate> template = const Value.absent(),
                Value<PaperColor> paperColor = const Value.absent(),
                Value<MarginSpec> marginSpec = const Value.absent(),
                Value<String?> pdfAssetId = const Value.absent(),
                Value<int?> pdfPageIndex = const Value.absent(),
                Value<String?> bgAssetId = const Value.absent(),
                Value<double?> pageW = const Value.absent(),
                Value<double?> pageH = const Value.absent(),
                Value<String?> bookmarkTitle = const Value.absent(),
                Value<String?> searchText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotePagesCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                template: template,
                paperColor: paperColor,
                marginSpec: marginSpec,
                pdfAssetId: pdfAssetId,
                pdfPageIndex: pdfPageIndex,
                bgAssetId: bgAssetId,
                pageW: pageW,
                pageH: pageH,
                bookmarkTitle: bookmarkTitle,
                searchText: searchText,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String id,
                required String documentId,
                required int pageIndex,
                Value<PaperTemplate> template = const Value.absent(),
                Value<PaperColor> paperColor = const Value.absent(),
                Value<MarginSpec> marginSpec = const Value.absent(),
                Value<String?> pdfAssetId = const Value.absent(),
                Value<int?> pdfPageIndex = const Value.absent(),
                Value<String?> bgAssetId = const Value.absent(),
                Value<double?> pageW = const Value.absent(),
                Value<double?> pageH = const Value.absent(),
                Value<String?> bookmarkTitle = const Value.absent(),
                Value<String?> searchText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotePagesCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                template: template,
                paperColor: paperColor,
                marginSpec: marginSpec,
                pdfAssetId: pdfAssetId,
                pdfPageIndex: pdfPageIndex,
                bgAssetId: bgAssetId,
                pageW: pageW,
                pageH: pageH,
                bookmarkTitle: bookmarkTitle,
                searchText: searchText,
                createdAt: createdAt,
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
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      required String id,
      required String pageId,
      required ToolType tool,
      required int color,
      required double width,
      Value<double> opacity,
      required Uint8List points,
      Value<StrokeStyle> style,
      Value<bool> filled,
      Value<StrokeTip> tip,
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
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> id,
      Value<String> pageId,
      Value<ToolType> tool,
      Value<int> color,
      Value<double> width,
      Value<double> opacity,
      Value<Uint8List> points,
      Value<StrokeStyle> style,
      Value<bool> filled,
      Value<StrokeTip> tip,
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
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

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

  ColumnWithTypeConverterFilters<StrokeStyle, StrokeStyle, int> get style =>
      $composableBuilder(
        column: $table.style,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get filled => $composableBuilder(
    column: $table.filled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StrokeTip, StrokeTip, int> get tip =>
      $composableBuilder(
        column: $table.tip,
        builder: (column) => ColumnWithTypeConverterFilters(column),
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
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

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

  ColumnOrderings<int> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get filled => $composableBuilder(
    column: $table.filled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tip => $composableBuilder(
    column: $table.tip,
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
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

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

  GeneratedColumnWithTypeConverter<StrokeStyle, int> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<bool> get filled =>
      $composableBuilder(column: $table.filled, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StrokeTip, int> get tip =>
      $composableBuilder(column: $table.tip, builder: (column) => column);

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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> pageId = const Value.absent(),
                Value<ToolType> tool = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> opacity = const Value.absent(),
                Value<Uint8List> points = const Value.absent(),
                Value<StrokeStyle> style = const Value.absent(),
                Value<bool> filled = const Value.absent(),
                Value<StrokeTip> tip = const Value.absent(),
                Value<double> bboxL = const Value.absent(),
                Value<double> bboxT = const Value.absent(),
                Value<double> bboxR = const Value.absent(),
                Value<double> bboxB = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StrokesCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                pageId: pageId,
                tool: tool,
                color: color,
                width: width,
                opacity: opacity,
                points: points,
                style: style,
                filled: filled,
                tip: tip,
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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String id,
                required String pageId,
                required ToolType tool,
                required int color,
                required double width,
                Value<double> opacity = const Value.absent(),
                required Uint8List points,
                Value<StrokeStyle> style = const Value.absent(),
                Value<bool> filled = const Value.absent(),
                Value<StrokeTip> tip = const Value.absent(),
                required double bboxL,
                required double bboxT,
                required double bboxR,
                required double bboxB,
                required int seq,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StrokesCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                pageId: pageId,
                tool: tool,
                color: color,
                width: width,
                opacity: opacity,
                points: points,
                style: style,
                filled: filled,
                tip: tip,
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
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
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
      Value<int> rowid,
    });
typedef $$CanvasElementsTableUpdateCompanionBuilder =
    CanvasElementsCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
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
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

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
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

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
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
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
                Value<int> rowid = const Value.absent(),
              }) => CanvasElementsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
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
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
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
                Value<int> rowid = const Value.absent(),
              }) => CanvasElementsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
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
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      required String id,
      required int kind,
      Value<String> path,
      Value<String?> mime,
      Value<String?> data,
      Value<String?> localPath,
      Value<String?> sha256,
      Value<int?> sizeBytes,
      Value<String?> remoteKey,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$AssetsTableUpdateCompanionBuilder =
    AssetsCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> id,
      Value<int> kind,
      Value<String> path,
      Value<String?> mime,
      Value<String?> data,
      Value<String?> localPath,
      Value<String?> sha256,
      Value<int?> sizeBytes,
      Value<String?> remoteKey,
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
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

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

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
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
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

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

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteKey => $composableBuilder(
    column: $table.remoteKey,
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
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get remoteKey =>
      $composableBuilder(column: $table.remoteKey, builder: (column) => column);

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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<String?> data = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> remoteKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                kind: kind,
                path: path,
                mime: mime,
                data: data,
                localPath: localPath,
                sha256: sha256,
                sizeBytes: sizeBytes,
                remoteKey: remoteKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String id,
                required int kind,
                Value<String> path = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<String?> data = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> remoteKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                kind: kind,
                path: path,
                mime: mime,
                data: data,
                localPath: localPath,
                sha256: sha256,
                sizeBytes: sizeBytes,
                remoteKey: remoteKey,
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
typedef $$QuizAttemptsTableCreateCompanionBuilder =
    QuizAttemptsCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      required String id,
      required String documentId,
      required String familyId,
      required String title,
      Value<String> sourceLabel,
      required int questionCount,
      required int correctCount,
      Value<int> durationMs,
      required String questionsJson,
      required String answersJson,
      Value<DateTime> completedAt,
      Value<bool> completed,
      Value<int> rowid,
    });
typedef $$QuizAttemptsTableUpdateCompanionBuilder =
    QuizAttemptsCompanion Function({
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<DateTime?> remoteUpdatedAt,
      Value<String> id,
      Value<String> documentId,
      Value<String> familyId,
      Value<String> title,
      Value<String> sourceLabel,
      Value<int> questionCount,
      Value<int> correctCount,
      Value<int> durationMs,
      Value<String> questionsJson,
      Value<String> answersJson,
      Value<DateTime> completedAt,
      Value<bool> completed,
      Value<int> rowid,
    });

final class $$QuizAttemptsTableReferences
    extends BaseReferences<_$AppDatabase, $QuizAttemptsTable, QuizAttempt> {
  $$QuizAttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DocumentsTable _documentIdTable(_$AppDatabase db) =>
      db.documents.createAlias('quiz_attempts__document_id__documents__id');

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
}

class $$QuizAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $QuizAttemptsTable> {
  $$QuizAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
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
}

class $$QuizAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizAttemptsTable> {
  $$QuizAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
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

class $$QuizAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizAttemptsTable> {
  $$QuizAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteUpdatedAt => $composableBuilder(
    column: $table.remoteUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get questionsJson => $composableBuilder(
    column: $table.questionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answersJson => $composableBuilder(
    column: $table.answersJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

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
}

class $$QuizAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuizAttemptsTable,
          QuizAttempt,
          $$QuizAttemptsTableFilterComposer,
          $$QuizAttemptsTableOrderingComposer,
          $$QuizAttemptsTableAnnotationComposer,
          $$QuizAttemptsTableCreateCompanionBuilder,
          $$QuizAttemptsTableUpdateCompanionBuilder,
          (QuizAttempt, $$QuizAttemptsTableReferences),
          QuizAttempt,
          PrefetchHooks Function({bool documentId})
        > {
  $$QuizAttemptsTableTableManager(_$AppDatabase db, $QuizAttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourceLabel = const Value.absent(),
                Value<int> questionCount = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> questionsJson = const Value.absent(),
                Value<String> answersJson = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuizAttemptsCompanion(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                documentId: documentId,
                familyId: familyId,
                title: title,
                sourceLabel: sourceLabel,
                questionCount: questionCount,
                correctCount: correctCount,
                durationMs: durationMs,
                questionsJson: questionsJson,
                answersJson: answersJson,
                completedAt: completedAt,
                completed: completed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<DateTime?> remoteUpdatedAt = const Value.absent(),
                required String id,
                required String documentId,
                required String familyId,
                required String title,
                Value<String> sourceLabel = const Value.absent(),
                required int questionCount,
                required int correctCount,
                Value<int> durationMs = const Value.absent(),
                required String questionsJson,
                required String answersJson,
                Value<DateTime> completedAt = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuizAttemptsCompanion.insert(
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                remoteUpdatedAt: remoteUpdatedAt,
                id: id,
                documentId: documentId,
                familyId: familyId,
                title: title,
                sourceLabel: sourceLabel,
                questionCount: questionCount,
                correctCount: correctCount,
                durationMs: durationMs,
                questionsJson: questionsJson,
                answersJson: answersJson,
                completedAt: completedAt,
                completed: completed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuizAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
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
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$QuizAttemptsTableReferences
                                    ._documentIdTable(db),
                                referencedColumn: $$QuizAttemptsTableReferences
                                    ._documentIdTable(db)
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

typedef $$QuizAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuizAttemptsTable,
      QuizAttempt,
      $$QuizAttemptsTableFilterComposer,
      $$QuizAttemptsTableOrderingComposer,
      $$QuizAttemptsTableAnnotationComposer,
      $$QuizAttemptsTableCreateCompanionBuilder,
      $$QuizAttemptsTableUpdateCompanionBuilder,
      (QuizAttempt, $$QuizAttemptsTableReferences),
      QuizAttempt,
      PrefetchHooks Function({bool documentId})
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
  $$QuizAttemptsTableTableManager get quizAttempts =>
      $$QuizAttemptsTableTableManager(_db, _db.quizAttempts);
}
