part of '../collection_browser.dart';

abstract class _Item implements SelectableItemMetadata, DraggableItemMetadata {
  const _Item();

  StaggeredTile get staggeredTile;

  Widget buildWidget(BuildContext context);

  Widget? buildDragFeedbackWidget(BuildContext context) => null;
}

/// Items backed by an actual [CollectionItem]
abstract class _ActualItem extends _Item {
  const _ActualItem({required this.original});

  @override
  bool get isSelectable => !_isNew;

  @override
  bool get isDraggable => !_isNew;

  bool get _isNew => original is NewCollectionItem;

  final CollectionItem original;
}

abstract class _FileItem extends _ActualItem {
  const _FileItem({
    required super.original,
    required this.file,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _FileItem && file.compareServerIdentity(other.file));

  @override
  int get hashCode => file.identityHashCode;

  final FileDescriptor file;
}

class _PhotoItem extends _FileItem {
  _PhotoItem({
    required super.original,
    required super.file,
    required this.account,
  }) : _previewUrl = NetworkRectThumbnail.imageUrlForFile(account, file);

  @override
  StaggeredTile get staggeredTile => const StaggeredTile.count(1, 1);

  @override
  Widget buildWidget(BuildContext context) {
    return Opacity(
      opacity: _isNew ? .5 : 1,
      child: PhotoListImage(
        account: account,
        previewUrl: _previewUrl,
        isGif: file.fdMime == "image/gif",
        isFavorite: file.fdIsFavorite,
        heroKey: flutter_util.getImageHeroTag(file),
      ),
    );
  }

  final Account account;
  final String _previewUrl;
}

class _VideoItem extends _FileItem {
  _VideoItem({
    required super.original,
    required super.file,
    required this.account,
  }) : _previewUrl = NetworkRectThumbnail.imageUrlForFile(account, file);

  @override
  StaggeredTile get staggeredTile => const StaggeredTile.count(1, 1);

  @override
  Widget buildWidget(BuildContext context) {
    return Opacity(
      opacity: _isNew ? .5 : 1,
      child: PhotoListVideo(
        account: account,
        previewUrl: _previewUrl,
        isFavorite: file.fdIsFavorite,
      ),
    );
  }

  final Account account;
  final String _previewUrl;
}

class _LabelItem extends _ActualItem {
  const _LabelItem({
    required super.original,
    required this.id,
    required this.text,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _LabelItem && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  StaggeredTile get staggeredTile => const StaggeredTile.extent(99, 56);

  @override
  Widget buildWidget(BuildContext context) {
    return PhotoListLabel(
      text: text,
    );
  }

  final Object id;
  final String text;
}

class _EditLabelListItem extends _LabelItem {
  const _EditLabelListItem({
    required super.original,
    required super.id,
    required super.text,
    required this.onEditPressed,
  });

  @override
  bool get isDraggable => true;

  @override
  Widget buildWidget(BuildContext context) {
    return PhotoListLabelEdit(
      text: text,
      onEditPressed: onEditPressed,
    );
  }

  @override
  Widget? buildDragFeedbackWidget(BuildContext context) {
    return super.buildWidget(context);
  }

  final VoidCallback? onEditPressed;
}

class _DateItem extends _Item {
  const _DateItem({
    required this.date,
  });

  @override
  bool get isSelectable => false;

  @override
  bool get isDraggable => false;

  @override
  StaggeredTile get staggeredTile => const StaggeredTile.extent(99, 32);

  @override
  Widget buildWidget(BuildContext context) {
    return PhotoListDate(
      date: date,
    );
  }

  final DateTime date;
}

@toString
class _ArchiveFailedError implements Exception {
  const _ArchiveFailedError(this.count);

  @override
  String toString() => _$toString();

  final int count;
}

@toString
class _RemoveFailedError implements Exception {
  const _RemoveFailedError(this.count);

  @override
  String toString() => _$toString();

  final int count;
}
