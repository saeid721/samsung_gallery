
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../data/models/media_model.dart';
import 'controllers/categories_controller.dart';

// Icon mapping for category ID → Material icon
const _categoryIcons = <String, IconData>{
  'videos':       Icons.videocam_rounded,
  'gifs':         Icons.gif_box_rounded,
  'screenshots':  Icons.screenshot_monitor_rounded,
  'downloads':    Icons.download_rounded,
  'portraits':    Icons.portrait_rounded,
  'panoramas':    Icons.panorama_rounded,
  'favorites':    Icons.favorite_rounded,
  'recent':       Icons.schedule_rounded,
};

// Category accent colors
const _categoryColors = <String, Color>{
  'videos':       Color(0xFF5E5CE6),
  'gifs':         Color(0xFFFF9F0A),
  'screenshots':  Color(0xFF30D158),
  'downloads':    Color(0xFF0A84FF),
  'portraits':    Color(0xFFFF375F),
  'panoramas':    Color(0xFF64D2FF),
  'favorites':    Color(0xFFFF3B30),
  'recent':       Color(0xFFAC8E68),
};

class CategoriesView extends GetView<CategoriesController> {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Obx(() {
        // If a category is opened, show its item grid
        if (controller.activeCategory.value != null) {
          return _CategoryItemGrid(controller: controller);
        }
        return _CategoriesGrid(controller: controller);
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORIES GRID
// ═══════════════════════════════════════════════════════════════
class _CategoriesGrid extends StatelessWidget {
  final CategoriesController controller;
  const _CategoriesGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
            child: const Text('Categories',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6)),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        Obx(() {
          if (controller.isLoading.value) {
            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4),
                delegate: SliverChildBuilderDelegate(
                      (_, __) => _ShimmerCard(),
                  childCount: 6,
                ),
              ),
            );
          }

          if (controller.categories.isEmpty) {
            return const SliverFillRemaining(
              child: Center(
                child: Text('No categories found',
                    style: TextStyle(color: Colors.white38)),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35),
              delegate: SliverChildBuilderDelegate(
                    (_, i) => _CategoryCard(
                    category: controller.categories[i],
                    controller: controller),
                childCount: controller.categories.length,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final MediaCategory category;
  final CategoriesController controller;
  const _CategoryCard({required this.category, required this.controller});

  @override
  Widget build(BuildContext context) {
    final icon  = _categoryIcons[category.id] ?? Icons.photo_library_outlined;
    final color = _categoryColors[category.id] ?? const Color(0xFF1259C3);

    return GestureDetector(
      onTap: () => controller.openCategory(category),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1A1A1A),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover thumbnail (if available)
              if (category.coverAssetId != null)
                Opacity(
                  opacity: 0.4,
                  child: _AssetImage(
                      assetId: category.coverAssetId!, fit: BoxFit.cover),
                ),

              // Color tint
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.5),
                      const Color(0xFF1A1A1A),
                    ],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const Spacer(),
                    Text(category.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('${category.count} items',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12)),
                  ],
                ),
              ),

              // Arrow indicator
              Positioned(
                top: 14, right: 14,
                child: Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORY ITEM GRID (opened category)
// ═══════════════════════════════════════════════════════════════
class _CategoryItemGrid extends StatelessWidget {
  final CategoriesController controller;
  const _CategoryItemGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return WillPopScope(
      onWillPop: () async {
        controller.closeCategory();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, top + 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: controller.closeCategory,
                    ),
                    Obx(() => Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.activeCategory.value?.label ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${controller.filteredItems.length} items',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Items grid
            Obx(() {
              if (controller.filteredItems.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text('No items',
                        style: TextStyle(color: Colors.white38)),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _ItemCell(item: controller.filteredItems[i]),
                    childCount: controller.filteredItems.length,
                    addRepaintBoundaries: true,
                    addAutomaticKeepAlives: false,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ItemCell extends StatelessWidget {
  final MediaItem item;
  const _ItemCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed('/viewer', arguments: {'mediaItem': item}),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AssetImage(assetId: item.id, fit: BoxFit.cover),

          // Video badge
          if (item.isVideo)
            Positioned(
              bottom: 4, right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_rounded,
                        color: Colors.white, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      _fmtDuration(item.duration),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),

          // GIF badge
          if (item.isGif)
            Positioned(
              top: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('GIF',
                    style: TextStyle(color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),

          // Favorite indicator
          Obx(() => item.isFavorite.value
              ? const Positioned(
            top: 4, right: 4,
            child: Icon(Icons.favorite_rounded,
                color: Colors.white, size: 14),
          )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Shared ────────────────────────────────────────────────────
class _AssetImage extends StatelessWidget {
  final String assetId;
  final BoxFit fit;
  const _AssetImage({required this.assetId, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _load(),
    builder: (_, snap) => snap.hasData
        ? Image.memory(snap.data!, fit: fit, gaplessPlayback: true)
        : Container(color: Colors.white.withOpacity(0.05)),
  );

  Future<Uint8List?> _load() async {
    final a = await AssetEntity.fromId(assetId);
    return a?.thumbnailDataWithSize(const ThumbnailSize(300, 300));
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white.withOpacity(0.05),
    ),
  );
}