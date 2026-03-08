
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/theme/theme.dart';
import '../../data/models/media_model.dart';
import 'controllers/videos_controller.dart';

class VideosView extends GetView<VideosController> {
  const VideosView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Obx(() {
        if (controller.isLoading.value) return _LoadingBody();
        return _Body(c: controller);
      }),
    );
  }
}

class _Body extends StatelessWidget {
  final VideosController c;
  const _Body({required this.c});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        // ── Header ───────────────────────────────────────
        Container(
          color: AppColors.backgroundDark,
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 0),
          child: Column(children: [
            // Title row
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Get.back(),
              ),
              const Text('Videos',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              // Sort menu
              PopupMenuButton<VideoSortOrder>(
                icon: const Icon(Icons.sort_rounded,
                    color: Colors.white70),
                color: const Color(0xFF2C2C2C),
                onSelected: c.setSortOrder,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: VideoSortOrder.newest,
                      child: Text('Newest first',
                          style: TextStyle(color: Colors.white))),
                  PopupMenuItem(
                      value: VideoSortOrder.oldest,
                      child: Text('Oldest first',
                          style: TextStyle(color: Colors.white))),
                  PopupMenuItem(
                      value: VideoSortOrder.longest,
                      child: Text('Longest first',
                          style: TextStyle(color: Colors.white))),
                  PopupMenuItem(
                      value: VideoSortOrder.shortest,
                      child: Text('Shortest first',
                          style: TextStyle(color: Colors.white))),
                  PopupMenuItem(
                      value: VideoSortOrder.largest,
                      child: Text('Largest file',
                          style: TextStyle(color: Colors.white))),
                ],
              ),
            ]),

            // Search bar
            const SizedBox(height: 10),
            _SearchBar(c: c),

            // Filter chips
            const SizedBox(height: 10),
            _FilterChips(c: c),

            // Stats bar
            const SizedBox(height: 8),
            _StatsBar(c: c),
            const SizedBox(height: 8),
          ]),
        ),

        // ── Grid ─────────────────────────────────────────
        Expanded(
          child: Obx(() {
            if (c.filteredVideos.isEmpty) {
              return const _EmptyState();
            }
            return GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                childAspectRatio: 16 / 10,
              ),
              itemCount: c.filteredVideos.length,
              itemBuilder: (_, i) =>
                  _VideoCell(item: c.filteredVideos[i], c: c),
            );
          }),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VideosController c;
  const _SearchBar({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextField(
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: c.onSearchChanged,
      decoration: const InputDecoration(
        hintText: 'Search videos…',
        hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded,
            color: Colors.white38, size: 18),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
}

class _FilterChips extends StatelessWidget {
  final VideosController c;
  const _FilterChips({required this.c});

  static const _labels = {
    VideoFilter.all:    'All',
    VideoFilter.short:  'Short < 1m',
    VideoFilter.medium: 'Medium 1–5m',
    VideoFilter.long:   'Long > 5m',
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: VideoFilter.values.map((f) {
        return Obx(() {
          final active = c.activeFilter.value == f;
          return GestureDetector(
            onTap: () => c.setFilter(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_labels[f]!,
                  style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.white60,
                      fontSize: 12,
                      fontWeight: active
                          ? FontWeight.w600
                          : FontWeight.normal)),
            ),
          );
        });
      }).toList(),
    ),
  );
}

class _StatsBar extends StatelessWidget {
  final VideosController c;
  const _StatsBar({required this.c});

  @override
  Widget build(BuildContext context) => Obx(() => Row(
    children: [
      _StatChip(Icons.videocam_rounded,
          '${c.filteredVideos.length} videos'),
      const SizedBox(width: 12),
      _StatChip(Icons.timer_outlined, c.totalDurationLabel),
      const SizedBox(width: 12),
      _StatChip(Icons.storage_rounded, c.totalSizeLabel),
    ],
  ));
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white38, size: 14),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 12)),
    ],
  );
}

class _VideoCell extends StatelessWidget {
  final MediaItem item;
  final VideosController c;
  const _VideoCell({required this.item, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (c.isSelectionMode.value) {
          c.toggleSelection(item.id);
        } else {
          Get.toNamed('/viewer', arguments: {
            'mediaItem': item,
            'items': c.filteredVideos,
            'index': c.filteredVideos.indexOf(item),
          });
        }
      },
      onLongPress: () => c.enterSelectionMode(item.id),
      child: Stack(fit: StackFit.expand, children: [
        // Thumbnail
        FutureBuilder<Uint8List?>(
          future: _thumb(item.id),
          builder: (_, snap) => snap.hasData
              ? Image.memory(snap.data!, fit: BoxFit.cover)
              : Container(color: Colors.white.withOpacity(0.05)),
        ),

        // Bottom gradient
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.75),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),

        // Play icon
        const Center(
          child: Icon(Icons.play_circle_fill_rounded,
              color: Colors.white70, size: 36),
        ),

        // Duration badge
        Positioned(
          bottom: 6, right: 8,
          child: Text(c.durationLabel(item.duration),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)])),
        ),

        // Selection overlay
        Obx(() {
          final selected = c.selectedIds.contains(item.id);
          if (!c.isSelectionMode.value && !selected) {
            return const SizedBox.shrink();
          }
          return Positioned(
            top: 8, right: 8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          );
        }),
      ]),
    );
  }

  Future<Uint8List?> _thumb(String id) async {
    final a = await AssetEntity.fromId(id);
    return a?.thumbnailDataWithSize(const ThumbnailSize(400, 250));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.videocam_off_outlined,
            size: 64, color: Colors.white24),
        SizedBox(height: 16),
        Text('No videos found',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text('Try a different filter',
            style: TextStyle(color: Colors.white38)),
      ],
    ),
  );
}

class _LoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.backgroundDark,
    body: Center(
      child: CircularProgressIndicator(
          color: AppColors.primary, strokeWidth: 2),
    ),
  );
}