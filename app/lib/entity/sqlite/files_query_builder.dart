import 'package:drift/drift.dart';
import 'package:nc_photos/account.dart' as app;
import 'package:nc_photos/ci_string.dart';
import 'package:nc_photos/entity/sqlite/database.dart';
import 'package:nc_photos/location_util.dart' as location_util;

enum FilesQueryMode {
  file,
  completeFile,
  expression,
}

typedef FilesQueryRelativePathBuilder = Expression<bool?> Function(
    GeneratedColumn<String?> relativePath);

/// Build a Files table query
///
/// If you call more than one by* methods, the condition will be added up
/// instead of replaced. No validations will be made to make sure the resulting
/// conditions make sense
class FilesQueryBuilder {
  FilesQueryBuilder(this.db);

  /// Set the query mode
  ///
  /// If [mode] == FilesQueryMode.expression, [expressions] must be defined and
  /// not empty
  void setQueryMode(
    FilesQueryMode mode, {
    Iterable<Expression>? expressions,
  }) {
    assert(
        (mode == FilesQueryMode.expression) != (expressions?.isEmpty != false));
    _queryMode = mode;
    _selectExpressions = expressions;
  }

  void setSqlAccount(Account account) {
    assert(_appAccount == null);
    _sqlAccount = account;
  }

  void setAppAccount(app.Account account) {
    assert(_sqlAccount == null);
    _appAccount = account;
  }

  void setAccountless() {
    assert(_sqlAccount == null && _appAccount == null);
    _isAccountless = true;
  }

  void byRowId(int rowId) {
    _byRowId = rowId;
  }

  void byFileId(int fileId) {
    _byFileId = fileId;
  }

  void byFileIds(Iterable<int> fileIds) {
    _byFileIds = fileIds;
  }

  void byRelativePath(String path) {
    _byRelativePath = path;
  }

  void byOrRelativePath(String path) {
    _byOrRelativePathBuilder((relativePath) => relativePath.equals(path));
  }

  void byOrRelativePathPattern(String pattern) {
    _byOrRelativePathBuilder((relativePath) => relativePath.like(pattern));
  }

  void byMimePattern(String pattern) {
    (_byMimePatterns ??= []).add(pattern);
  }

  void byFavorite(bool favorite) {
    _byFavorite = favorite;
  }

  void byDirRowId(int dirRowId) {
    _byDirRowId = dirRowId;
  }

  void byServerRowId(int serverRowId) {
    _byServerRowId = serverRowId;
  }

  void byLocation(String location) {
    _byLocation = location;
  }

  JoinedSelectStatement build() {
    if (_sqlAccount == null && _appAccount == null && !_isAccountless) {
      throw StateError("Invalid query: missing account");
    }
    final dynamic select = _queryMode == FilesQueryMode.expression
        ? db.selectOnly(db.files)
        : db.select(db.files);
    final query = select.join([
      innerJoin(db.accountFiles, db.accountFiles.file.equalsExp(db.files.rowId),
          useColumns: _queryMode == FilesQueryMode.completeFile),
      if (_appAccount != null) ...[
        innerJoin(
            db.accounts, db.accounts.rowId.equalsExp(db.accountFiles.account),
            useColumns: false),
        innerJoin(db.servers, db.servers.rowId.equalsExp(db.accounts.server),
            useColumns: false),
      ],
      if (_byDirRowId != null)
        innerJoin(db.dirFiles, db.dirFiles.child.equalsExp(db.files.rowId),
            useColumns: false),
      if (_queryMode == FilesQueryMode.completeFile) ...[
        leftOuterJoin(
            db.images, db.images.accountFile.equalsExp(db.accountFiles.rowId)),
        leftOuterJoin(db.imageLocations,
            db.imageLocations.accountFile.equalsExp(db.accountFiles.rowId)),
        leftOuterJoin(db.trashes, db.trashes.file.equalsExp(db.files.rowId)),
      ],
    ]) as JoinedSelectStatement;
    if (_queryMode == FilesQueryMode.expression) {
      query.addColumns(_selectExpressions!);
    }

    if (_sqlAccount != null) {
      query.where(db.accountFiles.account.equals(_sqlAccount!.rowId));
    } else if (_appAccount != null) {
      query
        ..where(db.servers.address.equals(_appAccount!.url))
        ..where(db.accounts.userId
            .equals(_appAccount!.userId.toCaseInsensitiveString()));
    }

    if (_byRowId != null) {
      query.where(db.files.rowId.equals(_byRowId));
    }
    if (_byFileId != null) {
      query.where(db.files.fileId.equals(_byFileId));
    }
    if (_byFileIds != null) {
      query.where(db.files.fileId.isIn(_byFileIds!));
    }
    if (_byRelativePath != null) {
      query.where(db.accountFiles.relativePath.equals(_byRelativePath));
    }
    if (_byOrRelativePathBuilders?.isNotEmpty == true) {
      final expression = _byOrRelativePathBuilders!
          .sublist(1)
          .fold<Expression<bool?>>(
              _byOrRelativePathBuilders![0](db.accountFiles.relativePath),
              (previousValue, builder) =>
                  previousValue | builder(db.accountFiles.relativePath));
      query.where(expression);
    }
    if (_byMimePatterns?.isNotEmpty == true) {
      final expression = _byMimePatterns!.sublist(1).fold<Expression<bool?>>(
          db.files.contentType.like(_byMimePatterns![0]),
          (previousValue, element) =>
              previousValue | db.files.contentType.like(element));
      query.where(expression);
    }
    if (_byFavorite != null) {
      if (_byFavorite!) {
        query.where(db.accountFiles.isFavorite.equals(true));
      } else {
        // null are treated as false
        query.where(db.accountFiles.isFavorite.equals(true).not());
      }
    }
    if (_byDirRowId != null) {
      query.where(db.dirFiles.dir.equals(_byDirRowId));
    }
    if (_byServerRowId != null) {
      query.where(db.files.server.equals(_byServerRowId));
    }
    if (_byLocation != null) {
      var clause = db.imageLocations.name.like(_byLocation!) |
          db.imageLocations.admin1.like(_byLocation!) |
          db.imageLocations.admin2.like(_byLocation!);
      final countryCode = location_util.nameToAlpha2Code(_byLocation!.toCi());
      if (countryCode != null) {
        clause = clause | db.imageLocations.countryCode.equals(countryCode);
      } else if (_byLocation!.length == 2 &&
          location_util.alpha2CodeToName(_byLocation!.toUpperCase()) != null) {
        clause = clause |
            db.imageLocations.countryCode.equals(_byLocation!.toUpperCase());
      }
      query.where(clause);
    }
    return query;
  }

  void _byOrRelativePathBuilder(FilesQueryRelativePathBuilder builder) {
    (_byOrRelativePathBuilders ??= []).add(builder);
  }

  final SqliteDb db;

  FilesQueryMode _queryMode = FilesQueryMode.file;
  Iterable<Expression>? _selectExpressions;

  Account? _sqlAccount;
  app.Account? _appAccount;
  bool _isAccountless = false;

  int? _byRowId;
  int? _byFileId;
  Iterable<int>? _byFileIds;
  String? _byRelativePath;
  List<FilesQueryRelativePathBuilder>? _byOrRelativePathBuilders;
  List<String>? _byMimePatterns;
  bool? _byFavorite;
  int? _byDirRowId;
  int? _byServerRowId;
  String? _byLocation;
}
