import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../app/routes/app_pages.dart';
import '../../../data/models/media_model.dart' hide TimelineGroup;
import '../../../data/models/timeline_group.dart';
import '../controllers/gallery_controller.dart';
import '../controllers/gallery_grid_controller.dart';
import '../controllers/video_thumbnail_manager.dart';

class GalleryTimelineWidget extends StatelessWidget {
  final List<TimelineGroup>     groups;
  final GalleryController       controller;
  final GalleryGridController   gridCtrl;

  const GalleryTimelineWidget({
    super.key,
    required this.groups,
    required this.controller,
    required this.gridCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _PinchDetector(
          gridCtrl: gridCtrl,
          child: _TimelineScrollView(
            groups:     groups,
            controller: controller,
            gridCtrl:   gridCtrl,
          ),
        ),

        Obx(() => AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity:  gridCtrl.isZooming.value ? 1.0 : 0.0,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _ColumnHud(columns: gridCtrl.columnsCount.value),
            ),
          ),
        )),
      ],
    );
  }
}

class _PinchDetector extends StatefulWidget {
  final GalleryGridController gridCtrl;
  final Widget child;
  const _PinchDetector({required this.gridCtrl, required this.child});

  @override
  State<_PinchDetector> createState() => _PinchDetectorState();
}

class _PinchDetectorState extends State<_PinchDetector> {
  bool _pinching = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onScaleStart: (d) {
        if (d.pointerCount >= 2) {
          _pinching = true;
          widget.gridCtrl.onScaleStart(1.0);
        }
      },
      onScaleUpdate: (d) {
        if (_pinching) {
          widget.gridCtrl.onScaleUpdate(d.scale);
        }
      },
      onScaleEnd: (_) {
        if (_pinching) {
          _pinching = false;
          widget.gridCtrl.onScaleEnd();
        }
      },
      child: widget.child,
    );
  }
}

class _TimelineScrollView extends StatelessWidget {
  final List<TimelineGroup>   groups;
  final GalleryController     controller;
  final GalleryGridController gridCtrl;

  const _TimelineScrollView({
    required this.groups,
    required this.controller,
    required this.gridCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cols = gridCtrl.columnsCount.value;

      return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          for (final group in groups) ...[
            // Samsung Style Header using SliverAppBar (pinned: false for non-sticky)
            SliverAppBar(
              pinned: false,
              floating: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              toolbarHeight: _headerHeightFor(cols),
              title: _DateHeader(
                label:     group.label,
                count:     group.count,
                columns:   cols,
                isSelected: group.isFullySelected(
                    controller.selectedIds.toSet()),
                onSelectAll: () => _toggleGroupSelection(group),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              sliver: SliverGrid(
                key: ValueKey('grid_${group.label}_$cols'),
                delegate: SliverChildBuilderDelegate(
                      (_, index) => _MediaCell(
                    item:       group.items[index],
                    controller: controller,
                    columns:    cols,
                  ),
                  childCount:             group.items.length,
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries:   true,
                ),
                gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   cols,
                  mainAxisSpacing:  _spacingFor(cols),
                  crossAxisSpacing: _spacingFor(cols),
                  childAspectRatio: 1.0,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      );
    });
  }

  double _headerHeightFor(int cols) {
    if (cols >= 10) return 32.0;
    if (cols >= 6)  return 44.0;
    return 56.0;
  }

  void _toggleGroupSelection(TimelineGroup group) {
    final ids = group.items.map((i) => i.id).toSet();
    final isAll = group.items.isNotEmpty &&
        group.items.every((i) => controller.selectedIds.contains(i.id));
    if (isAll) {
      controller.selectedIds.removeAll(ids);
      if (controller.selectedIds.isEmpty) {
        controller.exitSelectionMode();
      }
    } else {
      if (!controller.isSelectionMode.value) {
        controller.enterSelectionMode(group.items.first.id);
      }
      controller.selectedIds.addAll(ids);
    }
  }

  static double _spacingFor(int cols) {
    if (cols <= 2)  return 3.0;
    if (cols <= 4)  return 2.0;
    if (cols <= 8)  return 1.5;
    return 1.0;
  }
}

class _DateHeader extends StatelessWidget {
  final String  label;
  final int     count;
  final int     columns;
  final bool    isSelected;
  final VoidCallback onSelectAll;

  const _DateHeader({
    required this.label,
    required this.count,
    required this.columns,
    required this.isSelected,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    if (columns >= 12) return const SizedBox.shrink();

    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white54 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize:   columns <= 2 ? 18 : (columns <= 4 ? 16 : 14),
                fontWeight: FontWeight.w700,
                color:      textColor,
                letterSpacing: -0.2,
              ),
            ),
          ),

          if (columns <= 6) ...[
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color:    subColor,
              ),
            ),
            const SizedBox(width: 12),
          ],

          GestureDetector(
            onTap: onSelectAll,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width:  22,
              height: 22,
              decoration: BoxDecoration(
                color:  isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                shape:  BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.white38 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 14)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaCell extends StatelessWidget {
  final MediaItem         item;
  final GalleryController controller;
  final int               columns;

  const _MediaCell({
    super.key,
    required this.item,
    required this.controller,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.isSelectionMode.value) {
          controller.toggleSelection(item.id);
        } else {
          Get.toNamed(AppPages.viewer,
              arguments: {'mediaItem': item});
        }
      },
      onLongPress: () {
        if (!controller.isSelectionMode.value) {
          controller.enterSelectionMode(item.id);
        }
      },
      child: Obx(() {
        final selected = controller.selectedIds.contains(item.id);
        return Stack(
          fit: StackFit.expand,
          children: [
            _Thumbnail(item: item, columns: columns),

            // NO play button as requested. Only duration and favorite.

            if (item.isVideo)
              _VideoBadge(
                  duration: item.duration, columns: columns),

            if (item.isGif)
              _GifBadge(columns: columns),

            if (item.isFavorite.value && columns <= 6)
              const Positioned(
                top:   4,
                right: 4,
                child: Icon(Icons.favorite_rounded,
                    color: Colors.redAccent, size: 12),
              ),

            if (controller.isSelectionMode.value)
              _SelectionOverlay(
                  isSelected: selected, columns: columns),
          ],
        );
      }),
    );
  }
}

class _Thumbnail extends StatefulWidget {
  final MediaItem item;
  final int    columns;
  const _Thumbnail({required this.item, required this.columns});

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  VideoPlayerController? _videoController;
  final VideoThumbnailManager _videoManager = Get.find<VideoThumbnailManager>();
  Future<Uint8List?>? _thumbnailFuture;
  ThumbnailSize? _currentSize;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(_Thumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.columns != oldWidget.columns) {
      _loadThumbnail();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadThumbnail();
  }

  void _loadThumbnail() {
    final newSize = _thumbSize;
    if (_currentSize != newSize) {
      _currentSize = newSize;
      _thumbnailFuture = widget.item.entity?.thumbnailDataWithSize(newSize);
    }
  }

  void _initializeVideo() {
    _videoController = _videoManager.getController(
      widget.item.id,
      () async => (await widget.item.entity?.originFile)?.path,
    );
  }

  ThumbnailSize get _thumbSize {
    if (widget.columns >= 10) return const ThumbnailSize(120, 120);
    if (widget.columns >= 6)  return const ThumbnailSize(200, 200);
    if (widget.columns >= 3)  return const ThumbnailSize(360, 360);
    return const ThumbnailSize(640, 640);
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.item.entity;
    if (asset == null) return Container(color: Colors.grey.shade200);

    return VisibilityDetector(
      key: Key('thumbnail_${widget.item.id}'),
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
              future: _thumbnailFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                }
                return Container(color: Colors.grey.shade200);
              },
            ),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  final Duration duration;
  final int      columns;
  const _VideoBadge({required this.duration, required this.columns});

  @override
  Widget build(BuildContext context) {
    final m    = duration.inMinutes.toString().padLeft(1, '0');
    final s    = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final size = columns >= 8 ? 8.0 : (columns >= 4 ? 10.0 : 12.0);

    return Positioned(
      bottom: 4,
      right:  4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color:        Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$m:$s',
          style: TextStyle(
            color:      Colors.white,
            fontSize:   size,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GifBadge extends StatelessWidget {
  final int columns;
  const _GifBadge({required this.columns});

  @override
  Widget build(BuildContext context) {
    if (columns >= 12) return const SizedBox.shrink();
    return Positioned(
      bottom: 4,
      left:  4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color:        Colors.purpleAccent.shade700,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'GIF',
          style: TextStyle(
            color:      Colors.white,
            fontSize:   columns >= 6 ? 8 : 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _SelectionOverlay extends StatelessWidget {
  final bool isSelected;
  final int  columns;
  const _SelectionOverlay(
      {required this.isSelected, required this.columns});

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final dotSize  = columns >= 8 ? 16.0 : 22.0;
    final iconSize = columns >= 8 ? 10.0 : 14.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color:  isSelected
            ? primary.withOpacity(0.28)
            : Colors.transparent,
        border: isSelected
            ? Border.all(color: primary, width: 2)
            : null,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width:  dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color:  isSelected ? primary       : Colors.black26,
              shape:  BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white60,
                width: 1.5,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check_rounded,
                color: Colors.white, size: iconSize)
                : null,
          ),
        ),
      ),
    );
  }
}

class _ColumnHud extends StatelessWidget {
  final int columns;
  const _ColumnHud({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_view_rounded,
              color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(
            '$columns × $columns',
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}