import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_pages.dart';
import '../../../app/theme/theme.dart';
import '../../../data/models/media_model.dart';
import '../../../shared/widgets/media_thumbnail_widget.dart';
import '../../../shared/widgets/navigation_menu/app_bottom_nav.dart';
import '../../../shared/widgets/navigation_menu/bottom_nav_controller.dart';
import '../controllers/gallery_controller.dart';

class GalleryView extends StatelessWidget {
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomNavController = Get.find<BottomNavController>();
    final controller = Get.find<GalleryController>();
    bottomNavController.markTab(BottomNavTab.pictures);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: GetBuilder<GalleryController>(
          builder: (_) {
            final selectedCount = controller.selectedIds.length;
            final allCount = controller.timelineGroups
                .fold<int>(0, (sum, g) => sum + g.items.length);

            return AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) => _handleAction(value, controller),
                      itemBuilder: (_) => [
                        _buildPopupItem(
                            icon: Icons.favorite_border,
                            label: 'Add to Favorites',
                            value: 'favorite',
                            enabled: selectedCount > 0),
                        _buildPopupItem(
                            icon: Icons.folder_outlined,
                            label: 'Move to Album',
                            value: 'move',
                            enabled: selectedCount > 0),
                        const PopupMenuDivider(),
                        _buildPopupItem(
                            icon: Icons.delete_outline,
                            label: 'Move to Trash',
                            value: 'trash',
                            enabled: selectedCount > 0,
                            isDestructive: true),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: GetBuilder<GalleryController>(
        builder: (_) {
          if (!controller.hasPermission.value) {
            return _PermissionDenied(onRetry: controller.refresh);
          }

          if (controller.isLoading.value && controller.timelineGroups.isEmpty) {
            return const _LoadingShimmer();
          }

          // Flatten all media items into a single list
          final allItems = controller.timelineGroups.expand((g) => g.items).toList();

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              itemCount: allItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemBuilder: (context, index) {
                final item = allItems[index];
                return _MediaCell(item: item, controller: controller);
              },
            ),
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem({
    required IconData icon,
    required String label,
    required String value,
    bool enabled = true,
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon,
              color: isDestructive ? Colors.red : Colors.grey.shade700, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.black87,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _handleAction(String value, GalleryController controller) {
    switch (value) {
      case 'favorite':
        controller.toggleFavoriteSelected();
        break;
      case 'move':
        _showMoveToAlbumDialog(controller);
        break;
      case 'trash':
        _showTrashConfirmation(controller);
        break;
    }
  }

  void _showMoveToAlbumDialog(GalleryController controller) {
    Get.defaultDialog(
      title: 'Move to Album',
      content: const Text('Select destination album'),
      confirm: ElevatedButton(
        onPressed: () {
          // TODO: implement album picker
          Get.back();
        },
        child: const Text('Move'),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Cancel'),
      ),
    );
  }

  void _showTrashConfirmation(GalleryController controller) {
    Get.defaultDialog(
      title: 'Move to Trash?',
      middleText: 'Items will be deleted after 30 days',
      textConfirm: 'Move',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: controller.trashSelected,
      onCancel: () => Get.back(),
    );
  }
}

// ── Media Cell ───────────────────────────────────────────
class _MediaCell extends StatelessWidget {
  final MediaItem item;
  final GalleryController controller;
  const _MediaCell({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.selectedIds.contains(item.id);
    return GestureDetector(
      onTap: () {
        if (controller.isSelectionMode.value) {
          controller.toggleSelection(item.id);
        } else {
          Get.toNamed(AppPages.viewer, arguments: {'mediaItem': item});
        }
        controller.update();
      },
      onLongPress: () {
        if (!controller.isSelectionMode.value) {
          controller.enterSelectionMode(item.id);
        }
        controller.update();
      },
      child: Stack(fit: StackFit.expand, children: [
        MediaThumbnailWidget(item: item),
        if (item.type == MediaType.video) _VideoBadge(duration: item.duration),
        if (item.mimeType == 'image/gif') const _GifBadge(),
        if (controller.isSelectionMode.value) _SelectionOverlay(isSelected: isSelected),
      ]),
    );
  }
}

// ── Badges & Overlays ─────────────────────────────────────
class _VideoBadge extends StatelessWidget {
  final Duration duration;
  const _VideoBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    final m = duration.inMinutes.toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('$m:$s',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _GifBadge extends StatelessWidget {
  const _GifBadge();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomLeft,
    child: Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('GIF',
          style: TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    ),
  );
}

class _SelectionOverlay extends StatelessWidget {
  final bool isSelected;
  const _SelectionOverlay({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isSelected ? c.withOpacity(0.28) : Colors.black.withOpacity(0.08),
        border: isSelected ? Border.all(color: c, width: 2.5) : null,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(4),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isSelected ? c : Colors.black26,
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? Colors.white : Colors.white70, width: 2),
          ),
          child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
        ),
      ),
    );
  }
}

// ── Permission Denied & Loading ───────────────────────────
class _PermissionDenied extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionDenied({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text('Allow access to your photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          const Text(
            'Samsung Gallery needs storage permission\nto display your photos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Grant Permission'),
          ),
        ],
      ),
    ),
  );
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
    ),
    itemCount: 40,
    itemBuilder: (_, __) => Container(color: Colors.grey.shade200),
  );
}