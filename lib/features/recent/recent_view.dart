
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/theme/theme.dart';
import '../../data/models/media_model.dart';
import 'controllers/recent_controller.dart';

class RecentView extends GetView<RecentController> {
  const RecentView({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(children: [
        // Header
        Container(
          color: const Color(0xFF0F0F0F),
          padding: EdgeInsets.fromLTRB(4, top + 8, 16, 0),
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Get.back(),
              ),
              const Expanded(
                child: Text('Recent',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
              Obx(() => controller.isSelectionMode.value
                  ? TextButton(
                  onPressed: controller.trashSelected,
                  child: const Text('Delete',
                      style:
                      TextStyle(color: Colors.redAccent)))
                  : IconButton(
                icon: const Icon(
                    Icons.date_range_outlined,
                    color: Colors.white70),
                onPressed: () =>
                    _showDatePicker(context, controller),
              )),
            ]),

            // Period chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                children: RecentPeriod.values.map((p) {
                  final labels = {
                    RecentPeriod.today: 'Today',
                    RecentPeriod.week:  'Last 7 days',
                    RecentPeriod.month: 'Last 30 days',
                    RecentPeriod.custom: 'Custom',
                  };
                  return Obx(() {
                    final active = controller.period.value == p;
                    return GestureDetector(
                      onTap: () => controller.setPeriod(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(labels[p]!,
                            style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ),
                    );
                  });
                }).toList(),
              ),
            ),

            // Count bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Obx(() => Row(children: [
                Text(
                  '${controller.items.length} items — ${controller.periodLabel}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ])),
            ),
          ]),
        ),

        // Content
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              );
            }
            if (controller.items.isEmpty) {
              return _EmptyState(period: controller.periodLabel);
            }
            return RefreshIndicator(
              onRefresh: controller.refresh,
              color: AppColors.primary,
              child: _GroupedGrid(c: controller),
            );
          }),
        ),
      ]),
    );
  }

  void _showDatePicker(
      BuildContext context, RecentController c) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (range != null) {
      c.setCustomRange(range.start, range.end);
    }
  }
}

class _GroupedGrid extends StatelessWidget {
  final RecentController c;
  const _GroupedGrid({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final groups = c.grouped;
      return CustomScrollView(
        slivers: groups.entries.map((entry) {
          return SliverMainAxisGroup(slivers: [
            // Date header
            SliverToBoxAdapter(
              child: Padding(
                padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(entry.key,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
              ),
            ),
            // Grid for this day
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                      (_, i) =>
                      _Cell(item: entry.value[i], c: c),
                  childCount: entry.value.length,
                ),
              ),
            ),
          ]);
        }).toList(),
      );
    });
  }
}

class _Cell extends StatelessWidget {
  final MediaItem item;
  final RecentController c;
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
        future: () async {
          final a = await AssetEntity.fromId(item.id);
          return a?.thumbnailDataWithSize(
              const ThumbnailSize(300, 300));
        }(),
        builder: (_, snap) => snap.hasData
            ? Image.memory(snap.data!, fit: BoxFit.cover)
            : Container(
            color: Colors.white.withOpacity(0.05)),
      ),
      if (item.isVideo)
        const Positioned(
          bottom: 4, right: 4,
          child: Icon(Icons.videocam_rounded,
              color: Colors.white70, size: 14),
        ),
      Obx(() {
        final sel = c.selectedIds.contains(item.id);
        if (!c.isSelectionMode.value) {
          return const SizedBox.shrink();
        }
        return Container(
          color: sel
              ? AppColors.primary.withOpacity(0.45)
              : Colors.transparent,
          child: sel
              ? const Center(
              child: Icon(Icons.check_circle,
                  color: Colors.white, size: 26))
              : null,
        );
      }),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  final String period;
  const _EmptyState({required this.period});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.schedule_rounded,
            size: 64, color: Colors.white24),
        const SizedBox(height: 16),
        Text('Nothing added $period',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}