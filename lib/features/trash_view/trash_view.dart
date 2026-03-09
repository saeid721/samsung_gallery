import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../data/models/trash_model.dart';
import '../../shared/widgets/navigation_menu/app_bottom_nav.dart';
import '../../shared/widgets/navigation_menu/bottom_nav_controller.dart';
import 'controllers/trash_controller.dart';

class TrashView extends GetView<TrashController> {
  const TrashView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<BottomNavController>().markTab(BottomNavTab.more);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Recently Deleted',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Obx(() => controller.itemCount > 0
              ? TextButton(
                  onPressed: () => _confirmEmptyTrash(context),
                  child: const Text(
                    'Empty',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          );
        }

        if (controller.trashedItems.isEmpty) {
          return const _EmptyTrash();
        }

        return Column(
          children: [
            // Info banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Items are permanently deleted after 30 days.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade200,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Expiring soon warning
            Obx(() => controller.expiringSoon.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${controller.expiringSoon.length} item(s) will be deleted in ${controller.expiringSoon.first.daysRemaining} day(s).',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade200,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink()),

            // Trash grid
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                color: Colors.white,
                backgroundColor: Colors.grey.shade800,
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: controller.trashedItems.length,
                  itemBuilder: (context, index) {
                    final item = controller.trashedItems[index];
                    return _TrashCell(
                      trashedItem: item,
                      onRestore: () => controller.restoreItem(item.item.id),
                      onDelete: () => controller.deleteItemPermanently(item.item.id),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _confirmEmptyTrash(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Empty Recently Deleted?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'All ${controller.itemCount} item(s) will be permanently deleted. This cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.emptyTrash();
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashCell extends StatelessWidget {
  final TrashedItem trashedItem;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _TrashCell({
    required this.trashedItem,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail with overlay
        FutureBuilder(
          future: _loadThumb(),
          builder: (_, snap) => snap.hasData
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      snap.data!,
                      fit: BoxFit.cover,
                    ),
                    // Dark overlay for deleted appearance
                    Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                )
              : Container(
                  color: Colors.grey.shade800,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.white30,
                    size: 32,
                  ),
                ),
        ),

        // Time remaining badge
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: trashedItem.isExpiringSoon
                  ? Colors.red.withOpacity(0.8)
                  : Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trashedItem.timeRemainingString,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Restore button
        Positioned(
          bottom: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRestore,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restore,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),

        // Delete permanently button
        Positioned(
          bottom: 6,
          left: 6,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<dynamic> _loadThumb() async {
    final asset = await AssetEntity.fromId(trashedItem.item.id);
    return asset?.thumbnailDataWithSize(const ThumbnailSize(256, 256));
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.delete_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Trash is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Deleted photos appear here\nfor 30 days before removal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}