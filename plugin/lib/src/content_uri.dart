import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:nc_photos_plugin/src/exception.dart';
import 'package:nc_photos_plugin/src/k.dart' as k;

class ContentUri {
  static Future<Uint8List> readUri(String uri) async {
    try {
      return await _methodChannel.invokeMethod("readUri", <String, dynamic>{
        "uri": uri,
      });
    } on PlatformException catch (e) {
      if (e.code == _exceptionFileNotFound) {
        throw const FileNotFoundException();
      } else {
        rethrow;
      }
    }
  }

  static Future<String> getUriForFile(String filePath) async {
    return await _methodChannel.invokeMethod("getUriForFile", <String, dynamic>{
      "filePath": filePath,
    });
  }

  static const _methodChannel = MethodChannel("${k.libId}/content_uri_method");

  static const _exceptionFileNotFound = "fileNotFoundException";
}
