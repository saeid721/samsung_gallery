
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/routes/app_pages.dart';
import '../../app/theme/theme.dart';
import '../../data/repositories/album_repository.dart';
import '../../shared/widgets/navigation_menu/app_bottom_nav.dart';
import '../../shared/widgets/navigation_menu/bottom_nav_controller.dart';
import 'controllers/albums_controller.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class AlbumsView extends GetView<AlbumsController> {
  const AlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<BottomNavController>().markTab(BottomNavTab.albums);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        elevation: 2,
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

        // Show error if any
        if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading albums',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage.value,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  textAlign: TextAlign.center,
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

        if (controller.albums.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No albums found',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first album to get started',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
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
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: album.coverAssetId != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _AssetThumbnail(assetId: album.coverAssetId!),
                        )
                        : Center(
                          child: Icon(
                            Icons.folder,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
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
                              : Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${album.itemCount} ${album.itemCount == 1 ? 'photo' : 'photos'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
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
    return FutureBuilder<Uint8List?>(
      future: _loadThumb(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            color: Colors.grey.shade300,
            child: Icon(Icons.broken_image, color: Colors.grey.shade600),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          );
        }

        return Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.image, color: Colors.grey.shade500),
        );
      },
    );
  }

  Future<Uint8List?> _loadThumb() async {
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) {
        if (kDebugMode) print('Asset not found: $assetId');
        return null;
      }

      // Load thumbnail with appropriate size for album covers
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(300, 300),
        format: ThumbnailFormat.jpeg,
        quality: 85,
      );
      return thumbnail;
    } catch (e) {
      if (kDebugMode) print('Error loading thumbnail for $assetId: $e');
      return null;
    }
  }
}