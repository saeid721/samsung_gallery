// ============================================================
// features/gallery/widgets/gallery_timeline_widget.dart
// ============================================================
// Pinch-zoomable photo timeline that matches Samsung Gallery UX:
//
//  • 1–20 column grid, changed by pinch gesture
//  • Date headers ("9–18 Feb", "7 Feb") above each group
//  • Video duration badge  ▶ 0:16
//  • Semi-transparent column-count HUD during gesture
//  • AnimatedSwitcher for smooth column transitions
//  • Selection overlay (tick circle) in selection mode
//  • Works as a drop-in child — receives groups + controller
//
// USAGE:
//   GalleryTimelineWidget(
//     groups:     controller.timelineGroups,
//     controller: controller,
//     gridCtrl:   Get.find<GalleryGridController>(),
//   )
// ============================================================

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
        // ── Pinch-gesture detector wraps the scroll view ───────
        _PinchDetector(
          gridCtrl: gridCtrl,
          child: _TimelineScrollView(
            groups:     groups,
            controller: controller,
            gridCtrl:   gridCtrl,
          ),
        ),

        // ── Column count HUD (shown during gesture) ────────────
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

// ══════════════════════════════════════════════════════════════
// PINCH GESTURE DETECTOR
// ══════════════════════════════════════════════════════════════

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
      // We need to allow scroll + pinch simultaneously.
      // behavior: deferToChild lets the ListView scroll,
      // while onScale* intercepts the two-finger pinch.
      behavior: HitTestBehavior.deferToChild,
      onScaleStart: (d) {
        // Only activate on actual two-finger pinch (pointerCount >= 2).
        // ScaleStartDetails has no .scale — gesture always starts at 1.0.
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

// ══════════════════════════════════════════════════════════════
// TIMELINE SCROLL VIEW
// ══════════════════════════════════════════════════════════════

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
        // BouncingScrollPhysics keeps scroll working during pinch
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          for (final group in groups) ...[
            // ── Date header ──────────────────────────────────
            SliverToBoxAdapter(
              child: _DateHeader(
                label:     group.label,
                count:     group.count,
                columns:   cols,
                isSelected: group.isFullySelected(
                    controller.selectedIds.toSet()),
                onSelectAll: () => _toggleGroupSelection(group),
              ),
            ),

            // ── Photo grid for this date group ───────────────
            // AnimatedSwitcher gives smooth tile-size transition
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
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries:   true,
                  findChildIndexCallback: (key) {
                    if (key is ValueKey<String>) {
                      return group.items.indexWhere(
                              (i) => i.id == key.value);
                    }
                    return null;
                  },
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

          // Bottom padding clears the nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      );
    });
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

  // Tighter spacing at high column counts
  static double _spacingFor(int cols) {
    if (cols <= 2)  return 3.0;
    if (cols <= 4)  return 2.0;
    if (cols <= 8)  return 1.5;
    return 1.0;
  }
}

// ══════════════════════════════════════════════════════════════
// DATE HEADER
// ══════════════════════════════════════════════════════════════

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
    // At very high zoom-out (many tiny columns) hide header to save space
    if (columns >= 12) return const SizedBox(height: 4);

    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white54 : Colors.black38;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        columns <= 4 ? 18 : 12,
        12,
        columns <= 4 ? 8  : 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date label — size shrinks at smaller column counts
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize:   columns <= 2 ? 18 : (columns <= 4 ? 15 : 13),
                fontWeight: FontWeight.w700,
                color:      textColor,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // Item count — only show at normal zoom
          if (columns <= 6)
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color:    subColor,
              ),
            ),

          // "Select all in group" circle checkbox
          const SizedBox(width: 10),
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

// ══════════════════════════════════════════════════════════════
// MEDIA CELL
// ══════════════════════════════════════════════════════════════

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
            // ── Thumbnail ──────────────────────────────
            _Thumbnail(id: item.id, columns: columns),

            // ── Video play overlay ──────────────────────
            if (item.isVideo)
              Positioned.fill(
                child: _VideoPlayButton(
                  duration: item.duration,
                  columns: columns,
                ),
              ),

            // ── Video duration badge ───────────────────
            if (item.isVideo)
              _VideoBadge(
                  duration: item.duration, columns: columns),

            // ── GIF badge ──────────────────────────────
            if (item.isGif)
              _GifBadge(columns: columns),

            // ── Favourite heart ────────────────────────
            if (item.isFavorite.value && columns <= 6)
              const Positioned(
                top:   4,
                right: 4,
                child: Icon(Icons.favorite_rounded,
                    color: Colors.redAccent, size: 12),
              ),

            // ── Selection overlay ──────────────────────
            if (controller.isSelectionMode.value)
              _SelectionOverlay(
                  isSelected: selected, columns: columns),
          ],
        );
      }),
    );
  }
}

// ── Thumbnail ─────────────────────────────────────────────────
class _Thumbnail extends StatefulWidget {
  final String id;
  final int    columns;
  const _Thumbnail({required this.id, required this.columns});

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  final VideoThumbnailManager _videoManager = Get.find<VideoThumbnailManager>();

  @override
  void initState() {
    super.initState();
    _initializeThumbnail();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeThumbnail() async {
    final asset = await AssetEntity.fromId(widget.id);
    if (asset != null && asset.type == AssetType.video) {
      _isVideo = true;
      _videoController = _videoManager.getController(
        widget.id,
        () async => (await asset.originFile)?.path,
      );
    }
  }

  // Thumb resolution: smaller at high column counts saves memory
  ThumbnailSize get _thumbSize {
    if (widget.columns >= 10) return const ThumbnailSize(80,  80);
    if (widget.columns >= 6)  return const ThumbnailSize(150, 150);
    if (widget.columns >= 3)  return const ThumbnailSize(240, 240);
    return               const ThumbnailSize(480, 480);
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('thumbnail_${widget.id}'),
      onVisibilityChanged: (info) {
        if (_isVideo && _videoController != null) {
          if (info.visibleFraction > 0.5) {
            // Thumbnail is visible, activate video playback
            _videoManager.activateVideo(widget.id);
          } else {
            // Thumbnail is not visible, deactivate video playback
            _videoManager.deactivateVideo(widget.id);
          }
        }
      },
      child: _isVideo && _videoController != null && _videoController!.value.isInitialized
          ? AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            )
          : FutureBuilder<Uint8List?>(
              future: _loadStaticThumbnail(),
              builder: (_, snap) {
                if (snap.hasData && snap.data != null) {
                  return Image.memory(
                    snap.data!,
                    fit:         BoxFit.cover,
                    cacheWidth:  _thumbSize.width.toInt(),
                    cacheHeight: _thumbSize.height.toInt(),
                    // Fade in
                    frameBuilder: (_, child, frame, wasSynchronous) {
                      if (wasSynchronous || frame != null) return child;
                      return AnimatedOpacity(
                        opacity:  frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child:    child,
                      );
                    },
                  );
                }
                // Placeholder
                return Container(
                  color: Colors.grey.shade200,
                );
              },
            ),
    );
  }

  Future<Uint8List?> _loadStaticThumbnail() async {
    final asset = await AssetEntity.fromId(widget.id);
    return asset?.thumbnailDataWithSize(
      _thumbSize,
      format:  ThumbnailFormat.jpeg,
      quality: 85,
    );
  }
}

// ── Video badge ───────────────────────────────────────────────
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
      bottom: 3,
      left:   3,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: columns >= 8 ? 3 : 5,
          vertical:   1,
        ),
        decoration: BoxDecoration(
          color:        Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (columns <= 10)
              Icon(Icons.play_arrow_rounded,
                  color: Colors.white,
                  size:  size + 2),
            Text(
              '$m:$s',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   size,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GIF badge ─────────────────────────────────────────────────
class _GifBadge extends StatelessWidget {
  final int columns;
  const _GifBadge({required this.columns});

  @override
  Widget build(BuildContext context) {
    if (columns >= 12) return const SizedBox.shrink();
    return Positioned(
      bottom: 3,
      right:  3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color:        Colors.purpleAccent.shade700,
          borderRadius: BorderRadius.circular(3),
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

// ── Selection overlay ─────────────────────────────────────────
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

// ══════════════════════════════════════════════════════════════
// COLUMN COUNT HUD
// ══════════════════════════════════════════════════════════════

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

// ── Video play button ─────────────────────────────────────────
class _VideoPlayButton extends StatelessWidget {
  final Duration duration;
  final int      columns;
  const _VideoPlayButton({required this.duration, required this.columns});

  @override
  Widget build(BuildContext context) {
    final size = columns >= 8 ? 36.0 : (columns >= 4 ? 48.0 : 60.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}
