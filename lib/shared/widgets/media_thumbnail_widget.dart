import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../data/models/media_model.dart';
import '../../../app/theme/theme.dart';
import '../../features/gallery/controllers/video_thumbnail_manager.dart';
import 'package:get/get.dart';

class MediaThumbnailWidget extends StatelessWidget {
  final MediaItem item;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onTap;
  final bool showBadges;

  const MediaThumbnailWidget({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.onTap,
    this.showBadges = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _buildThumbnail(context),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Efficient Thumbnail Loading (with Autoplay for videos)
        _ThumbnailImage(item: item, width: width, height: height, fit: fit),

        // Badges
        if (showBadges) ...[
          // Video Duration
          if (item.type == MediaType.video)
            _VideoBadge(duration: item.duration),

          // GIF Badge
          if (item.mimeType == 'image/gif')
             _GifBadge(),

          // Favorite badge (Samsung-style heart)
          if (item.isFavorite.value)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 16,
                ),
              ),
            ),

          // Locked/Secure badge
          if (item.isSecure)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ThumbnailImage extends StatefulWidget {
  final MediaItem item;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _ThumbnailImage({
    required this.item,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<_ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<_ThumbnailImage> {
  VideoPlayerController? _videoController;
  final VideoThumbnailManager _videoManager = Get.find<VideoThumbnailManager>();

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    _videoController = _videoManager.getController(
      widget.item.id,
      () async => (await widget.item.entity?.originFile)?.path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.item.entity;
    if (asset == null) return const _ErrorPlaceholder();

    return VisibilityDetector(
      key: Key('thumb_shared_${widget.item.id}'),
      onVisibilityChanged: (info) {
        if (widget.item.isVideo && _videoController != null) {
          if (info.visibleFraction > 0.8) {
            _videoManager.activateVideo(widget.item.id);
          } else {
            _videoManager.deactivateVideo(widget.item.id);
          }
        }
      },
      child: widget.item.isVideo && _videoController != null && _videoController!.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          : FutureBuilder<Uint8List?>(
              future: asset.thumbnailDataWithSize(const ThumbnailSize(256, 256)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ShimmerPlaceholder();
                }

                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    width: widget.width,
                    height: widget.height,
                    fit: widget.fit,
                    gaplessPlayback: true,
                  );
                }

                return const _ErrorPlaceholder();
              },
            ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  final Duration duration;
  const _VideoBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    final m = duration.inMinutes.toString();
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$m:$s',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _GifBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purpleAccent.shade700,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: const Text(
          'GIF',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.shimmerBase,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}