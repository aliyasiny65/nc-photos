part of '../slideshow_viewer.dart';

@npLog
class _Bloc extends Bloc<_Event, _State> with BlocLogger {
  _Bloc({
    required this.account,
    required this.files,
    required this.startIndex,
    required this.config,
  }) : super(_State.init(
          initialFile: files[startIndex],
        )) {
    on<_Init>(_onInit);
    on<_ToggleShowUi>(_onToggleShowUi);
    on<_PreloadSidePages>(_onPreloadSidePages);
    on<_VideoCompleted>(_onVideoCompleted);
    on<_SetPause>(_onSetPause);
    on<_SetPlay>(_onSetPlay);
    on<_RequestPrevPage>(_onRequestPrevPage);
    on<_RequestNextPage>(_onRequestNextPage);
    on<_SetCurrentPage>(_onSetCurrentPage);
    on<_NextPage>(_onNextPage);
    on<_ToggleTimeline>(_onToggleTimeline);
    on<_RequestPage>(_onRequestPage);
    on<_RequestExit>(_onRequestExit);
  }

  @override
  Future<void> close() {
    _pageChangeTimer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    return super.close();
  }

  @override
  String get tag => _log.fullName;

  /// Convert the page index to the corresponding item index
  int convertPageToFileIndex(int pageIndex) {
    if (config.isShuffle) {
      final i = pageIndex ~/ files.length;
      if (!_shuffledIndex.containsKey(i)) {
        final index = [for (var i = 0; i < files.length; ++i) i];
        _shuffledIndex[i] = index..shuffle();
      }
      return _shuffledIndex[i]![pageIndex % files.length];
    } else {
      return _shuffledIndex[0]![pageIndex % files.length];
    }
  }

  FileDescriptor getFileByPageIndex(int pageIndex) =>
      files[convertPageToFileIndex(pageIndex)];

  void _onInit(_Init ev, Emitter<_State> emit) {
    _log.info(ev);
    final parsedConfig = _parseConfig(
      files: files,
      startIndex: startIndex,
      config: config,
    );
    _shuffledIndex = {0: parsedConfig.shuffled};
    initialPage = parsedConfig.initial;
    pageCount = parsedConfig.count;
    emit(state.copyWith(
      hasInit: true,
      page: initialPage,
      currentFile: getFileByPageIndex(initialPage),
      hasPrev: initialPage > 0,
      hasNext: pageCount == null || initialPage < (pageCount! - 1),
    ));
    _prepareNextPage();
  }

  void _onToggleShowUi(_ToggleShowUi ev, Emitter<_State> emit) {
    _log.info(ev);
    emit(state.copyWith(isShowUi: !state.isShowUi));
    if (state.isShowUi) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }
  }

  void _onPreloadSidePages(_PreloadSidePages ev, Emitter<_State> emit) {
    _log.info(ev);
    // currently pageview doesn't pre-load pages, we do it manually
    // don't pre-load if user already navigated away
    if (state.page != ev.center) {
      return;
    }
    _log.info("[_onPreloadSidePages] Pre-loading nearby images");
    if (ev.center > 0) {
      final fileIndex = convertPageToFileIndex(ev.center - 1);
      final prevFile = files[fileIndex];
      if (file_util.isSupportedImageFormat(prevFile)) {
        RemoteImageViewer.preloadImage(account, prevFile);
      }
    }
    if (pageCount == null || ev.center + 1 < pageCount!) {
      final fileIndex = convertPageToFileIndex(ev.center + 1);
      final nextFile = files[fileIndex];
      if (file_util.isSupportedImageFormat(nextFile)) {
        RemoteImageViewer.preloadImage(account, nextFile);
      }
    }
  }

  void _onVideoCompleted(_VideoCompleted ev, Emitter<_State> emit) {
    _log.info(ev);
    emit(state.copyWith(isVideoCompleted: true));
    if (state.isPlay) {
      _gotoNextPage();
    }
  }

  void _onSetPause(_SetPause ev, Emitter<_State> emit) {
    _log.info(ev);
    _pageChangeTimer?.cancel();
    _pageChangeTimer = null;
    emit(state.copyWith(isPlay: false));
  }

  void _onSetPlay(_SetPlay ev, Emitter<_State> emit) {
    _log.info(ev);
    if (file_util.isSupportedVideoFormat(state.currentFile)) {
      // only start the countdown if the video completed
      if (state.isVideoCompleted) {
        _pageChangeTimer?.cancel();
        _pageChangeTimer = Timer(config.duration, _gotoNextPage);
      }
    } else {
      _pageChangeTimer?.cancel();
      _pageChangeTimer = Timer(config.duration, _gotoNextPage);
    }
    emit(state.copyWith(isPlay: true));
  }

  void _onRequestPrevPage(_RequestPrevPage ev, Emitter<_State> emit) {
    _log.info(ev);
    _gotoPrevPage();
  }

  void _onRequestNextPage(_RequestNextPage ev, Emitter<_State> emit) {
    _log.info(ev);
    _gotoNextPage();
  }

  void _onSetCurrentPage(_SetCurrentPage ev, Emitter<_State> emit) {
    _log.info(ev);
    emit(state.copyWith(
      page: ev.value,
      currentFile: getFileByPageIndex(ev.value),
      isVideoCompleted: false,
      hasPrev: ev.value > 0,
      hasNext: pageCount == null || ev.value < (pageCount! - 1),
    ));
    if (state.isPlay) {
      _prepareNextPage();
    }
  }

  void _onNextPage(_NextPage ev, Emitter<_State> emit) {
    _log.info(ev);
    emit(state.copyWith(
      nextPage: ev.value,
      shouldAnimateNextPage: true,
    ));
  }

  void _onToggleTimeline(_ToggleTimeline ev, Emitter<_State> emit) {
    _log.info(ev);
    final next = !state.isShowTimeline;
    emit(state.copyWith(
      isShowTimeline: next,
      hasShownTimeline: state.hasShownTimeline || next,
    ));
  }

  void _onRequestPage(_RequestPage ev, Emitter<_State> emit) {
    _log.info(ev);
    emit(state.copyWith(
      nextPage: ev.value,
      shouldAnimateNextPage: false,
    ));
  }

  void _onRequestExit(_RequestExit ev, Emitter<_State> emit) {
    _log.info(ev);
    emit(state.copyWith(hasRequestExit: true));
  }

  static ({List<int> shuffled, int initial, int? count}) _parseConfig({
    required List<FileDescriptor> files,
    required int startIndex,
    required SlideshowConfig config,
  }) {
    final index = [for (var i = 0; i < files.length; ++i) i];
    final count = config.isRepeat ? null : files.length;
    if (config.isShuffle) {
      return (
        shuffled: index..shuffle(),
        initial: 0,
        count: count,
      );
    } else if (config.isReverse) {
      return (
        shuffled: index.reversed.toList(),
        initial: files.length - 1 - startIndex,
        count: count,
      );
    } else {
      return (
        shuffled: index,
        initial: startIndex,
        count: count,
      );
    }
  }

  Future<void> _prepareNextPage() async {
    final file = state.currentFile;
    if (file_util.isSupportedVideoFormat(file)) {
      // for videos, we need to wait until it's ended
      return;
    }
    // for photos, we wait for a fixed amount of time defined in config
    _pageChangeTimer?.cancel();
    _pageChangeTimer = Timer(config.duration, _gotoNextPage);
  }

  void _gotoPrevPage() {
    if (isClosed) {
      return;
    }
    final nextPage = state.page - 1;
    if (nextPage < 0) {
      // end reached
      _log.info("[_gotoPrevPage] Reached the end");
      return;
    }
    _log.info("[_gotoPrevPage] To page: $nextPage");
    _pageChangeTimer?.cancel();
    add(_NextPage(nextPage));
  }

  void _gotoNextPage() {
    if (isClosed) {
      return;
    }
    final nextPage = state.page + 1;
    if (pageCount != null && nextPage >= pageCount!) {
      // end reached
      _log.info("[_gotoNextPage] Reached the end");
      return;
    }
    _log.info("[_gotoNextPage] To page: $nextPage");
    _pageChangeTimer?.cancel();
    add(_NextPage(nextPage));
  }

  final Account account;
  final List<FileDescriptor> files;
  final int startIndex;
  final SlideshowConfig config;

  late final Map<int, List<int>> _shuffledIndex;
  late final int initialPage;
  late final int? pageCount;
  Timer? _pageChangeTimer;

  final _subscriptions = <StreamSubscription>[];
}
