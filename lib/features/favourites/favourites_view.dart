
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/theme/theme.dart';
import '../../data/models/media_model.dart';
import 'controllers/favourites_controller.dart';

class FavouritesView extends GetView<FavouritesController> {
  const FavouritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(children: [
        // ── Header ─────────────────────────────────────────
        Container(
          color: const Color(0xFF0F0F0F),
          padding: EdgeInsets.fromLTRB(4, top + 8, 8, 0),
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Get.back(),
              ),
              const Expanded(
                child: Text('Favourites',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
              // View mode toggle
              Obx(() => IconButton(
                icon: Icon(
                  controller.viewMode.value == FavViewMode.grid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: Colors.white70,
                ),
                onPressed: controller.toggleViewMode,
              )),
              // Sort menu
              PopupMenuButton<FavSortOrder>(
                icon: const Icon(Icons.sort_rounded,
                    color: Colors.white70),
                color: const Color(0xFF2C2C2C),
                onSelected: controller.setSortOrder,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: FavSortOrder.newest,
                      child: Text('Newest',
                          style: TextStyle(color: Colors.white))),
                  PopupMenuItem(
                      value: FavSortOrder.oldest,
                      child: Text('Oldest',
                          style: TextStyle(color: Colors.white))),
                  PopupMenuItem(
                      value: FavSortOrder.type,
                      child: Text('By type',
                          style: TextStyle(color: Colors.white))),
                ],
              ),
            ]),

            // Stats + filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                Obx(() => _FilterChip(
                  label:
                  '${controller.photoCount} Photos',
                  icon: Icons.photo_outlined,
                  active: controller.showOnlyPhotos.value,
                  onTap: controller.togglePhotoFilter,
                )),
                const SizedBox(width: 8),
                Obx(() => _FilterChip(
                  label:
                  '${controller.videoCount} Videos',
                  icon: Icons.videocam_outlined,
                  active: controller.showOnlyVideos.value,
                  onTap: controller.toggleVideoFilter,
                )),
                const Spacer(),
                // Selection actions
                Obx(() => controller.isSelectionMode.value
                    ? Row(children: [
                  TextButton(
                    onPressed: controller.unfavouriteSelected,
                    child: const Text('Remove',
                        style: TextStyle(
                            color: Colors.redAccent)),
                  ),
                  TextButton(
                    onPressed: controller.exitSelectionMode,
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.white54)),
                  ),
                ])
                    : const SizedBox.shrink()),
              ]),
            ),
          ]),
        ),

        // ── Body ───────────────────────────────────────────
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              );
            }

            final list = controller.displayedItems;
            if (list.isEmpty) return const _EmptyState();

            return controller.viewMode.value == FavViewMode.grid
                ? _FavGrid(items: list, c: controller)
                : _FavList(items: list, c: controller);
          }),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? Colors.red.withOpacity(0.25)
            : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: active ? Colors.redAccent : Colors.transparent,
            width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 13,
            color: active ? Colors.redAccent : Colors.white54),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: active ? Colors.redAccent : Colors.white54,
                fontSize: 12,
                fontWeight: active
                    ? FontWeight.w600
                    : FontWeight.normal)),
      ]),
    ),
  );
}

// ── Grid ──────────────────────────────────────────────────────
class _FavGrid extends StatelessWidget {
  final List<MediaItem> items;
  final FavouritesController c;
  const _FavGrid({required this.items, required this.c});

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(2),
    gridDelegate:
    const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => _Cell(item: items[i], c: c),
  );
}

class _Cell extends StatelessWidget {
  final MediaItem item;
  final FavouritesController c;
  const _Cell({required this.item, required this.c});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      if (c.isSelectionMode.value) {
        c.toggleSelection(item.id);
      } else {
        Get.toNamed('/viewer',
            arguments: {'mediaItem': item});
      }
    },
    onLongPress: () => c.enterSelectionMode(item.id),
    child: Stack(fit: StackFit.expand, children: [
      FutureBuilder<Uint8List?>(
        future: _thumb(item.id),
        builder: (_, snap) => snap.hasData
            ? Image.memory(snap.data!, fit: BoxFit.cover)
            : Container(
            color: Colors.white.withOpacity(0.05)),
      ),
      // Favorite heart badge
      const Positioned(
        top: 4, right: 4,
        child: Icon(Icons.favorite_rounded,
            color: Colors.redAccent, size: 14),
      ),
      // Video badge
      if (item.isVideo)
        const Positioned(
          bottom: 4, left: 4,
          child: Icon(Icons.videocam_rounded,
              color: Colors.white70, size: 14),
        ),
      // Selection
      Obx(() {
        final sel = c.selectedIds.contains(item.id);
        if (!c.isSelectionMode.value) {
          return const SizedBox.shrink();
        }
        return Container(
          color: sel
              ? AppColors.primary.withOpacity(0.4)
              : Colors.transparent,
          child: sel
              ? const Center(
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 28))
              : null,
        );
      }),
    ]),
  );

  Future<Uint8List?> _thumb(String id) async {
    final a = await AssetEntity.fromId(id);
    return a?.thumbnailDataWithSize(const ThumbnailSize(300, 300));
  }
}

// ── List view ─────────────────────────────────────────────────
class _FavList extends StatelessWidget {
  final List<MediaItem> items;
  final FavouritesController c;
  const _FavList({required this.items, required this.c});

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: 4),
    itemCount: items.length,
    separatorBuilder: (_, __) => const Divider(
        color: Colors.white12, height: 1, indent: 72),
    itemBuilder: (_, i) {
      final item = items[i];
      return ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56, height: 56,
            child: FutureBuilder<Uint8List?>(
              future: () async {
                final a = await AssetEntity.fromId(item.id);
                return a?.thumbnailDataWithSize(
                    const ThumbnailSize(112, 112));
              }(),
              builder: (_, snap) => snap.hasData
                  ? Image.memory(snap.data!, fit: BoxFit.cover)
                  : Container(color: Colors.white12),
            ),
          ),
        ),
        title: Text(
          item.isVideo ? 'Video' : 'Photo',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: Text(
          _fmtDate(item.createdAt),
          style: const TextStyle(
              color: Colors.white38, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite_rounded,
              color: Colors.redAccent, size: 20),
          onPressed: () => c.unfavouriteItem(item.id),
        ),
        onTap: () =>
            Get.toNamed('/viewer', arguments: {'mediaItem': item}),
      );
    },
  );

  String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.favorite_border_rounded,
            size: 64, color: Colors.white24),
        SizedBox(height: 16),
        Text('No favourites yet',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text('Tap ♥ on any photo to add it here',
            style: TextStyle(color: Colors.white38)),
      ],
    ),
  );
}