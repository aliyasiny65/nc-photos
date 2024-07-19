import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/db/entity_converter.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/entity/file_descriptor.dart';
import 'package:nc_photos/entity/file_util.dart' as file_util;
import 'package:nc_photos/entity/image_location/repo.dart';
import 'package:nc_photos/remote_storage_util.dart' as remote_storage_util;
import 'package:np_async/np_async.dart';
import 'package:np_codegen/np_codegen.dart';
import 'package:np_db/np_db.dart';

part 'data_source.g.dart';

@npLog
class ImageLocationNpDbDataSource implements ImageLocationDataSource {
  const ImageLocationNpDbDataSource(this.db);

  @override
  Future<List<ImageLatLng>> getLocations(Account account) async {
    _log.info("[getLocations]");
    final results = await db.getImageLatLngWithFileIds(
      account: account.toDb(),
      includeRelativeRoots: account.roots
          .map((e) => File(path: file_util.unstripPath(account, e))
              .strippedPathWithEmpty)
          .toList(),
      excludeRelativeRoots: [remote_storage_util.remoteStorageDirRelativePath],
      mimes: file_util.supportedFormatMimes,
    );
    return results.computeAll(DbImageLatLngConverter.fromDb);
  }

  final NpDb db;
}
