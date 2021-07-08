import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/api/api_util.dart' as api_util;
import 'package:nc_photos/entity/album.dart';
import 'package:nc_photos/entity/album/item.dart';
import 'package:nc_photos/entity/album/provider.dart';
import 'package:nc_photos/entity/album/sort_provider.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/entity/file_util.dart' as file_util;
import 'package:nc_photos/exception_util.dart' as exception_util;
import 'package:nc_photos/k.dart' as k;
import 'package:nc_photos/list_extension.dart';
import 'package:nc_photos/snack_bar_manager.dart';
import 'package:nc_photos/theme.dart';
import 'package:nc_photos/use_case/resync_album.dart';
import 'package:nc_photos/use_case/update_album.dart';
import 'package:nc_photos/widget/album_viewer_mixin.dart';
import 'package:nc_photos/widget/photo_list_item.dart';
import 'package:nc_photos/widget/selectable_item_stream_list_mixin.dart';
import 'package:nc_photos/widget/viewer.dart';
import 'package:quiver/iterables.dart';

class AlbumViewerArguments {
  AlbumViewerArguments(this.account, this.album);

  final Account account;
  final Album album;
}

class AlbumViewer extends StatefulWidget {
  static const routeName = "/album-viewer";

  AlbumViewer({
    Key key,
    @required this.account,
    @required this.album,
  }) : super(key: key);

  AlbumViewer.fromArgs(AlbumViewerArguments args, {Key key})
      : this(
          key: key,
          account: args.account,
          album: args.album,
        );

  @override
  createState() => _AlbumViewerState();

  final Account account;
  final Album album;
}

class _AlbumViewerState extends State<AlbumViewer>
    with
        WidgetsBindingObserver,
        SelectableItemStreamListMixin<AlbumViewer>,
        AlbumViewerMixin<AlbumViewer> {
  @override
  initState() {
    super.initState();
    _initAlbum();
  }

  @override
  build(BuildContext context) {
    return AppTheme(
      child: Scaffold(
        body: Builder(
          builder: (context) {
            if (isEditMode) {
              return Form(
                key: _editFormKey,
                child: _buildContent(context),
              );
            } else {
              return _buildContent(context);
            }
          },
        ),
      ),
    );
  }

  @override
  enterEditMode() {
    super.enterEditMode();
    _editAlbum = _album.copyWith();
  }

  @override
  doneEditMode() {
    if (_editFormKey?.currentState?.validate() == true) {
      try {
        // persist the changes
        _editFormKey.currentState.save();
        final newAlbum = makeEdited(_editAlbum);
        if (newAlbum.copyWith(lastUpdated: _album.lastUpdated) != _album) {
          _log.info("[doneEditMode] Album modified: $newAlbum");
          final albumRepo = AlbumRepo(AlbumCachedDataSource());
          setState(() {
            _album = newAlbum;
          });
          UpdateAlbum(albumRepo)(widget.account, newAlbum)
              .catchError((e, stacktrace) {
            SnackBarManager().showSnackBar(SnackBar(
              content: Text(exception_util.toUserString(e, context)),
              duration: k.snackBarDurationNormal,
            ));
          });
        } else {
          _log.fine("[doneEditMode] Album not modified");
        }
        return true;
      } finally {
        setState(() {
          // reset edits
          _editAlbum = null;
          // update the list to show the real album
          _transformItems();
        });
      }
    }
    return false;
  }

  void _initAlbum() {
    assert(widget.album.provider is AlbumStaticProvider);
    ResyncAlbum()(widget.account, widget.album).then((album) {
      if (_shouldPropagateResyncedAlbum(album)) {
        UpdateAlbum(AlbumRepo(AlbumCachedDataSource()))(widget.account, album)
            .catchError((e, stacktrace) {
          _log.shout("[_initAlbum] Failed while updating album", e, stacktrace);
        });
      }
      if (mounted) {
        setState(() {
          _album = album;
          _transformItems();
          initCover(widget.account, _backingFiles);
        });
      }
    });
  }

  Widget _buildContent(BuildContext context) {
    if (_album == null) {
      return CustomScrollView(
        slivers: [
          buildNormalAppBar(context, widget.account, widget.album),
          const SliverToBoxAdapter(
            child: const LinearProgressIndicator(),
          ),
        ],
      );
    }
    return buildItemStreamListOuter(
      context,
      child: Theme(
        data: Theme.of(context).copyWith(
          accentColor: AppTheme.getOverscrollIndicatorColor(context),
        ),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverIgnorePointer(
                ignoring: isEditMode,
                sliver: SliverOpacity(
                  opacity: isEditMode ? .25 : 1,
                  sliver: buildItemStreamList(
                    maxCrossAxisExtent: thumbSize.toDouble(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    if (isEditMode) {
      return _buildEditAppBar(context);
    } else if (isSelectionMode) {
      return _buildSelectionAppBar(context);
    } else {
      return buildNormalAppBar(context, widget.account, _album);
    }
  }

  Widget _buildSelectionAppBar(BuildContext context) {
    return buildSelectionAppBar(context, [
      IconButton(
        icon: const Icon(Icons.remove),
        tooltip: AppLocalizations.of(context).removeSelectedFromAlbumTooltip,
        onPressed: () {
          _onSelectionAppBarRemovePressed();
        },
      )
    ]);
  }

  Widget _buildEditAppBar(BuildContext context) {
    return buildEditAppBar(context, widget.account, widget.album, actions: [
      IconButton(
        icon: Icon(Icons.sort_by_alpha),
        tooltip: AppLocalizations.of(context).sortTooltip,
        onPressed: _onEditAppBarSortPressed,
      ),
    ]);
  }

  void _onItemTap(int index) {
    Navigator.pushNamed(context, Viewer.routeName,
        arguments: ViewerArguments(widget.account, _backingFiles, index));
  }

  void _onSelectionAppBarRemovePressed() {
    // currently album's are auto sorted by date, so it's ok to remove items w/o
    // preserving the order. this will be problematic if we want to allow custom
    // sorting later
    final selectedIndexes =
        selectedListItems.map((e) => itemStreamListItems.indexOf(e)).toList();
    final selectedFiles = _backingFiles.takeIndex(selectedIndexes).toList();
    final newItems = _getAlbumItemsOf(_album).where((element) {
      if (element is AlbumFileItem) {
        return !selectedFiles.any((select) => select.path == element.file.path);
      } else {
        return true;
      }
    }).toList();
    final albumRepo = AlbumRepo(AlbumCachedDataSource());
    final newAlbum = _album.copyWith(
      provider: AlbumStaticProvider(
        items: newItems,
      ),
    );
    UpdateAlbum(albumRepo)(widget.account, newAlbum).then((_) {
      SnackBarManager().showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)
            .removeSelectedFromAlbumSuccessNotification(
                selectedIndexes.length)),
        duration: k.snackBarDurationNormal,
      ));
      setState(() {
        _album = newAlbum;
        _transformItems();
        initCover(widget.account, _backingFiles);
      });
    }).catchError((e, stacktrace) {
      _log.shout("[_onSelectionRemovePressed] Failed while updating album", e,
          stacktrace);
      SnackBarManager().showSnackBar(SnackBar(
        content: Text(
            "${AppLocalizations.of(context).removeSelectedFromAlbumFailureNotification}: "
            "${exception_util.toUserString(e, context)}"),
        duration: k.snackBarDurationNormal,
      ));
    });
    setState(() {
      clearSelectedItems();
    });
  }

  void _onEditAppBarSortPressed() {
    final sortProvider = _editAlbum.sortProvider;
    final isOldest =
        sortProvider is AlbumTimeSortProvider && sortProvider.isAscending;
    final isNewest =
        sortProvider is AlbumTimeSortProvider && !sortProvider.isAscending;
    final activeTextStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
    );
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context).sortOptionDialogTitle),
        children: [
          SimpleDialogOption(
            child: ListTile(
              leading: Icon(
                isOldest ? Icons.check : null,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                AppLocalizations.of(context).sortOptionTimeAscendingLabel,
                style: isOldest ? activeTextStyle : null,
              ),
              onTap: isOldest
                  ? null
                  : () {
                      _onSortOldestPressed();
                      Navigator.of(context).pop();
                    },
            ),
          ),
          SimpleDialogOption(
            child: ListTile(
              leading: Icon(
                isNewest ? Icons.check : null,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                AppLocalizations.of(context).sortOptionTimeDescendingLabel,
                style: isNewest ? activeTextStyle : null,
              ),
              onTap: isNewest
                  ? null
                  : () {
                      _onSortNewestPressed();
                      Navigator.of(context).pop();
                    },
            ),
          ),
        ],
      ),
    );
  }

  void _onSortOldestPressed() {
    _editAlbum = _editAlbum.copyWith(
      sortProvider: AlbumTimeSortProvider(isAscending: true),
    );
    setState(() {
      _transformItems();
    });
  }

  void _onSortNewestPressed() {
    _editAlbum = _editAlbum.copyWith(
      sortProvider: AlbumTimeSortProvider(isAscending: false),
    );
    setState(() {
      _transformItems();
    });
  }

  void _transformItems() {
    List<AlbumItem> sortedItems;
    if (_editAlbum != null) {
      // edit mode
      sortedItems = _editAlbum.sortProvider.sort(_getAlbumItemsOf(_editAlbum));
    } else {
      sortedItems = _album.sortProvider.sort(_getAlbumItemsOf(_album));
    }
    _backingFiles = sortedItems
        .whereType<AlbumFileItem>()
        .map((e) => e.file)
        .where((element) => file_util.isSupportedFormat(element))
        .toList();

    itemStreamListItems = () sync* {
      for (int i = 0; i < _backingFiles.length; ++i) {
        final f = _backingFiles[i];

        final previewUrl = api_util.getFilePreviewUrl(widget.account, f,
            width: thumbSize, height: thumbSize);
        if (file_util.isSupportedImageFormat(f)) {
          yield _ImageListItem(
            file: f,
            account: widget.account,
            previewUrl: previewUrl,
            onTap: () => _onItemTap(i),
          );
        } else if (file_util.isSupportedVideoFormat(f)) {
          yield _VideoListItem(
            account: widget.account,
            previewUrl: previewUrl,
            onTap: () => _onItemTap(i),
          );
        } else {
          _log.shout(
              "[_transformItems] Unsupported file format: ${f.contentType}");
        }
      }
    }()
        .toList();
  }

  bool _shouldPropagateResyncedAlbum(Album album) {
    final origItems = _getAlbumItemsOf(widget.album);
    final resyncItems = _getAlbumItemsOf(album);
    if (origItems.length != resyncItems.length) {
      _log.info(
          "[_shouldPropagateResyncedAlbum] Item length differ: ${origItems.length}, ${resyncItems.length}");
      return true;
    }
    for (final z in zip([origItems, resyncItems])) {
      final a = z[0], b = z[1];
      bool isEqual;
      if (a is AlbumFileItem && b is AlbumFileItem) {
        // faster compare
        isEqual = a.equals(b, isDeep: false);
      } else {
        isEqual = a == b;
      }
      if (!isEqual) {
        _log.info(
            "[_shouldPropagateResyncedAlbum] Item differ:\nOriginal: ${z[0]}\nResynced: ${z[1]}");
        return true;
      }
    }
    _log.info("[_shouldPropagateResyncedAlbum] false");
    return false;
  }

  static List<AlbumItem> _getAlbumItemsOf(Album a) =>
      AlbumStaticProvider.of(a).items;

  Album _album;
  var _backingFiles = <File>[];

  final _editFormKey = GlobalKey<FormState>();
  Album _editAlbum;

  static final _log = Logger("widget.album_viewer._AlbumViewerState");
}

abstract class _ListItem implements SelectableItem {
  _ListItem({
    VoidCallback onTap,
  }) : _onTap = onTap;

  @override
  get onTap => _onTap;

  @override
  get isSelectable => true;

  @override
  get staggeredTile => const StaggeredTile.count(1, 1);

  final VoidCallback _onTap;
}

class _ImageListItem extends _ListItem {
  _ImageListItem({
    @required this.file,
    @required this.account,
    @required this.previewUrl,
    VoidCallback onTap,
  }) : super(onTap: onTap);

  @override
  buildWidget(BuildContext context) {
    return PhotoListImage(
      account: account,
      previewUrl: previewUrl,
      isGif: file.contentType == "image/gif",
    );
  }

  final File file;
  final Account account;
  final String previewUrl;
}

class _VideoListItem extends _ListItem {
  _VideoListItem({
    @required this.account,
    @required this.previewUrl,
    VoidCallback onTap,
  }) : super(onTap: onTap);

  @override
  buildWidget(BuildContext context) {
    return PhotoListVideo(
      account: account,
      previewUrl: previewUrl,
    );
  }

  final Account account;
  final String previewUrl;
}
