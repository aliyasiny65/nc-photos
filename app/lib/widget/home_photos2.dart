import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:copy_with/copy_with.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:kiwi/kiwi.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/app_localizations.dart';
import 'package:nc_photos/bloc_util.dart';
import 'package:nc_photos/controller/account_controller.dart';
import 'package:nc_photos/controller/account_pref_controller.dart';
import 'package:nc_photos/controller/collections_controller.dart';
import 'package:nc_photos/controller/files_controller.dart';
import 'package:nc_photos/controller/metadata_controller.dart';
import 'package:nc_photos/controller/persons_controller.dart';
import 'package:nc_photos/controller/pref_controller.dart';
import 'package:nc_photos/controller/sync_controller.dart';
import 'package:nc_photos/di_container.dart';
import 'package:nc_photos/download_handler.dart';
import 'package:nc_photos/entity/collection.dart';
import 'package:nc_photos/entity/file_descriptor.dart';
import 'package:nc_photos/entity/file_util.dart' as file_util;
import 'package:nc_photos/event/event.dart';
import 'package:nc_photos/exception_event.dart';
import 'package:nc_photos/exception_util.dart' as exception_util;
import 'package:nc_photos/flutter_util.dart' as flutter_util;
import 'package:nc_photos/k.dart' as k;
import 'package:nc_photos/language_util.dart' as language_util;
import 'package:nc_photos/progress_util.dart';
import 'package:nc_photos/snack_bar_manager.dart';
import 'package:nc_photos/theme.dart';
import 'package:nc_photos/theme/dimension.dart';
import 'package:nc_photos/widget/collection_browser.dart';
import 'package:nc_photos/widget/collection_picker.dart';
import 'package:nc_photos/widget/file_sharer_dialog.dart';
import 'package:nc_photos/widget/finger_listener.dart';
import 'package:nc_photos/widget/home_app_bar.dart';
import 'package:nc_photos/widget/navigation_bar_blur_filter.dart';
import 'package:nc_photos/widget/network_thumbnail.dart';
import 'package:nc_photos/widget/photo_list_item.dart';
import 'package:nc_photos/widget/photo_list_util.dart' as photo_list_util;
import 'package:nc_photos/widget/selectable_item_list.dart';
import 'package:nc_photos/widget/selection_app_bar.dart';
import 'package:nc_photos/widget/sliver_visualized_scale.dart';
import 'package:nc_photos/widget/viewer.dart';
import 'package:np_async/np_async.dart';
import 'package:np_codegen/np_codegen.dart';
import 'package:np_collection/np_collection.dart';
import 'package:np_common/object_util.dart';
import 'package:np_common/or_null.dart';
import 'package:to_string/to_string.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'home_photos/app_bar.dart';
part 'home_photos/bloc.dart';
part 'home_photos/state_event.dart';
part 'home_photos/type.dart';
part 'home_photos/view.dart';
part 'home_photos2.g.dart';

class HomePhotos2BackToTopEvent {
  const HomePhotos2BackToTopEvent();
}

class HomePhotos2 extends StatelessWidget {
  const HomePhotos2({super.key});

  @override
  Widget build(BuildContext context) {
    final accountController = context.read<AccountController>();
    return BlocProvider(
      create: (_) => _Bloc(
        KiwiContainer().resolve(),
        account: accountController.account,
        controller: accountController.filesController,
        prefController: context.read(),
        accountPrefController: accountController.accountPrefController,
        collectionsController: accountController.collectionsController,
        syncController: accountController.syncController,
        personsController: accountController.personsController,
        metadataController: accountController.metadataController,
      ),
      child: const _WrappedHomePhotos(),
    );
  }
}

class _WrappedHomePhotos extends StatefulWidget {
  const _WrappedHomePhotos();

  @override
  State<StatefulWidget> createState() => _WrappedHomePhotosState();
}

@npLog
class _WrappedHomePhotosState extends State<_WrappedHomePhotos> {
  @override
  void initState() {
    super.initState();
    _bloc.add(const _LoadItems());
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _key,
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction >= 0.2;
        if (isVisible != _isVisible) {
          if (mounted) {
            setState(() {
              _isVisible = isVisible;
            });
          }
        }
      },
      child: MultiBlocListener(
        listeners: [
          _BlocListenerT<List<FileDescriptor>>(
            selector: (state) => state.files,
            listener: (context, files) {
              _bloc.add(_TransformItems(files));
            },
          ),
          _BlocListenerT<ExceptionEvent?>(
            selector: (state) => state.error,
            listener: (context, error) {
              if (error != null && _isVisible == true) {
                final String content;
                if (error.error is _ArchiveFailedError) {
                  content = L10n.global().archiveSelectedFailureNotification(
                      (error.error as _ArchiveFailedError).count);
                } else if (error.error is _RemoveFailedError) {
                  content = L10n.global().deleteSelectedFailureNotification(
                      (error.error as _RemoveFailedError).count);
                } else {
                  content = exception_util.toUserString(error.error);
                }
                SnackBarManager().showSnackBar(SnackBar(
                  content: Text(content),
                  duration: k.snackBarDurationNormal,
                ));
              }
            },
          ),
        ],
        child: _BlocSelector<bool>(
          selector: (state) =>
              state.files.isEmpty && state.syncProgress != null,
          builder: (context, isInitialSyncing) {
            if (isInitialSyncing) {
              return const _InitialSyncBody();
            } else {
              return const _Body();
            }
          },
        ),
      ),
    );
  }

  late final _bloc = context.bloc;

  final _key = GlobalKey();
  bool? _isVisible;
}

class _InitialSyncBody extends StatelessWidget {
  const _InitialSyncBody();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const _AppBar(),
        _BlocSelector<Progress?>(
          selector: (state) => state.syncProgress,
          builder: (context, syncProgress) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: Theme.of(context).widthLimitedContentMaxWidth,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.global().initialSyncMessage,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (syncProgress?.progress ?? 0) == 0
                              ? null
                              : syncProgress!.progress,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          syncProgress?.text ?? "",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<StatefulWidget> createState() => _BodyState();
}

@npLog
class _BodyState extends State<_Body> {
  @override
  void initState() {
    super.initState();
    _onBackToTopListener.begin();
  }

  @override
  void dispose() {
    _onBackToTopListener.end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FingerListener(
      onFingerChanged: (finger) {
        setState(() {
          _finger = finger;
        });
      },
      child: GestureDetector(
        onScaleStart: (_) {
          _bloc.add(const _StartScaling());
        },
        onScaleUpdate: (details) {
          _bloc.add(_SetScale(details.scale));
        },
        onScaleEnd: (_) {
          _bloc.add(const _EndScaling());
        },
        child: LayoutBuilder(
          builder: (context, constraints) => _BlocBuilder(
            buildWhen: (previous, current) =>
                previous.contentListMaxExtent != current.contentListMaxExtent ||
                (previous.isEnableMemoryCollection &&
                        previous.memoryCollections.isNotEmpty) !=
                    (current.isEnableMemoryCollection &&
                        current.memoryCollections.isNotEmpty),
            builder: (context, state) {
              final scrollExtent = _getScrollViewExtent(
                context: context,
                constraints: constraints,
                hasMemoryCollection: state.isEnableMemoryCollection &&
                    state.memoryCollections.isNotEmpty,
                contentListMaxExtent: state.contentListMaxExtent,
              );
              return Stack(
                children: [
                  DraggableScrollbar.semicircle(
                    controller: _scrollController,
                    overrideMaxScrollExtent: scrollExtent,
                    // status bar + app bar
                    topOffset: _getAppBarExtent(context),
                    bottomOffset:
                        AppDimension.of(context).homeBottomAppBarHeight,
                    labelTextBuilder: (_) => const _ScrollLabel(),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 40),
                    backgroundColor: Theme.of(context).elevate(
                        Theme.of(context).colorScheme.inverseSurface, 3),
                    heightScrollThumb: 60,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: RefreshIndicator(
                        onRefresh: () async {
                          _bloc.add(const _RequestRefresh());
                          var hasNotNull = false;
                          await _bloc.stream.firstWhere((s) {
                            if (s.syncProgress != null) {
                              hasNotNull = true;
                            }
                            return hasNotNull && s.syncProgress == null;
                          });
                        },
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: _finger >= 2
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          slivers: [
                            _BlocSelector<bool>(
                              selector: (state) => state.selectedItems.isEmpty,
                              builder: (context, isEmpty) => isEmpty
                                  ? const _AppBar()
                                  : const _SelectionAppBar(),
                            ),
                            _BlocBuilder(
                              buildWhen: (previous, current) =>
                                  (previous.isEnableMemoryCollection &&
                                      previous.memoryCollections.isNotEmpty) !=
                                  (current.isEnableMemoryCollection &&
                                      current.memoryCollections.isNotEmpty),
                              builder: (context, state) {
                                if (state.isEnableMemoryCollection &&
                                    state.memoryCollections.isNotEmpty) {
                                  return const _MemoryCollectionList();
                                } else {
                                  return const SliverToBoxAdapter();
                                }
                              },
                            ),
                            _BlocSelector<double?>(
                              selector: (state) => state.scale,
                              builder: (context, scale) =>
                                  SliverTransitionedScale(
                                scale: scale,
                                baseSliver: const _ContentList(),
                                overlaySliver: const _ScalingList(),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: AppDimension.of(context)
                                    .homeBottomAppBarHeight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: NavigationBarBlurFilter(
                      height: AppDimension.of(context).homeBottomAppBarHeight,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _onBackToTop(HomePhotos2BackToTopEvent ev) {
    _scrollController.jumpTo(0);
  }

  /// Return the estimated scroll extent of the custom scroll view, or null
  double? _getScrollViewExtent({
    required BuildContext context,
    required BoxConstraints constraints,
    required bool hasMemoryCollection,
    required double? contentListMaxExtent,
  }) {
    if (contentListMaxExtent != null && constraints.hasBoundedHeight) {
      final appBarExtent = _getAppBarExtent(context);
      final bottomAppBarExtent =
          AppDimension.of(context).homeBottomAppBarHeight;
      // final metadataTaskHeaderExtent = _web?.getHeaderHeight() ?? 0;
      final smartAlbumListHeight =
          hasMemoryCollection ? _MemoryCollectionItem.height : 0;
      // scroll extent = list height - widget viewport height
      // + sliver app bar height + bottom app bar height
      // + metadata task header height + smart album list height
      final scrollExtent = contentListMaxExtent -
          constraints.maxHeight +
          appBarExtent +
          bottomAppBarExtent +
          // metadataTaskHeaderExtent +
          smartAlbumListHeight;
      _log.info("[_getScrollViewExtent] $contentListMaxExtent "
          "- ${constraints.maxHeight} "
          "+ $appBarExtent "
          "+ $bottomAppBarExtent "
          // "+ $metadataTaskHeaderExtent "
          "+ $smartAlbumListHeight "
          "= $scrollExtent");
      return scrollExtent;
    } else {
      return null;
    }
  }

  double _getAppBarExtent(BuildContext context) =>
      MediaQuery.of(context).padding.top + kToolbarHeight;

  late final _bloc = context.bloc;

  final _scrollController = ScrollController();
  var _finger = 0;

  late final _onBackToTopListener =
      AppEventListener<HomePhotos2BackToTopEvent>(_onBackToTop);
}

typedef _BlocBuilder = BlocBuilder<_Bloc, _State>;
// typedef _BlocListener = BlocListener<_Bloc, _State>;
typedef _BlocListenerT<T> = BlocListenerT<_Bloc, _State, T>;
typedef _BlocSelector<T> = BlocSelector<_Bloc, _State, T>;

extension on BuildContext {
  _Bloc get bloc => read<_Bloc>();
  // _State get state => bloc.state;
  void addEvent(_Event event) => bloc.add(event);
}

@npLog
// ignore: camel_case_types
class __ {}