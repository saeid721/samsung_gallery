
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/routes/app_pages.dart';
import '../../app/theme/theme.dart';
import '../../data/repositories/album_repository.dart';
import '../../shared/widgets/navigation_menu/app_bottom_nav.dart';
import '../../shared/widgets/navigation_menu/bottom_nav_controller.dart';
import 'controllers/albums_controller.dart';

class AlbumsView extends GetView<AlbumsController> {
  const AlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<BottomNavController>().markTab(BottomNavTab.albums);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          Obx(() => controller.isSelectionMode.value
              ? TextButton(
            onPressed: _confirmDeleteSelected,
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          )
              : IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateAlbumDialog(context),
          )),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.albums.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No albums found', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85, // Slightly taller than square for label
            ),
            itemCount: controller.albums.length,
            itemBuilder: (context, index) {
              final album = controller.albums[index];
              return _AlbumCard(album: album, controller: controller);
            },
          ),
        );
      }),
    );
  }

  void _showCreateAlbumDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Album'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Album name'),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.createAlbum(textController.text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected() {
    Get.defaultDialog(
      title: 'Delete Albums',
      middleText:
      'Delete ${controller.selectedIds.length} album(s)? Photos will be moved to trash.',
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        Get.back();
        controller.deleteSelectedAlbums();
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  final AlbumsController controller;

  const _AlbumCard({required this.album, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.isSelectionMode.value) {
          controller.toggleSelection(album.id);
        } else {
          Get.toNamed(
            AppPages.gallery,
            arguments: {'albumId': album.id, 'albumName': album.name},
          );
        }
      },
      onLongPress: () {
        if (!controller.isSelectionMode.value) {
          controller.enterSelectionMode(album.id);
        }
      },
      child: Obx(() {
        final isSelected = controller.selectedIds.contains(album.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover thumbnail
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: album.coverAssetId != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _AssetThumbnail(assetId: album.coverAssetId!),
                    )
                        : const Icon(Icons.folder, size: 48, color: Colors.grey),
                  ),
                  // Selection overlay
                  if (controller.isSelectionMode.value)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              album.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${album.itemCount}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        );
      }),
    );
  }
}

// Thumbnail widget using photo_manager
class _AssetThumbnail extends StatelessWidget {
  final String assetId;
  const _AssetThumbnail({required this.assetId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadThumb(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(color: Colors.grey.shade200);
      },
    );
  }

  Future<dynamic> _loadThumb() async {
    final asset = await AssetEntity.fromId(assetId);
    return asset?.thumbnailDataWithSize(const ThumbnailSize(256, 256));
  }
}