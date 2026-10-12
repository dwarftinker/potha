// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
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
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortTitleMeta = const VerificationMeta(
    'sortTitle',
  );
  @override
  late final GeneratedColumn<String> sortTitle = GeneratedColumn<String>(
    'sort_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchKeyMeta = const VerificationMeta(
    'searchKey',
  );
  @override
  late final GeneratedColumn<String> searchKey = GeneratedColumn<String>(
    'search_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalFileNameMeta = const VerificationMeta(
    'originalFileName',
  );
  @override
  late final GeneratedColumn<String> originalFileName = GeneratedColumn<String>(
    'original_file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    check: () => ComparableExpr(pageCount).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPasswordProtectedMeta =
      const VerificationMeta('isPasswordProtected');
  @override
  late final GeneratedColumn<bool> isPasswordProtected = GeneratedColumn<bool>(
    'is_password_protected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_password_protected" IN (0, 1))',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
    format,
    title,
    author,
    sortTitle,
    searchKey,
    originalFileName,
    contentHash,
    sizeBytes,
    pageCount,
    isPasswordProtected,
    addedAt,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('sort_title')) {
      context.handle(
        _sortTitleMeta,
        sortTitle.isAcceptableOrUnknown(data['sort_title']!, _sortTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_sortTitleMeta);
    }
    if (data.containsKey('search_key')) {
      context.handle(
        _searchKeyMeta,
        searchKey.isAcceptableOrUnknown(data['search_key']!, _searchKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_searchKeyMeta);
    }
    if (data.containsKey('original_file_name')) {
      context.handle(
        _originalFileNameMeta,
        originalFileName.isAcceptableOrUnknown(
          data['original_file_name']!,
          _originalFileNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalFileNameMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('is_password_protected')) {
      context.handle(
        _isPasswordProtectedMeta,
        isPasswordProtected.isAcceptableOrUnknown(
          data['is_password_protected']!,
          _isPasswordProtectedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isPasswordProtectedMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
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
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      sortTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_title'],
      )!,
      searchKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_key'],
      )!,
      originalFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_file_name'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      isPasswordProtected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_password_protected'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  /// Random UUID v4, created at import.
  final String id;

  /// `pdf` for now; later formats share the table.
  final String format;

  /// Never blank (FR-010).
  final String title;
  final String? author;
  final String sortTitle;
  final String searchKey;
  final String originalFileName;

  /// SHA-256 of the file, lower-case hex (FR-007).
  final String contentHash;
  final int sizeBytes;
  final int pageCount;
  final bool isPasswordProtected;

  /// UTC.
  final DateTime addedAt;

  /// UTC; null until first opened.
  final DateTime? lastOpenedAt;
  const Book({
    required this.id,
    required this.format,
    required this.title,
    this.author,
    required this.sortTitle,
    required this.searchKey,
    required this.originalFileName,
    required this.contentHash,
    required this.sizeBytes,
    required this.pageCount,
    required this.isPasswordProtected,
    required this.addedAt,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['format'] = Variable<String>(format);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['sort_title'] = Variable<String>(sortTitle);
    map['search_key'] = Variable<String>(searchKey);
    map['original_file_name'] = Variable<String>(originalFileName);
    map['content_hash'] = Variable<String>(contentHash);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['page_count'] = Variable<int>(pageCount);
    map['is_password_protected'] = Variable<bool>(isPasswordProtected);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      format: Value(format),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      sortTitle: Value(sortTitle),
      searchKey: Value(searchKey),
      originalFileName: Value(originalFileName),
      contentHash: Value(contentHash),
      sizeBytes: Value(sizeBytes),
      pageCount: Value(pageCount),
      isPasswordProtected: Value(isPasswordProtected),
      addedAt: Value(addedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<String>(json['id']),
      format: serializer.fromJson<String>(json['format']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      sortTitle: serializer.fromJson<String>(json['sortTitle']),
      searchKey: serializer.fromJson<String>(json['searchKey']),
      originalFileName: serializer.fromJson<String>(json['originalFileName']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      isPasswordProtected: serializer.fromJson<bool>(
        json['isPasswordProtected'],
      ),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'format': serializer.toJson<String>(format),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'sortTitle': serializer.toJson<String>(sortTitle),
      'searchKey': serializer.toJson<String>(searchKey),
      'originalFileName': serializer.toJson<String>(originalFileName),
      'contentHash': serializer.toJson<String>(contentHash),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'pageCount': serializer.toJson<int>(pageCount),
      'isPasswordProtected': serializer.toJson<bool>(isPasswordProtected),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
    };
  }

  Book copyWith({
    String? id,
    String? format,
    String? title,
    Value<String?> author = const Value.absent(),
    String? sortTitle,
    String? searchKey,
    String? originalFileName,
    String? contentHash,
    int? sizeBytes,
    int? pageCount,
    bool? isPasswordProtected,
    DateTime? addedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    format: format ?? this.format,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    sortTitle: sortTitle ?? this.sortTitle,
    searchKey: searchKey ?? this.searchKey,
    originalFileName: originalFileName ?? this.originalFileName,
    contentHash: contentHash ?? this.contentHash,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    pageCount: pageCount ?? this.pageCount,
    isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
    addedAt: addedAt ?? this.addedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      format: data.format.present ? data.format.value : this.format,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      sortTitle: data.sortTitle.present ? data.sortTitle.value : this.sortTitle,
      searchKey: data.searchKey.present ? data.searchKey.value : this.searchKey,
      originalFileName: data.originalFileName.present
          ? data.originalFileName.value
          : this.originalFileName,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      isPasswordProtected: data.isPasswordProtected.present
          ? data.isPasswordProtected.value
          : this.isPasswordProtected,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('searchKey: $searchKey, ')
          ..write('originalFileName: $originalFileName, ')
          ..write('contentHash: $contentHash, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('pageCount: $pageCount, ')
          ..write('isPasswordProtected: $isPasswordProtected, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    format,
    title,
    author,
    sortTitle,
    searchKey,
    originalFileName,
    contentHash,
    sizeBytes,
    pageCount,
    isPasswordProtected,
    addedAt,
    lastOpenedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.format == this.format &&
          other.title == this.title &&
          other.author == this.author &&
          other.sortTitle == this.sortTitle &&
          other.searchKey == this.searchKey &&
          other.originalFileName == this.originalFileName &&
          other.contentHash == this.contentHash &&
          other.sizeBytes == this.sizeBytes &&
          other.pageCount == this.pageCount &&
          other.isPasswordProtected == this.isPasswordProtected &&
          other.addedAt == this.addedAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<String> id;
  final Value<String> format;
  final Value<String> title;
  final Value<String?> author;
  final Value<String> sortTitle;
  final Value<String> searchKey;
  final Value<String> originalFileName;
  final Value<String> contentHash;
  final Value<int> sizeBytes;
  final Value<int> pageCount;
  final Value<bool> isPasswordProtected;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.format = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.sortTitle = const Value.absent(),
    this.searchKey = const Value.absent(),
    this.originalFileName = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.isPasswordProtected = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String format,
    required String title,
    this.author = const Value.absent(),
    required String sortTitle,
    required String searchKey,
    required String originalFileName,
    required String contentHash,
    required int sizeBytes,
    required int pageCount,
    required bool isPasswordProtected,
    required DateTime addedAt,
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       format = Value(format),
       title = Value(title),
       sortTitle = Value(sortTitle),
       searchKey = Value(searchKey),
       originalFileName = Value(originalFileName),
       contentHash = Value(contentHash),
       sizeBytes = Value(sizeBytes),
       pageCount = Value(pageCount),
       isPasswordProtected = Value(isPasswordProtected),
       addedAt = Value(addedAt);
  static Insertable<Book> custom({
    Expression<String>? id,
    Expression<String>? format,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? sortTitle,
    Expression<String>? searchKey,
    Expression<String>? originalFileName,
    Expression<String>? contentHash,
    Expression<int>? sizeBytes,
    Expression<int>? pageCount,
    Expression<bool>? isPasswordProtected,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (format != null) 'format': format,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (sortTitle != null) 'sort_title': sortTitle,
      if (searchKey != null) 'search_key': searchKey,
      if (originalFileName != null) 'original_file_name': originalFileName,
      if (contentHash != null) 'content_hash': contentHash,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (pageCount != null) 'page_count': pageCount,
      if (isPasswordProtected != null)
        'is_password_protected': isPasswordProtected,
      if (addedAt != null) 'added_at': addedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? format,
    Value<String>? title,
    Value<String?>? author,
    Value<String>? sortTitle,
    Value<String>? searchKey,
    Value<String>? originalFileName,
    Value<String>? contentHash,
    Value<int>? sizeBytes,
    Value<int>? pageCount,
    Value<bool>? isPasswordProtected,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      format: format ?? this.format,
      title: title ?? this.title,
      author: author ?? this.author,
      sortTitle: sortTitle ?? this.sortTitle,
      searchKey: searchKey ?? this.searchKey,
      originalFileName: originalFileName ?? this.originalFileName,
      contentHash: contentHash ?? this.contentHash,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      pageCount: pageCount ?? this.pageCount,
      isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
      addedAt: addedAt ?? this.addedAt,
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
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (sortTitle.present) {
      map['sort_title'] = Variable<String>(sortTitle.value);
    }
    if (searchKey.present) {
      map['search_key'] = Variable<String>(searchKey.value);
    }
    if (originalFileName.present) {
      map['original_file_name'] = Variable<String>(originalFileName.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (isPasswordProtected.present) {
      map['is_password_protected'] = Variable<bool>(isPasswordProtected.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
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
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('searchKey: $searchKey, ')
          ..write('originalFileName: $originalFileName, ')
          ..write('contentHash: $contentHash, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('pageCount: $pageCount, ')
          ..write('isPasswordProtected: $isPasswordProtected, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookCoversTable extends BookCovers
    with TableInfo<$BookCoversTable, BookCover> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookCoversTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<Uint8List> image = GeneratedColumn<Uint8List>(
    'image',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, image];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_covers';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookCover> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    } else if (isInserting) {
      context.missing(_imageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  BookCover map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookCover(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}image'],
      )!,
    );
  }

  @override
  $BookCoversTable createAlias(String alias) {
    return $BookCoversTable(attachedDatabase, alias);
  }
}

class BookCover extends DataClass implements Insertable<BookCover> {
  final String bookId;

  /// PNG, 360 px wide, page 1.
  final Uint8List image;
  const BookCover({required this.bookId, required this.image});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['image'] = Variable<Uint8List>(image);
    return map;
  }

  BookCoversCompanion toCompanion(bool nullToAbsent) {
    return BookCoversCompanion(bookId: Value(bookId), image: Value(image));
  }

  factory BookCover.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookCover(
      bookId: serializer.fromJson<String>(json['bookId']),
      image: serializer.fromJson<Uint8List>(json['image']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'image': serializer.toJson<Uint8List>(image),
    };
  }

  BookCover copyWith({String? bookId, Uint8List? image}) =>
      BookCover(bookId: bookId ?? this.bookId, image: image ?? this.image);
  BookCover copyWithCompanion(BookCoversCompanion data) {
    return BookCover(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      image: data.image.present ? data.image.value : this.image,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookCover(')
          ..write('bookId: $bookId, ')
          ..write('image: $image')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, $driftBlobEquality.hash(image));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookCover &&
          other.bookId == this.bookId &&
          $driftBlobEquality.equals(other.image, this.image));
}

class BookCoversCompanion extends UpdateCompanion<BookCover> {
  final Value<String> bookId;
  final Value<Uint8List> image;
  final Value<int> rowid;
  const BookCoversCompanion({
    this.bookId = const Value.absent(),
    this.image = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookCoversCompanion.insert({
    required String bookId,
    required Uint8List image,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       image = Value(image);
  static Insertable<BookCover> custom({
    Expression<String>? bookId,
    Expression<Uint8List>? image,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (image != null) 'image': image,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookCoversCompanion copyWith({
    Value<String>? bookId,
    Value<Uint8List>? image,
    Value<int>? rowid,
  }) {
    return BookCoversCompanion(
      bookId: bookId ?? this.bookId,
      image: image ?? this.image,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (image.present) {
      map['image'] = Variable<Uint8List>(image.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookCoversCompanion(')
          ..write('bookId: $bookId, ')
          ..write('image: $image, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _currentPageMeta = const VerificationMeta(
    'currentPage',
  );
  @override
  late final GeneratedColumn<int> currentPage = GeneratedColumn<int>(
    'current_page',
    aliasedName,
    false,
    check: () => ComparableExpr(currentPage).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, currentPage, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('current_page')) {
      context.handle(
        _currentPageMeta,
        currentPage.isAcceptableOrUnknown(
          data['current_page']!,
          _currentPageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentPageMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressData(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      currentPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_page'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressData extends DataClass
    implements Insertable<ReadingProgressData> {
  final String bookId;

  /// 1-based; 1 ≤ currentPage ≤ pageCount (enforced by the repository).
  final int currentPage;
  final DateTime updatedAt;
  const ReadingProgressData({
    required this.bookId,
    required this.currentPage,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['current_page'] = Variable<int>(currentPage);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      bookId: Value(bookId),
      currentPage: Value(currentPage),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressData(
      bookId: serializer.fromJson<String>(json['bookId']),
      currentPage: serializer.fromJson<int>(json['currentPage']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'currentPage': serializer.toJson<int>(currentPage),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressData copyWith({
    String? bookId,
    int? currentPage,
    DateTime? updatedAt,
  }) => ReadingProgressData(
    bookId: bookId ?? this.bookId,
    currentPage: currentPage ?? this.currentPage,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressData copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      currentPage: data.currentPage.present
          ? data.currentPage.value
          : this.currentPage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressData(')
          ..write('bookId: $bookId, ')
          ..write('currentPage: $currentPage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, currentPage, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressData &&
          other.bookId == this.bookId &&
          other.currentPage == this.currentPage &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressData> {
  final Value<String> bookId;
  final Value<int> currentPage;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingProgressCompanion({
    this.bookId = const Value.absent(),
    this.currentPage = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    required String bookId,
    required int currentPage,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       currentPage = Value(currentPage),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingProgressData> custom({
    Expression<String>? bookId,
    Expression<int>? currentPage,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (currentPage != null) 'current_page': currentPage,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<String>? bookId,
    Value<int>? currentPage,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReadingProgressCompanion(
      bookId: bookId ?? this.bookId,
      currentPage: currentPage ?? this.currentPage,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (currentPage.present) {
      map['current_page'] = Variable<int>(currentPage.value);
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
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('bookId: $bookId, ')
          ..write('currentPage: $currentPage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryPreferencesTable extends LibraryPreferences
    with TableInfo<$LibraryPreferencesTable, LibraryPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SortOrder, String> sortOrder =
      GeneratedColumn<String>(
        'sort_order',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(SortOrder.recentlyOpened.name),
      ).withConverter<SortOrder>($LibraryPreferencesTable.$convertersortOrder);
  @override
  late final GeneratedColumnWithTypeConverter<ViewMode, String> viewMode =
      GeneratedColumn<String>(
        'view_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(ViewMode.grid.name),
      ).withConverter<ViewMode>($LibraryPreferencesTable.$converterviewMode);
  static const VerificationMeta _webStorageNoticeShownMeta =
      const VerificationMeta('webStorageNoticeShown');
  @override
  late final GeneratedColumn<bool> webStorageNoticeShown =
      GeneratedColumn<bool>(
        'web_storage_notice_shown',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("web_storage_notice_shown" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sortOrder,
    viewMode,
    webStorageNoticeShown,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('web_storage_notice_shown')) {
      context.handle(
        _webStorageNoticeShownMeta,
        webStorageNoticeShown.isAcceptableOrUnknown(
          data['web_storage_notice_shown']!,
          _webStorageNoticeShownMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sortOrder: $LibraryPreferencesTable.$convertersortOrder.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sort_order'],
        )!,
      ),
      viewMode: $LibraryPreferencesTable.$converterviewMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}view_mode'],
        )!,
      ),
      webStorageNoticeShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}web_storage_notice_shown'],
      )!,
    );
  }

  @override
  $LibraryPreferencesTable createAlias(String alias) {
    return $LibraryPreferencesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SortOrder, String, String> $convertersortOrder =
      const EnumNameConverter<SortOrder>(SortOrder.values);
  static JsonTypeConverter2<ViewMode, String, String> $converterviewMode =
      const EnumNameConverter<ViewMode>(ViewMode.values);
}

class LibraryPreference extends DataClass
    implements Insertable<LibraryPreference> {
  final int id;
  final SortOrder sortOrder;
  final ViewMode viewMode;
  final bool webStorageNoticeShown;
  const LibraryPreference({
    required this.id,
    required this.sortOrder,
    required this.viewMode,
    required this.webStorageNoticeShown,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['sort_order'] = Variable<String>(
        $LibraryPreferencesTable.$convertersortOrder.toSql(sortOrder),
      );
    }
    {
      map['view_mode'] = Variable<String>(
        $LibraryPreferencesTable.$converterviewMode.toSql(viewMode),
      );
    }
    map['web_storage_notice_shown'] = Variable<bool>(webStorageNoticeShown);
    return map;
  }

  LibraryPreferencesCompanion toCompanion(bool nullToAbsent) {
    return LibraryPreferencesCompanion(
      id: Value(id),
      sortOrder: Value(sortOrder),
      viewMode: Value(viewMode),
      webStorageNoticeShown: Value(webStorageNoticeShown),
    );
  }

  factory LibraryPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryPreference(
      id: serializer.fromJson<int>(json['id']),
      sortOrder: $LibraryPreferencesTable.$convertersortOrder.fromJson(
        serializer.fromJson<String>(json['sortOrder']),
      ),
      viewMode: $LibraryPreferencesTable.$converterviewMode.fromJson(
        serializer.fromJson<String>(json['viewMode']),
      ),
      webStorageNoticeShown: serializer.fromJson<bool>(
        json['webStorageNoticeShown'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sortOrder': serializer.toJson<String>(
        $LibraryPreferencesTable.$convertersortOrder.toJson(sortOrder),
      ),
      'viewMode': serializer.toJson<String>(
        $LibraryPreferencesTable.$converterviewMode.toJson(viewMode),
      ),
      'webStorageNoticeShown': serializer.toJson<bool>(webStorageNoticeShown),
    };
  }

  LibraryPreference copyWith({
    int? id,
    SortOrder? sortOrder,
    ViewMode? viewMode,
    bool? webStorageNoticeShown,
  }) => LibraryPreference(
    id: id ?? this.id,
    sortOrder: sortOrder ?? this.sortOrder,
    viewMode: viewMode ?? this.viewMode,
    webStorageNoticeShown: webStorageNoticeShown ?? this.webStorageNoticeShown,
  );
  LibraryPreference copyWithCompanion(LibraryPreferencesCompanion data) {
    return LibraryPreference(
      id: data.id.present ? data.id.value : this.id,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      viewMode: data.viewMode.present ? data.viewMode.value : this.viewMode,
      webStorageNoticeShown: data.webStorageNoticeShown.present
          ? data.webStorageNoticeShown.value
          : this.webStorageNoticeShown,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryPreference(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('viewMode: $viewMode, ')
          ..write('webStorageNoticeShown: $webStorageNoticeShown')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sortOrder, viewMode, webStorageNoticeShown);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryPreference &&
          other.id == this.id &&
          other.sortOrder == this.sortOrder &&
          other.viewMode == this.viewMode &&
          other.webStorageNoticeShown == this.webStorageNoticeShown);
}

class LibraryPreferencesCompanion extends UpdateCompanion<LibraryPreference> {
  final Value<int> id;
  final Value<SortOrder> sortOrder;
  final Value<ViewMode> viewMode;
  final Value<bool> webStorageNoticeShown;
  const LibraryPreferencesCompanion({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.viewMode = const Value.absent(),
    this.webStorageNoticeShown = const Value.absent(),
  });
  LibraryPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.viewMode = const Value.absent(),
    this.webStorageNoticeShown = const Value.absent(),
  });
  static Insertable<LibraryPreference> custom({
    Expression<int>? id,
    Expression<String>? sortOrder,
    Expression<String>? viewMode,
    Expression<bool>? webStorageNoticeShown,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (viewMode != null) 'view_mode': viewMode,
      if (webStorageNoticeShown != null)
        'web_storage_notice_shown': webStorageNoticeShown,
    });
  }

  LibraryPreferencesCompanion copyWith({
    Value<int>? id,
    Value<SortOrder>? sortOrder,
    Value<ViewMode>? viewMode,
    Value<bool>? webStorageNoticeShown,
  }) {
    return LibraryPreferencesCompanion(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      viewMode: viewMode ?? this.viewMode,
      webStorageNoticeShown:
          webStorageNoticeShown ?? this.webStorageNoticeShown,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<String>(
        $LibraryPreferencesTable.$convertersortOrder.toSql(sortOrder.value),
      );
    }
    if (viewMode.present) {
      map['view_mode'] = Variable<String>(
        $LibraryPreferencesTable.$converterviewMode.toSql(viewMode.value),
      );
    }
    if (webStorageNoticeShown.present) {
      map['web_storage_notice_shown'] = Variable<bool>(
        webStorageNoticeShown.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('viewMode: $viewMode, ')
          ..write('webStorageNoticeShown: $webStorageNoticeShown')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $BookCoversTable bookCovers = $BookCoversTable(this);
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  late final $LibraryPreferencesTable libraryPreferences =
      $LibraryPreferencesTable(this);
  late final Index booksLastOpenedAt = Index(
    'books_last_opened_at',
    'CREATE INDEX books_last_opened_at ON books (last_opened_at)',
  );
  late final Index booksAddedAt = Index(
    'books_added_at',
    'CREATE INDEX books_added_at ON books (added_at)',
  );
  late final Index booksSortTitle = Index(
    'books_sort_title',
    'CREATE INDEX books_sort_title ON books (sort_title)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    bookCovers,
    readingProgress,
    libraryPreferences,
    booksLastOpenedAt,
    booksAddedAt,
    booksSortTitle,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_covers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_progress', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  required String id,
  required String format,
  required String title,
  Value<String?> author,
  required String sortTitle,
  required String searchKey,
  required String originalFileName,
  required String contentHash,
  required int sizeBytes,
  required int pageCount,
  required bool isPasswordProtected,
  required DateTime addedAt,
  Value<DateTime?> lastOpenedAt,
  Value<int> rowid,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<String> id,
  Value<String> format,
  Value<String> title,
  Value<String?> author,
  Value<String> sortTitle,
  Value<String> searchKey,
  Value<String> originalFileName,
  Value<String> contentHash,
  Value<int> sizeBytes,
  Value<int> pageCount,
  Value<bool> isPasswordProtected,
  Value<DateTime> addedAt,
  Value<DateTime?> lastOpenedAt,
  Value<int> rowid,
});

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, Book> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BookCoversTable, List<BookCover>>
  _bookCoversRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookCovers,
    aliasName: 'books__id__book_covers__book_id',
  );

  $$BookCoversTableProcessedTableManager get bookCoversRefs {
    final manager = $$BookCoversTableTableManager(
      $_db,
      $_db.bookCovers,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookCoversRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReadingProgressTable, List<ReadingProgressData>>
  _readingProgressRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.readingProgress,
    aliasName: 'books__id__reading_progress__book_id',
  );

  $$ReadingProgressTableProcessedTableManager get readingProgressRefs {
    final manager = $$ReadingProgressTableTableManager(
      $_db,
      $_db.readingProgress,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingProgressRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
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

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortTitle => $composableBuilder(
    column: $table.sortTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchKey => $composableBuilder(
    column: $table.searchKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalFileName => $composableBuilder(
    column: $table.originalFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPasswordProtected => $composableBuilder(
    column: $table.isPasswordProtected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bookCoversRefs(
    Expression<bool> Function($$BookCoversTableFilterComposer f) f,
  ) {
    final $$BookCoversTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookCovers,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookCoversTableFilterComposer(
            $db: $db,
            $table: $db.bookCovers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingProgressRefs(
    Expression<bool> Function($$ReadingProgressTableFilterComposer f) f,
  ) {
    final $$ReadingProgressTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgress,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressTableFilterComposer(
            $db: $db,
            $table: $db.readingProgress,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
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

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortTitle => $composableBuilder(
    column: $table.sortTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchKey => $composableBuilder(
    column: $table.searchKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalFileName => $composableBuilder(
    column: $table.originalFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPasswordProtected => $composableBuilder(
    column: $table.isPasswordProtected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get sortTitle =>
      $composableBuilder(column: $table.sortTitle, builder: (column) => column);

  GeneratedColumn<String> get searchKey =>
      $composableBuilder(column: $table.searchKey, builder: (column) => column);

  GeneratedColumn<String> get originalFileName => $composableBuilder(
    column: $table.originalFileName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<bool> get isPasswordProtected => $composableBuilder(
    column: $table.isPasswordProtected,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  Expression<T> bookCoversRefs<T extends Object>(
    Expression<T> Function($$BookCoversTableAnnotationComposer a) f,
  ) {
    final $$BookCoversTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookCovers,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookCoversTableAnnotationComposer(
            $db: $db,
            $table: $db.bookCovers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingProgressRefs<T extends Object>(
    Expression<T> Function($$ReadingProgressTableAnnotationComposer a) f,
  ) {
    final $$ReadingProgressTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgress,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressTableAnnotationComposer(
            $db: $db,
            $table: $db.readingProgress,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, $$BooksTableReferences),
          Book,
          PrefetchHooks Function({
            bool bookCoversRefs,
            bool readingProgressRefs,
          })
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> sortTitle = const Value.absent(),
                Value<String> searchKey = const Value.absent(),
                Value<String> originalFileName = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<bool> isPasswordProtected = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                format: format,
                title: title,
                author: author,
                sortTitle: sortTitle,
                searchKey: searchKey,
                originalFileName: originalFileName,
                contentHash: contentHash,
                sizeBytes: sizeBytes,
                pageCount: pageCount,
                isPasswordProtected: isPasswordProtected,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String format,
                required String title,
                Value<String?> author = const Value.absent(),
                required String sortTitle,
                required String searchKey,
                required String originalFileName,
                required String contentHash,
                required int sizeBytes,
                required int pageCount,
                required bool isPasswordProtected,
                required DateTime addedAt,
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                format: format,
                title: title,
                author: author,
                sortTitle: sortTitle,
                searchKey: searchKey,
                originalFileName: originalFileName,
                contentHash: contentHash,
                sizeBytes: sizeBytes,
                pageCount: pageCount,
                isPasswordProtected: isPasswordProtected,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, Book>(table),
                  $$BooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bookCoversRefs = false, readingProgressRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bookCoversRefs) db.bookCovers,
                    if (readingProgressRefs) db.readingProgress,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bookCoversRefs)
                        await $_getPrefetchedData<Book, $BooksTable, BookCover>(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._bookCoversRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookCoversRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingProgressRefs)
                        await $_getPrefetchedData<
                          Book,
                          $BooksTable,
                          ReadingProgressData
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._readingProgressRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).readingProgressRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
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

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, $$BooksTableReferences),
      Book,
      PrefetchHooks Function({bool bookCoversRefs, bool readingProgressRefs})
    >;
typedef $$BookCoversTableCreateCompanionBuilder = BookCoversCompanion Function({
  required String bookId,
  required Uint8List image,
  Value<int> rowid,
});
typedef $$BookCoversTableUpdateCompanionBuilder = BookCoversCompanion Function({
  Value<String> bookId,
  Value<Uint8List> image,
  Value<int> rowid,
});

final class $$BookCoversTableReferences
    extends BaseReferences<_$AppDatabase, $BookCoversTable, BookCover> {
  $$BookCoversTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('book_covers__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookCoversTableFilterComposer
    extends Composer<_$AppDatabase, $BookCoversTable> {
  $$BookCoversTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookCoversTableOrderingComposer
    extends Composer<_$AppDatabase, $BookCoversTable> {
  $$BookCoversTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookCoversTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookCoversTable> {
  $$BookCoversTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookCoversTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookCoversTable,
          BookCover,
          $$BookCoversTableFilterComposer,
          $$BookCoversTableOrderingComposer,
          $$BookCoversTableAnnotationComposer,
          $$BookCoversTableCreateCompanionBuilder,
          $$BookCoversTableUpdateCompanionBuilder,
          (BookCover, $$BookCoversTableReferences),
          BookCover,
          PrefetchHooks Function({bool bookId})
        > {
  $$BookCoversTableTableManager(_$AppDatabase db, $BookCoversTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookCoversTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookCoversTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookCoversTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> bookId = const Value.absent(),
            Value<Uint8List> image = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => BookCoversCompanion(bookId: bookId, image: image, rowid: rowid),
          createCompanionCallback:
              ({
                required String bookId,
                required Uint8List image,
                Value<int> rowid = const Value.absent(),
              }) => BookCoversCompanion.insert(
                bookId: bookId,
                image: image,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookCoversTable, BookCover>(table),
                  $$BookCoversTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
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
                    if (bookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bookId,
                        referencedTable: $$BookCoversTableReferences
                            ._bookIdTable(db),
                        referencedColumn: $$BookCoversTableReferences
                            ._bookIdTable(db)
                            .id,
                      ) as T;
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

typedef $$BookCoversTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookCoversTable,
      BookCover,
      $$BookCoversTableFilterComposer,
      $$BookCoversTableOrderingComposer,
      $$BookCoversTableAnnotationComposer,
      $$BookCoversTableCreateCompanionBuilder,
      $$BookCoversTableUpdateCompanionBuilder,
      (BookCover, $$BookCoversTableReferences),
      BookCover,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      required String bookId,
      required int currentPage,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<String> bookId,
      Value<int> currentPage,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ReadingProgressTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData
        > {
  $$ReadingProgressTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('reading_progress__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (ReadingProgressData, $$ReadingProgressTableReferences),
          ReadingProgressData,
          PrefetchHooks Function({bool bookId})
        > {
  $$ReadingProgressTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> currentPage = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion(
                bookId: bookId,
                currentPage: currentPage,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required int currentPage,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                bookId: bookId,
                currentPage: currentPage,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingProgressTable, ReadingProgressData>(
                    table,
                  ),
                  $$ReadingProgressTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
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
                    if (bookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bookId,
                        referencedTable: $$ReadingProgressTableReferences
                            ._bookIdTable(db),
                        referencedColumn: $$ReadingProgressTableReferences
                            ._bookIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTable,
      ReadingProgressData,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (ReadingProgressData, $$ReadingProgressTableReferences),
      ReadingProgressData,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$LibraryPreferencesTableCreateCompanionBuilder =
    LibraryPreferencesCompanion Function({
      Value<int> id,
      Value<SortOrder> sortOrder,
      Value<ViewMode> viewMode,
      Value<bool> webStorageNoticeShown,
    });
typedef $$LibraryPreferencesTableUpdateCompanionBuilder =
    LibraryPreferencesCompanion Function({
      Value<int> id,
      Value<SortOrder> sortOrder,
      Value<ViewMode> viewMode,
      Value<bool> webStorageNoticeShown,
    });

class $$LibraryPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryPreferencesTable> {
  $$LibraryPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SortOrder, SortOrder, String> get sortOrder =>
      $composableBuilder(
        column: $table.sortOrder,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<ViewMode, ViewMode, String> get viewMode =>
      $composableBuilder(
        column: $table.viewMode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get webStorageNoticeShown => $composableBuilder(
    column: $table.webStorageNoticeShown,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryPreferencesTable> {
  $$LibraryPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewMode => $composableBuilder(
    column: $table.viewMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get webStorageNoticeShown => $composableBuilder(
    column: $table.webStorageNoticeShown,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryPreferencesTable> {
  $$LibraryPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SortOrder, String> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ViewMode, String> get viewMode =>
      $composableBuilder(column: $table.viewMode, builder: (column) => column);

  GeneratedColumn<bool> get webStorageNoticeShown => $composableBuilder(
    column: $table.webStorageNoticeShown,
    builder: (column) => column,
  );
}

class $$LibraryPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryPreferencesTable,
          LibraryPreference,
          $$LibraryPreferencesTableFilterComposer,
          $$LibraryPreferencesTableOrderingComposer,
          $$LibraryPreferencesTableAnnotationComposer,
          $$LibraryPreferencesTableCreateCompanionBuilder,
          $$LibraryPreferencesTableUpdateCompanionBuilder,
          (
            LibraryPreference,
            BaseReferences<
              _$AppDatabase,
              $LibraryPreferencesTable,
              LibraryPreference
            >,
          ),
          LibraryPreference,
          PrefetchHooks Function()
        > {
  $$LibraryPreferencesTableTableManager(
    _$AppDatabase db,
    $LibraryPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<SortOrder> sortOrder = const Value.absent(),
                Value<ViewMode> viewMode = const Value.absent(),
                Value<bool> webStorageNoticeShown = const Value.absent(),
              }) => LibraryPreferencesCompanion(
                id: id,
                sortOrder: sortOrder,
                viewMode: viewMode,
                webStorageNoticeShown: webStorageNoticeShown,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<SortOrder> sortOrder = const Value.absent(),
                Value<ViewMode> viewMode = const Value.absent(),
                Value<bool> webStorageNoticeShown = const Value.absent(),
              }) => LibraryPreferencesCompanion.insert(
                id: id,
                sortOrder: sortOrder,
                viewMode: viewMode,
                webStorageNoticeShown: webStorageNoticeShown,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryPreferencesTable, LibraryPreference>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LibraryPreferencesTable,
                    LibraryPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryPreferencesTable,
      LibraryPreference,
      $$LibraryPreferencesTableFilterComposer,
      $$LibraryPreferencesTableOrderingComposer,
      $$LibraryPreferencesTableAnnotationComposer,
      $$LibraryPreferencesTableCreateCompanionBuilder,
      $$LibraryPreferencesTableUpdateCompanionBuilder,
      (
        LibraryPreference,
        BaseReferences<
          _$AppDatabase,
          $LibraryPreferencesTable,
          LibraryPreference
        >,
      ),
      LibraryPreference,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$BookCoversTableTableManager get bookCovers =>
      $$BookCoversTableTableManager(_db, _db.bookCovers);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$LibraryPreferencesTableTableManager get libraryPreferences =>
      $$LibraryPreferencesTableTableManager(_db, _db.libraryPreferences);
}
