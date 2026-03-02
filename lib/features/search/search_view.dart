import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/routes/app_pages.dart';
import '../../app/theme/theme.dart';
import '../../data/models/media_model.dart';
import 'controllers/search_controller.dart';

class SearchView extends GetView<GallerySearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _SearchField(controller: controller),
        actions: [
          Obx(() => controller.query.value.isNotEmpty
              ? TextButton(
            onPressed: controller.clearQuery,
            child: const Text('Cancel'),
          )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        // ── Empty state: show recent searches ────────────────
        if (controller.query.value.isEmpty &&
            !controller.hasSearched.value) {
          return _RecentSearches(controller: controller);
        }

        // ── Loading ──────────────────────────────────────────
        if (controller.isSearching.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // ── No results ───────────────────────────────────────
        if (controller.hasSearched.value &&
            controller.results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'No results for "${controller.query.value}"',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // ── Results grid ─────────────────────────────────────
        return Column(
          children: [
            // Active filter chips
            _FilterChips(controller: controller),

            // Results count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${controller.results.length} results',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            ),

            // Results grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: controller.results.length,
                itemBuilder: (context, index) {
                  final item = controller.results[index];
                  return _ResultCell(item: item);
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Search input field ──────────────────────────────────────
class _SearchField extends StatelessWidget {
  final GallerySearchController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search photos, places, people…',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
        border: InputBorder.none,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
      ),
      onChanged: controller.onQueryChanged,
      textInputAction: TextInputAction.search,
    );
  }
}

// ── Active filter chips ─────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final GallerySearchController controller;
  const _FilterChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasDateFilter = controller.filterStartDate.value != null;
      if (!hasDateFilter) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          spacing: 8,
          children: [
            if (hasDateFilter)
              Chip(
                label: Text(_dateLabel(
                  controller.filterStartDate.value,
                  controller.filterEndDate.value,
                )),
                onDeleted: controller.clearDateFilter,
                backgroundColor: AppColors.primary.withOpacity(0.1),
              ),
          ],
        ),
      );
    });
  }

  String _dateLabel(DateTime? start, DateTime? end) {
    if (start == null) return '';
    final s = '${start.year}/${start.month}/${start.day}';
    if (end == null) return 'From $s';
    final e = '${end.year}/${end.month}/${end.day}';
    return '$s – $e';
  }
}

// ── Recent searches list ────────────────────────────────────
class _RecentSearches extends StatelessWidget {
  final GallerySearchController controller;
  const _RecentSearches({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.recentSearches.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.history, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('Search your gallery',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
              SizedBox(height: 4),
              Text('Try "beach", "food", or a person\'s name',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: controller.clearAllRecent,
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: controller.recentSearches.length,
              itemBuilder: (_, index) {
                final q = controller.recentSearches[index];
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(q),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => controller.removeRecent(q),
                  ),
                  onTap: () => controller.searchFromRecent(q),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

// ── Single result cell ──────────────────────────────────────
class _ResultCell extends StatelessWidget {
  final MediaItem item;
  const _ResultCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed(
        AppPages.viewer,
        arguments: {'mediaItem': item},
      ),
      child: FutureBuilder(
        future: _loadThumb(item.id),
        builder: (_, snap) {
          if (snap.hasData) {
            return Image.memory(snap.data!, fit: BoxFit.cover);
          }
          return Container(color: Colors.grey.shade200);
        },
      ),
    );
  }

  Future<dynamic> _loadThumb(String id) async {
    final asset = await AssetEntity.fromId(id);
    return asset?.thumbnailDataWithSize(const ThumbnailSize(256, 256));
  }
}