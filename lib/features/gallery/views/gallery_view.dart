import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_pages.dart';
import '../../../app/theme/theme.dart';
import '../../../data/models/media_model.dart';
import '../../../shared/widgets/media_thumbnail_widget.dart';
import '../../../shared/widgets/selection_app_bar.dart';
import '../../../shared/widgets/timeline_header_widget.dart';
import '../controllers/gallery_controller.dart';

class GalleryView extends GetView<GalleryController> {
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        if (!controller.hasPermission.value && !controller.isLoading.value) {
          return _PermissionDeniedWidget(onRetry: controller.refresh);
        }

        if (controller.isLoading.value && controller.timelineGroups.isEmpty) {
          return const _LoadingShimmer();
        }

        // ✅ RefreshIndicator now properly wraps the CustomScrollView
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              Obx(() => controller.isSelectionMode.value
                  ? const SelectionAppBar()
                  : _buildMainAppBar()),

              // ✅ Timeline groups with proper spread syntax
              ...controller.timelineGroups.map((group) => [
                SliverToBoxAdapter(
                  child: TimelineHeaderWidget(group: group),
                ),
                _buildGrid(context, group),
              ]).expand((widgets) => widgets),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      }),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFab(),
    );
  }

  SliverGrid _buildGrid(BuildContext context, TimelineGroup group) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final item = group.items[index];
          return _MediaCell(item: item, controller: controller);
        },
        childCount: group.items.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        // ✅ Add findChildIndexCallback for better item tracking
        findChildIndexCallback: (Key key) {
          if (key is ValueKey<String>) {
            return group.items.indexWhere((item) => item.id == key.value);
          }
          return null;
        },
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
    );
  }

  Widget _buildMainAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      title: const Text(
        'Gallery',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Get.toNamed(AppPages.search),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showMoreMenu,
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      destinations: const [
        NavigationDestination(icon: Icon(Icons.photo_library), label: 'Photos'),
        NavigationDestination(icon: Icon(Icons.folder), label: 'Albums'),
        NavigationDestination(icon: Icon(Icons.category), label: 'Categories'),
        NavigationDestination(icon: Icon(Icons.person), label: 'People'),
      ],
      onDestinationSelected: (index) {
        switch (index) {
          case 1: Get.toNamed(AppPages.albums); break;
          case 2: Get.toNamed(AppPages.categories); break;
          case 3: Get.toNamed(AppPages.people); break;
          default: break;
        }
      },
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => Get.toNamed(AppPages.memories),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Memories'),
    );
  }

  void _showMoreMenu() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.face),
              title: const Text('Scan Faces'),
              onTap: () {
                Get.back();
                controller.startFaceGrouping();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Find Duplicates'),
              onTap: () {
                Get.back();
                Get.toNamed(AppPages.duplicates);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Trash Bin'),
              onTap: () {
                Get.back();
                Get.toNamed(AppPages.trash);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Secure Folder'),
              onTap: () {
                Get.back();
                Get.toNamed(AppPages.secureFolder);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

// ── Individual Grid Cell ────────────────────────────────────
class _MediaCell extends StatelessWidget {
  final MediaItem item;
  final GalleryController controller;

  const _MediaCell({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.isSelectionMode.value) {
          controller.toggleSelection(item.id);
        } else {
          Get.toNamed(AppPages.viewer, arguments: {'mediaItem': item});
        }
      },
      onLongPress: () {
        if (!controller.isSelectionMode.value) {
          controller.enterSelectionMode(item.id);
        }
      },
      child: Obx(() {
        final isSelected = controller.selectedIds.contains(item.id);
        return Stack(
          fit: StackFit.expand,
          children: [
            // ✅ Uncommented - actual thumbnail display
            MediaThumbnailWidget(item: item),

            if (item.type == MediaType.video)
              _VideoBadge(duration: item.duration),

            if (item.mimeType == 'image/gif')
              const _GifBadge(),

            if (controller.isSelectionMode.value)
              _SelectionOverlay(isSelected: isSelected),
          ],
        );
      }),
    );
  }
}

class _VideoBadge extends StatelessWidget {
  final Duration duration;
  const _VideoBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    final mins = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$mins:$secs',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _GifBadge extends StatelessWidget {
  const _GifBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purpleAccent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('GIF',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _SelectionOverlay extends StatelessWidget {
  final bool isSelected;
  const _SelectionOverlay({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: isSelected
            ? Border.all(color: primary, width: 3)
            : null,
        color: isSelected
            ? primary.withOpacity(0.3)
            : Colors.black.withOpacity(0.1),
      ),
      child: isSelected
          ? Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        ),
      )
          : Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(4),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 2),
            shape: BoxShape.circle,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionDeniedWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Allow access to your photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Samsung Gallery needs storage permission\nto display your photos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.lock_open),
              label: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 40,
      itemBuilder: (_, __) => Container(
        color: Colors.grey.shade300,
        child: const ShimmerPlaceholder(), // Consider using shimmer package
      ),
    );
  }
}

// Optional: Simple shimmer placeholder if not using package
class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.grey.shade200);
  }
}