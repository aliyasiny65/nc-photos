import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:np_codegen/np_codegen.dart';

part 'repo.g.dart';

class ImageLatLng with EquatableMixin {
  const ImageLatLng({
    required this.latitude,
    required this.longitude,
    required this.fileId,
  });

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        fileId,
      ];

  final double latitude;
  final double longitude;
  final int fileId;
}

abstract class ImageLocationRepo {
  /// Query all locations with the corresponding file ids
  ///
  /// Returned data are sorted by the file date time in descending order
  Future<List<ImageLatLng>> getLocations(Account account);
}

@npLog
class BasicImageLocationRepo implements ImageLocationRepo {
  const BasicImageLocationRepo(this.dataSrc);

  @override
  Future<List<ImageLatLng>> getLocations(Account account) =>
      dataSrc.getLocations(account);

  final ImageLocationDataSource dataSrc;
}

abstract class ImageLocationDataSource {
  /// Query all locations with the corresponding file ids
  ///
  /// Returned data are sorted by the file date time in descending order
  Future<List<ImageLatLng>> getLocations(Account account);
}
