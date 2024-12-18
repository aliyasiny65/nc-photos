import 'dart:async';

import 'package:clock/clock.dart';
import 'package:copy_with/copy_with.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/app_localizations.dart';
import 'package:nc_photos/bloc_util.dart';
import 'package:nc_photos/controller/account_controller.dart';
import 'package:nc_photos/controller/files_controller.dart';
import 'package:nc_photos/entity/file_descriptor.dart';
import 'package:nc_photos/entity/file_util.dart' as file_util;
import 'package:nc_photos/k.dart' as k;
import 'package:nc_photos/theme.dart';
import 'package:nc_photos/widget/disposable.dart';
import 'package:nc_photos/widget/horizontal_page_viewer.dart';
import 'package:nc_photos/widget/image_viewer.dart';
import 'package:nc_photos/widget/network_thumbnail.dart';
import 'package:nc_photos/widget/photo_list_item.dart';
import 'package:nc_photos/widget/slideshow_dialog.dart';
import 'package:nc_photos/widget/video_viewer.dart';
import 'package:nc_photos/widget/viewer_mixin.dart';
import 'package:nc_photos/widget/wakelock_util.dart';
import 'package:np_codegen/np_codegen.dart';
import 'package:np_common/object_util.dart';
import 'package:np_ui/np_ui.dart';
import 'package:to_string/to_string.dart';

part 'slideshow_viewer.g.dart';
part 'slideshow_viewer/bloc.dart';
part 'slideshow_viewer/state_event.dart';
part 'slideshow_viewer/timeline.dart';
part 'slideshow_viewer/view.dart';

class SlideshowViewerArguments {
  const SlideshowViewerArguments(
    this.account,
    this.fileIds,
    this.startIndex,
    this.config,
  );

  final Account account;
  final List<int> fileIds;
  final int startIndex;
  final SlideshowConfig config;
}

class SlideshowViewer extends StatelessWidget {
  static const routeName = "/slideshow-viewer";

  static Route buildRoute(
          SlideshowViewerArguments args, RouteSettings settings) =>
      MaterialPageRoute<int>(
        builder: (context) => SlideshowViewer.fromArgs(args),
        settings: settings,
      );

  const SlideshowViewer({
    super.key,
    required this.account,
    required this.fileIds,
    required this.startIndex,
    required this.config,
  });

  SlideshowViewer.fromArgs(SlideshowViewerArguments args, {Key? key})
      : this(
          key: key,
          account: args.account,
          fileIds: args.fileIds,
          startIndex: args.startIndex,
          config: args.config,
        );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _Bloc(
        filesController: context.read<AccountController>().filesController,
        account: context.read<AccountController>().account,
        fileIds: fileIds,
        startIndex: startIndex,
        config: config,
      )..add(const _Init()),
      child: const _WrappedSlideshowViewer(),
    );
  }

  final Account account;
  final List<int> fileIds;
  final int startIndex;
  final SlideshowConfig config;
}

class _WrappedSlideshowViewer extends StatefulWidget {
  const _WrappedSlideshowViewer();

  @override
  State<StatefulWidget> createState() => _WrappedSlideshowViewerState();
}

class _WrappedSlideshowViewerState extends State<_WrappedSlideshowViewer>
    with
        DisposableManagerMixin<_WrappedSlideshowViewer>,
        ViewerControllersMixin<_WrappedSlideshowViewer> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  List<Disposable> initDisposables() {
    return [
      ...super.initDisposables(),
      WakelockControllerDisposable(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        _BlocListenerT<bool>(
          selector: (state) => state.hasRequestExit,
          listener: (context, hasRequestExit) {
            if (hasRequestExit) {
              final pageIndex = context.state.page;
              final fileIndex = context.bloc.convertPageToFileIndex(pageIndex);
              Navigator.of(context).pop(fileIndex);
            }
          },
        ),
      ],
      child: Theme(
        data: buildDarkTheme(context),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            body: PopScope(
              canPop: false,
              onPopInvoked: (_) {
                context.addEvent(const _RequestExit());
              },
              child: _BlocSelector<bool>(
                selector: (state) => state.hasInit,
                builder: (context, hasInit) =>
                    hasInit ? const _Body() : const _InitBody(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// typedef _BlocBuilder = BlocBuilder<_Bloc, _State>;
typedef _BlocListener = BlocListener<_Bloc, _State>;
typedef _BlocListenerT<T> = BlocListenerT<_Bloc, _State, T>;
typedef _BlocSelector<T> = BlocSelector<_Bloc, _State, T>;

extension on BuildContext {
  _Bloc get bloc => read<_Bloc>();
  _State get state => bloc.state;
  void addEvent(_Event event) => bloc.add(event);
}
