import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/api/api_util.dart' as api_util;
import 'package:nc_photos/entity/collection.dart';
import 'package:nc_photos/entity/collection/util.dart';
import 'package:nc_photos/entity/collection_item/util.dart';
import 'package:nc_photos/entity/file_descriptor.dart';
import 'package:np_common/object_util.dart';
import 'package:to_string/to_string.dart';
import 'package:uuid/uuid.dart';

part 'ad_hoc.g.dart';

@toString
class CollectionAdHocProvider
    with EquatableMixin
    implements CollectionContentProvider {
  CollectionAdHocProvider({
    required this.account,
    required this.fileIds,
    this.cover,
  });

  @override
  String get fourCc => "ADHC";

  @override
  String get id => _id;

  @override
  int? get count => fileIds.length;

  @override
  DateTime get lastModified => clock.now();

  @override
  List<CollectionCapability> get capabilities => [
        CollectionCapability.deleteItem,
      ];

  @override
  CollectionItemSort get itemSort => CollectionItemSort.dateDescending;

  @override
  List<CollectionShare> get shares => [];

  @override
  String? getCoverUrl(
    int width,
    int height, {
    bool? isKeepAspectRatio,
  }) {
    return cover?.let((cover) => api_util.getFilePreviewUrl(
          account,
          cover,
          width: width,
          height: height,
          isKeepAspectRatio: isKeepAspectRatio ?? false,
        ));
  }

  @override
  bool get isDynamicCollection => true;

  @override
  bool get isPendingSharedAlbum => false;

  @override
  bool get isOwned => true;

  @override
  String toString() => _$toString();

  @override
  List<Object?> get props => [account, fileIds, cover];

  final Account account;
  final List<int> fileIds;
  final FileDescriptor? cover;

  late final _id = const Uuid().v4();
}
