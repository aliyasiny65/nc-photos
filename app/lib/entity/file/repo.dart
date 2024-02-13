import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/entity/file_descriptor.dart';
import 'package:np_codegen/np_codegen.dart';
import 'package:np_common/or_null.dart';

part 'repo.g.dart';

abstract class FileRepo2 {
  /// Query all files belonging to [account]
  ///
  /// Returned files are sorted by time in descending order
  ///
  /// Normally the stream should complete with only a single event, but some
  /// implementation might want to return multiple set of values, say one set of
  /// cached value and later another set of updated value from a remote source.
  /// In any case, each event is guaranteed to be one complete set of data
  Stream<List<FileDescriptor>> getFileDescriptors(
      Account account, String shareDirPath);

  Future<void> updateProperty(
    Account account,
    FileDescriptor f, {
    OrNull<Metadata>? metadata,
    OrNull<bool>? isArchived,
    OrNull<DateTime>? overrideDateTime,
    bool? favorite,
    OrNull<ImageLocation>? location,
  });

  Future<void> remove(Account account, FileDescriptor f);
}

/// A repo that simply relay the call to the backed [FileDataSource]
@npLog
class BasicFileRepo implements FileRepo2 {
  const BasicFileRepo(this.dataSrc);

  @override
  Stream<List<FileDescriptor>> getFileDescriptors(
          Account account, String shareDirPath) =>
      dataSrc.getFileDescriptors(account, shareDirPath);

  @override
  Future<void> updateProperty(
    Account account,
    FileDescriptor f, {
    OrNull<Metadata>? metadata,
    OrNull<bool>? isArchived,
    OrNull<DateTime>? overrideDateTime,
    bool? favorite,
    OrNull<ImageLocation>? location,
  }) =>
      dataSrc.updateProperty(
        account,
        f,
        metadata: metadata,
        isArchived: isArchived,
        overrideDateTime: overrideDateTime,
        favorite: favorite,
        location: location,
      );

  @override
  Future<void> remove(Account account, FileDescriptor f) =>
      dataSrc.remove(account, f);

  final FileDataSource2 dataSrc;
}

/// A repo that manage a remote data source and a cache data source
@npLog
class CachedFileRepo implements FileRepo2 {
  const CachedFileRepo(this.remoteDataSrc, this.cacheDataSrc);

  @override
  Stream<List<FileDescriptor>> getFileDescriptors(
          Account account, String shareDirPath) =>
      cacheDataSrc.getFileDescriptors(account, shareDirPath);

  @override
  Future<void> updateProperty(
    Account account,
    FileDescriptor f, {
    OrNull<Metadata>? metadata,
    OrNull<bool>? isArchived,
    OrNull<DateTime>? overrideDateTime,
    bool? favorite,
    OrNull<ImageLocation>? location,
  }) async {
    await remoteDataSrc.updateProperty(
      account,
      f,
      metadata: metadata,
      isArchived: isArchived,
      overrideDateTime: overrideDateTime,
      favorite: favorite,
      location: location,
    );
    try {
      await cacheDataSrc.updateProperty(
        account,
        f,
        metadata: metadata,
        isArchived: isArchived,
        overrideDateTime: overrideDateTime,
        favorite: favorite,
        location: location,
      );
    } catch (e, stackTrace) {
      _log.warning("[updateProperty] Failed to update cache", e, stackTrace);
    }
  }

  @override
  Future<void> remove(Account account, FileDescriptor f) async {
    await remoteDataSrc.remove(account, f);
    try {
      await cacheDataSrc.remove(account, f);
    } catch (e, stackTrace) {
      _log.warning("[remove] Failed to update cache", e, stackTrace);
    }
  }

  final FileDataSource2 remoteDataSrc;
  final FileDataSource2 cacheDataSrc;
}

abstract class FileDataSource2 {
  /// Query all files belonging to [account]
  ///
  /// Returned files are sorted by time in descending order
  Stream<List<FileDescriptor>> getFileDescriptors(
      Account account, String shareDirPath);

  Future<void> updateProperty(
    Account account,
    FileDescriptor f, {
    OrNull<Metadata>? metadata,
    OrNull<bool>? isArchived,
    OrNull<DateTime>? overrideDateTime,
    bool? favorite,
    OrNull<ImageLocation>? location,
  });

  Future<void> remove(Account account, FileDescriptor f);
}
