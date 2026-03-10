import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_pages.dart';
import '../../../app/theme/theme.dart';
import '../../../shared/widgets/navigation_menu/app_bottom_nav.dart';
import '../../../shared/widgets/navigation_menu/bottom_nav_controller.dart';
import '../controllers/gallery_controller.dart';
import '../controllers/gallery_grid_controller.dart';
import '../widgets/gallery_timeline_widget.dart';

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
        child: Obx(() {
          final selectedCount = controller.selectedIds.length;
          final allCount = controller.timelineGroups
              .fold<int>(0, (sum, g) => sum + g.items.length);

          // Show album name if viewing specific album
          final title = controller.currentAlbumName.value.isNotEmpty
              ? controller.currentAlbumName.value
              : 'Gallery';

          return AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.isSelectionMode.value)
                  Text('$selectedCount / $allCount selected', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))
                else
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            actions: [
              Row(
                children: [
                  if (!controller.isSelectionMode.value)
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      onPressed: () => Get.toNamed(AppPages.search),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) => _handleAction(value, controller),
                    itemBuilder: (_) => [
                      _buildPopupItem(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          value: 'edit',
                          enabled: selectedCount > 0),
                      _buildPopupItem(
                          icon: Icons.select_all,
                          label: 'Select All',
                          value: 'select_all',
                          enabled: selectedCount > 0),
                      _buildPopupItem(
                          icon: Icons.add_circle_outline,
                          label: 'Create',
                          value: 'create',
                          enabled: selectedCount > 0,
                          isDestructive: true),
                      _buildPopupItem(
                          icon: Icons.group_work_outlined,
                          label: 'Group Similar Images',
                          value: 'group_similar_image',
                          enabled: selectedCount > 0,
                          isDestructive: true),
                      _buildPopupItem(
                          icon: Icons.slideshow,
                          label: 'Start Slideshow',
                          value: 'start_slideshow',
                          enabled: selectedCount > 0,
                          isDestructive: true),
                    ],
                  ),
                ],
              ),
            ],
          );
        }),
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: Obx(() {
        if (!controller.hasPermission.value) {
          return _PermissionDenied(onRetry: controller.refresh);
        }

        if (controller.isLoading.value && controller.timelineGroups.isEmpty) {
          return const _LoadingShimmer();
        }

        // Show error if any
        if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading photos',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage.value,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Flatten all media items into a single list
        final allItems = controller.timelineGroups.expand((g) => g.items).toList();

        if (allItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No photos found', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.refresh,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: GalleryTimelineWidget(
            groups: controller.timelineGroups.toList(),
            controller: controller,
            gridCtrl: Get.find<GalleryGridController>(),
          ),
        );
      }),
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