// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_collections.dart';

// **************************************************************************
// CopyWithLintRuleGenerator
// **************************************************************************

// ignore_for_file: library_private_types_in_public_api, duplicate_ignore

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class $_StateCopyWithWorker {
  _State call(
      {List<Collection>? collections,
      collection_util.CollectionSort? sort,
      bool? isLoading,
      List<_Item>? transformedItems,
      Set<_Item>? selectedItems,
      ExceptionEvent? error,
      ExceptionEvent? removeError});
}

class _$_StateCopyWithWorkerImpl implements $_StateCopyWithWorker {
  _$_StateCopyWithWorkerImpl(this.that);

  @override
  _State call(
      {dynamic collections,
      dynamic sort,
      dynamic isLoading,
      dynamic transformedItems,
      dynamic selectedItems,
      dynamic error = copyWithNull,
      dynamic removeError = copyWithNull}) {
    return _State(
        collections: collections as List<Collection>? ?? that.collections,
        sort: sort as collection_util.CollectionSort? ?? that.sort,
        isLoading: isLoading as bool? ?? that.isLoading,
        transformedItems:
            transformedItems as List<_Item>? ?? that.transformedItems,
        selectedItems: selectedItems as Set<_Item>? ?? that.selectedItems,
        error: error == copyWithNull ? that.error : error as ExceptionEvent?,
        removeError: removeError == copyWithNull
            ? that.removeError
            : removeError as ExceptionEvent?);
  }

  final _State that;
}

extension $_StateCopyWith on _State {
  $_StateCopyWithWorker get copyWith => _$copyWith;
  $_StateCopyWithWorker get _$copyWith => _$_StateCopyWithWorkerImpl(this);
}

// **************************************************************************
// NpLogGenerator
// **************************************************************************

extension _$_WrappedHomeCollectionsStateNpLog on _WrappedHomeCollectionsState {
  // ignore: unused_element
  Logger get _log => log;

  static final log =
      Logger("widget.home_collections._WrappedHomeCollectionsState");
}

extension _$_SelectionAppBarNpLog on _SelectionAppBar {
  // ignore: unused_element
  Logger get _log => log;

  static final log = Logger("widget.home_collections._SelectionAppBar");
}

extension _$_BlocNpLog on _Bloc {
  // ignore: unused_element
  Logger get _log => log;

  static final log = Logger("widget.home_collections._Bloc");
}

extension _$_ItemNpLog on _Item {
  // ignore: unused_element
  Logger get _log => log;

  static final log = Logger("widget.home_collections._Item");
}

// **************************************************************************
// ToStringGenerator
// **************************************************************************

extension _$_StateToString on _State {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_State {collections: [length: ${collections.length}], sort: ${sort.name}, isLoading: $isLoading, transformedItems: [length: ${transformedItems.length}], selectedItems: $selectedItems, error: $error, removeError: $removeError}";
  }
}

extension _$_LoadCollectionsToString on _LoadCollections {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_LoadCollections {}";
  }
}

extension _$_ReloadCollectionsToString on _ReloadCollections {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_ReloadCollections {}";
  }
}

extension _$_TransformItemsToString on _TransformItems {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_TransformItems {collections: [length: ${collections.length}]}";
  }
}

extension _$_SetSelectedItemsToString on _SetSelectedItems {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_SetSelectedItems {items: $items}";
  }
}

extension _$_RemoveSelectedItemsToString on _RemoveSelectedItems {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_RemoveSelectedItems {}";
  }
}

extension _$_UpdateCollectionSortToString on _UpdateCollectionSort {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_UpdateCollectionSort {sort: ${sort.name}}";
  }
}

extension _$_SetCollectionSortToString on _SetCollectionSort {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_SetCollectionSort {sort: ${sort.name}}";
  }
}

extension _$_SetErrorToString on _SetError {
  String _$toString() {
    // ignore: unnecessary_string_interpolations
    return "_SetError {error: $error, stackTrace: $stackTrace}";
  }
}
