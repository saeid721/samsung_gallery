
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/media_model.dart';
import 'controllers/media_viewer_controller.dart';

class MediaViewerView extends GetView<MediaViewerController> {
  const MediaViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    // Hide system UI for immersive full-screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return WillPopScope(
      onWillPop: () async {
        // Restore system UI on back
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Obx(() {
          if (controller.items.isEmpty) {
            return const Center(
              child: Text('No media', style: TextStyle(color: Colors.white)),
            );
          }

          return Stack(
            children: [
              // ── Photo/Video PageView ──────────────────────
              _MediaPageView(controller: controller),

              // ── Top chrome (app bar) ──────────────────────
              Obx(() => AnimatedOpacity(
                opacity: controller.showChrome.value ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _TopBar(controller: controller),
              )),

              // ── Bottom chrome (action bar) ────────────────
              Obx(() => AnimatedOpacity(
                opacity: controller.showChrome.value ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _BottomBar(controller: controller),
              )),
            ],
          );
        }),
      ),
    );
  }
}

// ── Swipeable photo/video gallery ──────────────────────────
class _MediaPageView extends StatelessWidget {
  final MediaViewerController controller;
  const _MediaPageView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      itemCount: controller.items.length,
      pageController: PageController(initialPage: controller.currentIndex.value),
      onPageChanged: controller.goToIndex,
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (context, index) {
        final item = controller.items[index];

        if (item.isVideo) {
          return PhotoViewGalleryPageOptions.customChild(
            child: _VideoPlayerWidget(item: item, controller: controller),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        }

        // Image: load full-resolution bytes from photo_manager
        return PhotoViewGalleryPageOptions(
          imageProvider: _AssetImageProvider(item.id),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          heroAttributes: PhotoViewHeroAttributes(tag: 'media_${item.id}'),
          filterQuality: FilterQuality.high,
          gestureDetectorBehavior: HitTestBehavior.translucent,
          onTapUp: (_, __, ___) => controller.toggleChrome(),
        );
      },
      loadingBuilder: (context, event) => Center(
        child: CircularProgressIndicator(
          value: event?.expectedTotalBytes != null
              ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
              : null,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Top navigation bar ──────────────────────────────────────
class _TopBar extends StatelessWidget {
  final MediaViewerController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  Get.back();
                },
              ),
              const Spacer(),
              // Item counter "3 / 24"
              Obx(() => Text(
                '${controller.currentIndex.value + 1} / ${controller.items.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )),
              const Spacer(),
              // Info button — shows EXIF panel
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () => _showExifPanel(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExifPanel(BuildContext context) async {
    await controller.loadExif();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExifPanel(controller: controller),
    );
  }
}

// ── Bottom action bar ───────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final MediaViewerController controller;
  const _BottomBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Obx(() {
            final item = controller.currentItem.value;
            if (item == null) return const SizedBox.shrink();

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Favorite
                Obx(() => IconButton(
                  icon: Icon(
                    item.isFavorite.value
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: item.isFavorite.value ? Colors.red : Colors.white,
                  ),
                  onPressed: controller.toggleFavorite,
                )),
                // Edit
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: controller.openEditor,
                ),
                // Share
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  onPressed: () => _shareItem(item),
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _shareItem(MediaItem item) async {
    final asset = await AssetEntity.fromId(item.id);
    final file = await asset?.originFile;
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: const Text('You can restore it within 30 days.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteCurrentItem();
            },
            child: const Text('Move to Trash',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── EXIF info panel ─────────────────────────────────────────
class _ExifPanel extends StatelessWidget {
  final MediaViewerController controller;
  const _ExifPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingExif.value) {
        return const SizedBox(
          height: 200,
          child: Center(
              child: CircularProgressIndicator(color: Colors.white)),
        );
      }

      final exif = controller.exifData.value;
      final item = controller.currentItem.value;

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (item != null) ...[
              _ExifRow(Icons.calendar_today, 'Date',
                  _formatDate(item.createdAt)),
              _ExifRow(Icons.photo_size_select_actual, 'Size',
                  '${item.width} × ${item.height}'),
              _ExifRow(Icons.storage, 'File size',
                  _formatBytes(item.size)),
            ],
            if (exif?.cameraDisplay != null)
              _ExifRow(Icons.camera_alt, 'Camera', exif!.cameraDisplay!),
            if (exif?.exposureDisplay != null)
              _ExifRow(Icons.exposure, 'Exposure', exif!.exposureDisplay!),
            if (exif?.hasLocation == true)
              _ExifRow(Icons.location_on, 'Location',
                  '${exif!.latitude!.toStringAsFixed(4)}, '
                      '${exif.longitude!.toStringAsFixed(4)}'),
            const SizedBox(height: 8),
          ],
        ),
      );
    });
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ExifRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ExifRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Text('$label  ',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Video player stub ───────────────────────────────────────
class _VideoPlayerWidget extends StatelessWidget {
  final MediaItem item;
  final MediaViewerController controller;
  const _VideoPlayerWidget({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Full implementation uses video_player package.
    // See: pub.dev/packages/video_player
    return GestureDetector(
      onTap: controller.toggleChrome,
      child: Center(
        child: Obx(() => Icon(
          controller.isVideoPlaying.value
              ? Icons.pause_circle
              : Icons.play_circle,
          size: 72,
          color: Colors.white,
        )),
      ),
    );
  }
}

// ── Image provider that loads from photo_manager ────────────
class _AssetImageProvider extends ImageProvider<_AssetImageProvider> {
  final String assetId;
  const _AssetImageProvider(this.assetId);

  @override
  Future<_AssetImageProvider> obtainKey(ImageConfiguration config) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadBuffer(
      _AssetImageProvider key, DecoderBufferCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(decode),
      scale: 1.0,
    );
  }

  Future<Codec> _loadAsync(DecoderBufferCallback decode) async {
    final asset = await AssetEntity.fromId(assetId);
    final bytes = await asset?.originBytes;
    if (bytes == null) throw Exception('Could not load asset $assetId');
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is _AssetImageProvider && assetId == other.assetId;

  @override
  int get hashCode => assetId.hashCode;
}