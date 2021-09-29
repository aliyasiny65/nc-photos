import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/exception.dart';
import 'package:nc_photos/mobile/android/download.dart';
import 'package:nc_photos/mobile/android/media_store.dart';
import 'package:nc_photos/platform/file_downloader.dart' as itf;
import 'package:nc_photos/platform/k.dart' as platform_k;

class FileDownloader extends itf.FileDownloader {
  @override
  downloadUrl({
    required String url,
    Map<String, String>? headers,
    String? mimeType,
    required String filename,
    String? parentDir,
    bool? shouldNotify,
  }) {
    if (platform_k.isAndroid) {
      return _downloadUrlAndroid(
        url: url,
        headers: headers,
        mimeType: mimeType,
        filename: filename,
        parentDir: parentDir,
        shouldNotify: shouldNotify,
      );
    } else {
      throw UnimplementedError();
    }
  }

  Future<String> _downloadUrlAndroid({
    required String url,
    Map<String, String>? headers,
    String? mimeType,
    required String filename,
    String? parentDir,
    bool? shouldNotify,
  }) async {
    final String path;
    if (parentDir?.isNotEmpty == true) {
      path = "$parentDir/$filename";
    } else {
      path = filename;
    }

    try {
      _log.info("[_downloadUrlAndroid] Start downloading '$url'");
      final id = await Download.downloadUrl(
        url: url,
        headers: headers,
        mimeType: mimeType,
        filename: path,
        shouldNotify: shouldNotify,
      );
      late final String uri;
      final completer = Completer();
      onDownloadComplete(DownloadCompleteEvent ev) {
        if (ev.downloadId == id) {
          _log.info(
              "[_downloadUrlAndroid] Finished downloading '$url' to '${ev.uri}'");
          uri = ev.uri;
          completer.complete();
        }
      }

      StreamSubscription<DownloadCompleteEvent>? subscription;
      try {
        subscription = DownloadEvent.listenDownloadComplete()
          ..onData(onDownloadComplete)
          ..onError((e, stackTrace) {
            if (e is AndroidDownloadError) {
              if (e.downloadId != id) {
                // not us, ignore
                return;
              }
              completer.completeError(e.error, e.stackTrace);
            } else {
              completer.completeError(e, stackTrace);
            }
          });
        await completer.future;
      } finally {
        subscription?.cancel();
      }
      return uri;
    } on PlatformException catch (e) {
      switch (e.code) {
        case MediaStore.exceptionCodePermissionError:
          throw PermissionException();

        case Download.exceptionCodeDownloadError:
          throw DownloadException(e.message);

        case DownloadEvent.exceptionCodeUserCanceled:
          throw JobCanceledException(e.message);

        default:
          rethrow;
      }
    }
  }

  static final _log = Logger("mobile.file_downloader.FileDownloader");
}
