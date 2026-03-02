import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../app/routes/app_pages.dart';
import '../../../app/theme/theme.dart';
import '../../../data/models/media_model.dart';
import '../controllers/gallery_controller.dart';

import '../widgets/media_thumbnail_widget.dart';
import '../widgets/selection_app_bar.dart';
import '../widgets/timeline_header_widget.dart';


class GalleryView extends GetView<GalleryController> {
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        // ── Permission Denied State ─────────────────────────
        if (!controller.hasPermission.value && !controller.isLoading.value) {
          return _PermissionDeniedWidget(onRetry: controller.refresh);
        }

        // ── Loading State ───────────────────────────────────
        if (controller.isLoading.value && controller.timelineGroups.isEmpty) {
          return const _LoadingShimmer();
        }

        // ── Main Content ────────────────────────────────────
        return CustomScrollView(
          // Physics tuned for fast flick scrolling
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── App Bar (changes in selection mode) ──────────
            Obx(() => controller.isSelectionMode.value
                ? const SelectionAppBar()
                : _buildMainAppBar()),

            // ── Pull-to-Refresh ───────────────────────────────
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: const SizedBox.shrink(),
              ),
            ),

            // ── Timeline Groups ──────────────────────────────
            ...controller.timelineGroups.map((group) => [
              // Date header (Today, Yesterday, etc.)
              SliverToBoxAdapter(
                child: TimelineHeaderWidget(group: group),
              ),
              // Photo/video grid for this date group
              _buildGrid(context, group),
            ]).expand((widgets) => widgets),

            // ── Bottom padding for FAB/nav bar ───────────────
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        );
      }),

      // ── Bottom Navigation Bar ───────────────────────────────
      bottomNavigationBar: _buildBottomNav(),

      // ── FAB for AI features ─────────────────────────────────
      floatingActionButton: _buildFab(),
    );
  }

  // ── Grid builder — virtualized, handles 50k+ items ─────────
  SliverGrid _buildGrid(BuildContext context, TimelineGroup group) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final item = group.items[index];
          return _MediaCell(item: item, controller: controller);
        },
        childCount: group.items.length,
        // Recycle cells aggressively for memory efficiency
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
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
          case 0: break; // Already on gallery
          case 1: Get.toNamed(AppPages.albums);
          case 2: Get.toNamed(AppPages.categories);
          case 3: Get.toNamed(AppPages.people);
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
      // Short tap: open full-screen OR toggle selection
      onTap: () {
        if (controller.isSelectionMode.value) {
          controller.toggleSelection(item.id);
        } else {
          Get.toNamed(AppPages.viewer, arguments: {'mediaItem': item});
        }
      },
      // Long press: enter multi-selection mode
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
            // Thumbnail — loaded from cache or decoded lazily
            //MediaThumbnailWidget(item: item),

            // Video duration badge
            if (item.type == MediaType.video)
              _VideoBadge(duration: item.duration),

            // GIF badge
            if (item.mimeType == 'image/gif')
              const _GifBadge(),

            // Selection overlay
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('$mins:$secs',
            style: const TextStyle(color: Colors.white, fontSize: 10)),
      ),
    );
  }
}

class _GifBadge extends StatelessWidget {
  const _GifBadge();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.all(4),
        child: Text('GIF',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SelectionOverlay extends StatelessWidget {
  final bool isSelected;
  const _SelectionOverlay({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: isSelected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
            : null,
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
            : Colors.black.withOpacity(0.1),
      ),
      child: isSelected
          ? Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
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
            border: Border.all(color: Colors.white, width: 2),
            shape: BoxShape.circle,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Allow access to your photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Samsung Gallery needs storage permission\nto display your photos.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    // Use shimmer package for Samsung-style skeleton loading
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 40,
      itemBuilder: (_, __) => Container(color: Colors.grey.shade200),
    );
  }
}