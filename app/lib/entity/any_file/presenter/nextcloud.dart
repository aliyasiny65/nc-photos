import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:nc_photos/account.dart';
import 'package:nc_photos/api/api_util.dart' as api_util;
import 'package:nc_photos/cache_manager_util.dart';
import 'package:nc_photos/entity/any_file/any_file.dart';
import 'package:nc_photos/entity/any_file/presenter/factory.dart';
import 'package:nc_photos/entity/file_descriptor.dart';
import 'package:nc_photos/file_view_util.dart';
import 'package:nc_photos/np_api_util.dart';
import 'package:nc_photos/use_case/request_public_link.dart';
import 'package:nc_photos/widget/image_viewer.dart';
import 'package:nc_photos/widget/network_thumbnail.dart';
import 'package:nc_photos/widget/photo_list_item.dart';
import 'package:np_log/np_log.dart';
import 'package:np_platform_util/np_platform_util.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

part 'nextcloud.g.dart';

@npLog
class AnyFileNextcloudVideoPlayerControllerPresenter
    implements AnyFileVideoPlayerControllerPresenter {
  AnyFileNextcloudVideoPlayerControllerPresenter(
    AnyFile file, {
    required this.account,
  }) : _provider = file.provider as AnyFileNextcloudProvider;

  @override
  Future<VideoPlayerController> build({LivePhotoType? livePhotoType}) async {
    if (getRawPlatform() != NpPlatform.web) {
      try {
        return _buildVideoControllerWithFileUrl(
          _provider.file,
          livePhotoType: livePhotoType,
        );
      } catch (e, stackTrace) {
        _log.warning(
          "[build] Failed while _buildVideoControllerWithFileUrl",
          e,
          stackTrace,
        );
      }
    }
    return await _buildVideoControllerWithPublicUrl(
      _provider.file,
      livePhotoType: livePhotoType,
    );
  }

  VideoPlayerController _buildVideoControllerWithFileUrl(
    FileDescriptor file, {
    LivePhotoType? livePhotoType,
  }) {
    final uri = api_util.getFileUri(account, file);
    _log.fine("[_buildVideoControllerWithFileUrl] URI: $uri");
    return VideoPlayerController.networkUrl(
      uri,
      httpHeaders: {
        "Authorization": AuthUtil.fromAccount(account).toHeaderValue(),
      },
      livePhotoType: livePhotoType,
    );
  }

  Future<VideoPlayerController> _buildVideoControllerWithPublicUrl(
    FileDescriptor file, {
    LivePhotoType? livePhotoType,
  }) async {
    final url = await RequestPublicLink()(account, file);
    _log.fine("[_buildVideoControllerWithPublicUrl] URL: $url");
    return VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: {
        "Authorization": AuthUtil.fromAccount(account).toHeaderValue(),
      },
      livePhotoType: livePhotoType,
    );
  }

  final Account account;

  final AnyFileNextcloudProvider _provider;
}

class AnyFileNextcloudLargeImagePresenter
    implements AnyFileLargeImagePresenter {
  AnyFileNextcloudLargeImagePresenter(AnyFile file, {required this.account})
    : _provider = file.provider as AnyFileNextcloudProvider;

  @override
  Widget buildWidget({
    BoxFit? fit,
    Widget Function(BuildContext context, Widget child)? imageBuilder,
  }) {
    return CachedNetworkImageBuilder(
      type: CachedNetworkImageType.largeImage,
      imageUrl: getViewerUrlForImageFile(account, _provider.file),
      mime: _provider.file.fdMime,
      account: account,
      fit: fit,
      imageBuilder: (context, child, imageProvider) {
        return imageBuilder?.call(context, child) ?? child;
      },
    ).build();
  }

  final Account account;

  final AnyFileNextcloudProvider _provider;
}

class AnyFileNextcloudImageViewerPresenter
    implements AnyFileImageViewerPresenter {
  AnyFileNextcloudImageViewerPresenter(AnyFile file, {required this.account})
    : _provider = file.provider as AnyFileNextcloudProvider;

  @override
  Widget buildWidget({
    required bool canZoom,
    VoidCallback? onLoaded,
    ValueChanged<double>? onHeightChanged,
    VoidCallback? onZoomStarted,
    VoidCallback? onZoomEnded,
  }) {
    return RemoteImageViewer(
      account: account,
      file: _provider.file,
      canZoom: canZoom,
      onLoaded: onLoaded,
      onHeightChanged: onHeightChanged,
      onZoomStarted: onZoomStarted,
      onZoomEnded: onZoomEnded,
    );
  }

  @override
  void preloadImage() {
    RemoteImageViewer.preloadImage(account, _provider.file);
  }

  final Account account;

  final AnyFileNextcloudProvider _provider;
}

class AnyFileNextcloudPhotoListImagePresenter
    implements AnyFilePhotoListImagePresenter {
  AnyFileNextcloudPhotoListImagePresenter(AnyFile file, {required this.account})
    : _provider = file.provider as AnyFileNextcloudProvider;

  @override
  Widget buildWidget() {
    return PhotoListImage(
      account: account,
      previewUrl: NetworkRectThumbnail.imageUrlForFile(account, _provider.file),
      mime: _provider.file.fdMime,
    );
  }

  final Account account;

  final AnyFileNextcloudProvider _provider;
}
