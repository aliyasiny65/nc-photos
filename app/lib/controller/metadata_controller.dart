import 'dart:async';

import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/controller/files_controller.dart';
import 'package:nc_photos/controller/pref_controller.dart';
import 'package:nc_photos/db/entity_converter.dart';
import 'package:nc_photos/di_container.dart';
import 'package:nc_photos/entity/file_descriptor.dart';
import 'package:nc_photos/entity/file_util.dart' as file_util;
import 'package:nc_photos/service.dart' as service;
import 'package:np_codegen/np_codegen.dart';

part 'metadata_controller.g.dart';

@npLog
class MetadataController {
  MetadataController(
    this._c, {
    required this.account,
    required this.filesController,
    required this.prefController,
  }) {
    _subscriptions.add(filesController.stream.listen(_onFilesEvent));
    _subscriptions
        .add(prefController.isEnableExifChange.listen(_onSetEnableExif));
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
  }

  /// Normally EXIF task only run once, call this function to make it run again
  /// after receiving new files
  void scheduleNext() {
    _hasStarted = false;
  }

  Future<void> _onFilesEvent(FilesStreamEvent ev) async {
    _log.info("[_onFilesEvent]");
    if (!prefController.isEnableExifValue) {
      // disabled
      return;
    }
    if (ev.data.isNotEmpty && !ev.hasNext) {
      // finished querying
      if (!_hasStarted) {
        await _startMetadataTask(ev.data);
      }
    }
  }

  void _onSetEnableExif(bool value) {
    _log.info("[_onSetEnableExif]");
    if (value) {
      final filesState = filesController.stream.value;
      if (filesState.hasNext || filesState.data.isEmpty) {
        _log.info("[_onSetEnableExif] Ignored as data not ready");
        return;
      }
      _startMetadataTask(filesState.data);
    } else {
      _stopMetadataTask();
    }
  }

  Future<void> _startMetadataTask(List<FileDescriptor> data) async {
    _hasStarted = true;
    try {
      final missingCount = await _c.npDb.countFilesByFileIdsMissingMetadata(
        account: account.toDb(),
        fileIds: data.map((e) => e.fdId).toList(),
        mimes: file_util.supportedImageFormatMimes,
      );
      _log.info("[_startMetadataTask] Missing count: $missingCount");
      if (missingCount > 0) {
        unawaited(service.startService());
      }
    } catch (e, stackTrace) {
      _log.shout(
          "[_startMetadataTask] Failed starting metadata task", e, stackTrace);
    }
  }

  void _stopMetadataTask() {
    service.stopService();
  }

  final DiContainer _c;
  final Account account;
  final FilesController filesController;
  final PrefController prefController;

  final _subscriptions = <StreamSubscription>[];
  var _hasStarted = false;
}