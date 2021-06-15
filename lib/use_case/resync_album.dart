import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/app_db.dart';
import 'package:nc_photos/entity/album.dart';
import 'package:nc_photos/entity/file_util.dart' as file_util;

/// Resync files inside an album with the file db
class ResyncAlbum {
  Future<Album> call(Account account, Album album) async {
    return await AppDb.use((db) async {
      final transaction =
          db.transaction(AppDb.fileDbStoreName, idbModeReadWrite);
      final store = transaction.objectStore(AppDb.fileDbStoreName);
      final index = store.index(AppDbFileDbEntry.indexName);
      final newItems = <AlbumItem>[];
      for (final item in album.items) {
        if (item is AlbumFileItem) {
          try {
            newItems.add(await _syncOne(account, item, store, index));
          } catch (e, stacktrace) {
            _log.shout(
                "[call] Failed syncing file in album" +
                    (kDebugMode ? ": '${item.file.path}'" : ""),
                e,
                stacktrace);
          }
        } else {
          newItems.add(item);
        }
      }
      return album.copyWith(items: newItems);
    });
  }

  Future<AlbumFileItem> _syncOne(Account account, AlbumFileItem item,
      ObjectStore objStore, Index index) async {
    Map dbItem;
    if (item.file.fileId != null) {
      final List dbItems = await index
          .getAll(AppDbFileDbEntry.toNamespacedFileId(account, item.file));
      // find the one owned by us
      dbItem = dbItems.firstWhere((element) {
        final e = AppDbFileDbEntry.fromJson(element.cast<String, dynamic>());
        return file_util.getUserDirName(e.file) == account.username;
      }, orElse: () => null);
    } else {
      dbItem = await objStore
          .getObject(AppDbFileDbEntry.toPrimaryKey(account, item.file));
    }
    if (dbItem == null) {
      _log.warning(
          "[_syncOne] File doesn't exist in DB, removed?: '${item.file.path}'");
      return item;
    }
    final dbEntry = AppDbFileDbEntry.fromJson(dbItem.cast<String, dynamic>());
    return AlbumFileItem(file: dbEntry.file);
  }

  static final _log = Logger("use_case.resync_album.ResyncAlbum");
}