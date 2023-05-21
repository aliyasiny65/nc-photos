import 'package:nc_photos/entity/collection_item.dart';
import 'package:nc_photos/entity/file_descriptor.dart';
import 'package:to_string/to_string.dart';

part 'new_item.g.dart';

abstract class NewCollectionItem implements CollectionItem {}

/// A new [CollectionFileItem]
///
/// This class is for marking an intermediate item that has recently been added
/// but not necessarily persisted yet to the provider of this collection
@toString
class NewCollectionFileItem implements CollectionFileItem, NewCollectionItem {
  const NewCollectionFileItem(this.file);

  @override
  String toString() => _$toString();

  @override
  final FileDescriptor file;
}

/// A new [CollectionLabelItem]
///
/// This class is for marking an intermediate item that has recently been added
/// but not necessarily persisted yet to the provider of this collection
@toString
class NewCollectionLabelItem implements CollectionLabelItem, NewCollectionItem {
  const NewCollectionLabelItem(this.text, this.createdAt);

  @override
  String toString() => _$toString();

  @override
  Object get id => createdAt;

  @override
  final String text;

  final DateTime createdAt;
}
