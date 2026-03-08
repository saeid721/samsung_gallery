import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../data/models/media_model.dart';
import '../../../app/theme/theme.dart';

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
      child: _buildThumbnail(context),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    // Video thumbnail with play indicator
    if (item.type == MediaType.video) {
      return _VideoThumbnail(item: item, width: width, height: height, fit: fit);
    }

    // GIF thumbnail with animated badge
    if (item.mimeType == 'image/gif') {
      return _GifThumbnail(item: item, width: width, height: height, fit: fit);
    }

    // Regular image thumbnail
    return _ImageThumbnail(item: item, width: width, height: height, fit: fit);
  }
}

// ── Image Thumbnail ──────────────────────────────────────────
class _ImageThumbnail extends StatelessWidget {
  final MediaItem item;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _ImageThumbnail({
    required this.item,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Load thumbnail from phone storage
          FutureBuilder<Uint8List?>(
            future: _loadThumbnail(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _ShimmerPlaceholder();
              }

              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(
                  snapshot.data!,
                  width: width,
                  height: height,
                  fit: fit,
                  gaplessPlayback: true,
                );
              }

              return _ErrorPlaceholder();
            },
          ),

          // Favorite badge (Samsung-style heart)
          if (item.isFavorite.value)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
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
                decoration: BoxDecoration(
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
      ),
    );
  }

  Future<Uint8List?> _loadThumbnail() async {
    try {
      // Use photo_manager to load thumbnail directly
      final asset = await AssetEntity.fromId(item.id);
      if (asset == null) return null;

      // Get thumbnail as bytes with appropriate size
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(256, 256),
        format: ThumbnailFormat.jpeg,
        quality: 85,
      );

      return bytes;
    } catch (e) {
      debugPrint('Error loading thumbnail for ${item.id}: $e');
      return null;
    }
  }
}

// ── Video Thumbnail ──────────────────────────────────────────
class _VideoThumbnail extends StatelessWidget {
  final MediaItem item;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _VideoThumbnail({
    required this.item,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ImageThumbnail(item: item, width: width, height: height, fit: fit),

        // Play button overlay (Samsung-style)
        Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 1),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),

        // Duration badge (bottom-right)
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatDuration(item.duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return mins > 0 ? '$mins:${secs.toString().padLeft(2, '0')}' : '0:$secs';
  }
}

// ── GIF Thumbnail ───────────────────────────────────────────
class _GifThumbnail extends StatelessWidget {
  final MediaItem item;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _GifThumbnail({
    required this.item,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ImageThumbnail(item: item, width: width, height: height, fit: fit),

        // GIF badge (bottom-left, Samsung-style purple)
        Positioned(
          bottom: 4,
          left: 4,
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
        ),
      ],
    );
  }
}

// ── Placeholder & Error Widgets ─────────────────────────────
class _ShimmerPlaceholder extends StatelessWidget {
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