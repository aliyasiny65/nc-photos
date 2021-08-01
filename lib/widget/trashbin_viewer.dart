import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/app_localizations.dart';
import 'package:nc_photos/entity/file.dart';
import 'package:nc_photos/entity/file/data_source.dart';
import 'package:nc_photos/entity/file_util.dart' as file_util;
import 'package:nc_photos/exception_util.dart' as exception_util;
import 'package:nc_photos/k.dart' as k;
import 'package:nc_photos/snack_bar_manager.dart';
import 'package:nc_photos/theme.dart';
import 'package:nc_photos/use_case/remove.dart';
import 'package:nc_photos/use_case/restore_trashbin.dart';
import 'package:nc_photos/widget/horizontal_page_viewer.dart';
import 'package:nc_photos/widget/image_viewer.dart';
import 'package:nc_photos/widget/video_viewer.dart';

class TrashbinViewerArguments {
  TrashbinViewerArguments(this.account, this.streamFiles, this.startIndex);

  final Account account;
  final List<File> streamFiles;
  final int startIndex;
}

class TrashbinViewer extends StatefulWidget {
  static const routeName = "/trashbin-viewer";

  static Route buildRoute(TrashbinViewerArguments args) => MaterialPageRoute(
        builder: (context) => TrashbinViewer.fromArgs(args),
      );

  TrashbinViewer({
    Key? key,
    required this.account,
    required this.streamFiles,
    required this.startIndex,
  }) : super(key: key);

  TrashbinViewer.fromArgs(TrashbinViewerArguments args, {Key? key})
      : this(
          key: key,
          account: args.account,
          streamFiles: args.streamFiles,
          startIndex: args.startIndex,
        );

  @override
  createState() => _TrashbinViewerState();

  final Account account;
  final List<File> streamFiles;
  final int startIndex;
}

class _TrashbinViewerState extends State<TrashbinViewer> {
  @override
  build(BuildContext context) {
    return AppTheme(
      child: Scaffold(
        body: Builder(
          builder: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isShowVideoControl = !_isShowVideoControl;
        });
      },
      child: Stack(
        children: [
          Container(color: Colors.black),
          if (!_isViewerLoaded ||
              !_pageStates[_viewerController.currentPage]!.hasLoaded)
            Align(
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          HorizontalPageViewer(
            pageCount: widget.streamFiles.length,
            pageBuilder: _buildPage,
            initialPage: widget.startIndex,
            controller: _viewerController,
            viewportFraction: _viewportFraction,
            canSwitchPage: _canSwitchPage,
          ),
          _buildAppBar(context),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Wrap(
      children: [
        Stack(
          children: [
            Container(
              // + status bar height
              height: kToolbarHeight + MediaQuery.of(context).padding.top,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(0, -1),
                  end: const Alignment(0, 1),
                  colors: [
                    Color.fromARGB(192, 0, 0, 0),
                    Color.fromARGB(0, 0, 0, 0),
                  ],
                ),
              ),
            ),
            AppBar(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              brightness: Brightness.dark,
              iconTheme: Theme.of(context).iconTheme.copyWith(
                    color: Colors.white.withOpacity(.87),
                  ),
              actionsIconTheme: Theme.of(context).iconTheme.copyWith(
                    color: Colors.white.withOpacity(.87),
                  ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.restore_outlined),
                  tooltip: L10n.of(context).restoreTooltip,
                  onPressed: _onRestorePressed,
                ),
                PopupMenuButton<_AppBarMenuOption>(
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _AppBarMenuOption.delete,
                      child: Text(L10n.of(context).deletePermanentlyTooltip),
                    ),
                  ],
                  onSelected: (option) {
                    switch (option) {
                      case _AppBarMenuOption.delete:
                        _onDeletePressed(context);
                        break;

                      default:
                        _log.shout("[_buildAppBar] Unknown option: $option");
                        break;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _onRestorePressed() async {
    final file = widget.streamFiles[_viewerController.currentPage];
    _log.info("[_onRestorePressed] Restoring file: ${file.path}");
    var controller = SnackBarManager().showSnackBar(SnackBar(
      content: Text(L10n.of(context).restoreProcessingNotification),
      duration: k.snackBarDurationShort,
    ));
    controller?.closed.whenComplete(() {
      controller = null;
    });
    final fileRepo = FileRepo(FileCachedDataSource());
    try {
      await RestoreTrashbin(fileRepo)(widget.account, file);
      controller?.close();
      SnackBarManager().showSnackBar(SnackBar(
        content: Text(L10n.of(context).restoreSuccessNotification),
        duration: k.snackBarDurationNormal,
      ));
      Navigator.of(context).pop();
    } catch (e, stacktrace) {
      _log.shout(
          "Failed while restore trashbin" +
              (kDebugMode ? ": ${file.path}" : ""),
          e,
          stacktrace);
      controller?.close();
      SnackBarManager().showSnackBar(SnackBar(
        content: Text("${L10n.of(context).restoreFailureNotification}: "
            "${exception_util.toUserString(e, context)}"),
        duration: k.snackBarDurationNormal,
      ));
    }
  }

  Future<void> _onDeletePressed(BuildContext context) async {
    final file = widget.streamFiles[_viewerController.currentPage];
    _log.info("[_onDeletePressed] Deleting file permanently: ${file.path}");
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L10n.of(context).deletePermanentlyConfirmationDialogTitle),
        content:
            Text(L10n.of(context).deletePermanentlyConfirmationDialogContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _delete(context);
            },
            child: Text(L10n.of(context).confirmButtonLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    if (_pageStates[index] == null) {
      _pageStates[index] = _PageState();
    }
    return FractionallySizedBox(
      widthFactor: 1 / _viewportFraction,
      child: _buildItemView(context, index),
    );
  }

  Widget _buildItemView(BuildContext context, int index) {
    final file = widget.streamFiles[index];
    if (file_util.isSupportedImageFormat(file)) {
      return _buildImageView(context, index);
    } else if (file_util.isSupportedVideoFormat(file)) {
      return _buildVideoView(context, index);
    } else {
      _log.shout("[_buildItemView] Unknown file format: ${file.contentType}");
      return Container();
    }
  }

  Widget _buildImageView(BuildContext context, int index) {
    return ImageViewer(
      account: widget.account,
      file: widget.streamFiles[index],
      canZoom: true,
      onLoaded: () => _onImageLoaded(index),
      onZoomStarted: () {
        setState(() {
          _isZoomed = true;
        });
      },
      onZoomEnded: () {
        setState(() {
          _isZoomed = false;
        });
      },
    );
  }

  Widget _buildVideoView(BuildContext context, int index) {
    return VideoViewer(
      account: widget.account,
      file: widget.streamFiles[index],
      onLoaded: () => _onVideoLoaded(index),
      onPlay: _onVideoPlay,
      onPause: _onVideoPause,
      isControlVisible: _isShowVideoControl,
    );
  }

  void _onImageLoaded(int index) {
    // currently pageview doesn't pre-load pages, we do it manually
    // don't pre-load if user already navigated away
    if (_viewerController.currentPage == index &&
        !_pageStates[index]!.hasLoaded) {
      _log.info("[_onImageLoaded] Pre-loading nearby images");
      if (index > 0) {
        final prevFile = widget.streamFiles[index - 1];
        if (file_util.isSupportedImageFormat(prevFile)) {
          ImageViewer.preloadImage(widget.account, prevFile);
        }
      }
      if (index + 1 < widget.streamFiles.length) {
        final nextFile = widget.streamFiles[index + 1];
        if (file_util.isSupportedImageFormat(nextFile)) {
          ImageViewer.preloadImage(widget.account, nextFile);
        }
      }
      setState(() {
        _pageStates[index]!.hasLoaded = true;
        _isViewerLoaded = true;
      });
    }
  }

  void _onVideoLoaded(int index) {
    if (_viewerController.currentPage == index &&
        !_pageStates[index]!.hasLoaded) {
      setState(() {
        _pageStates[index]!.hasLoaded = true;
        _isViewerLoaded = true;
      });
    }
  }

  void _onVideoPlay() {
    setState(() {
      _isShowVideoControl = false;
    });
  }

  void _onVideoPause() {
    setState(() {
      _isShowVideoControl = true;
    });
  }

  Future<void> _delete(BuildContext context) async {
    final file = widget.streamFiles[_viewerController.currentPage];
    _log.info("[_delete] Removing file: ${file.path}");
    var controller = SnackBarManager().showSnackBar(SnackBar(
      content: Text(L10n.of(context).deleteProcessingNotification),
      duration: k.snackBarDurationShort,
    ));
    controller?.closed.whenComplete(() {
      controller = null;
    });
    try {
      final fileRepo = FileRepo(FileCachedDataSource());
      await Remove(fileRepo, null)(widget.account, file);
      controller?.close();
      SnackBarManager().showSnackBar(SnackBar(
        content: Text(L10n.of(context).deleteSuccessNotification),
        duration: k.snackBarDurationNormal,
      ));
      Navigator.of(context).pop();
    } catch (e, stacktrace) {
      _log.shout(
          "[_delete] Failed while remove" +
              (kDebugMode ? ": ${file.path}" : ""),
          e,
          stacktrace);
      controller?.close();
      SnackBarManager().showSnackBar(SnackBar(
        content: Text("${L10n.of(context).deleteFailureNotification}: "
            "${exception_util.toUserString(e, context)}"),
        duration: k.snackBarDurationNormal,
      ));
    }
  }

  bool get _canSwitchPage => !_isZoomed;

  var _isShowVideoControl = true;
  var _isZoomed = false;

  final _viewerController = HorizontalPageViewerController();
  bool _isViewerLoaded = false;
  final _pageStates = <int, _PageState>{};

  static final _log = Logger("widget.trashbin_viewer._TrashbinViewerState");

  static const _viewportFraction = 1.05;
}

class _PageState {
  bool hasLoaded = false;
}

enum _AppBarMenuOption {
  delete,
}
