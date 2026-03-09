import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/date_filter_controller.dart';
import '../../../app/theme/theme.dart';
import '../controllers/gallery_controller.dart';

class DateFilterChip extends StatelessWidget {
  final DateFilterController controller;

  const DateFilterChip({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final options = controller.getFilterOptions();
      final selected = controller.selectedFilter;

      return SizedBox(
        height: 45,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final (filterType, label) = options[index];
            final isSelected = selected == filterType;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                backgroundColor: Colors.transparent,
                selectedColor: AppColors.primary,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
                onSelected: (_) {
                  controller.setFilter(filterType);
                  // Trigger filtering in gallery
                  Get.find<GalleryController>().applyDateFilter(filterType);
                },
              ),
            );
          },
        ),
      );
    });
  }
}

// Video thumbnail with play button overlay
class VideoThumbnailOverlay extends StatelessWidget {
  final Duration duration;
  final double size;

  const VideoThumbnailOverlay({
    super.key,
    required this.duration,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    final mins = duration.inMinutes;
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final timeStr = mins > 0 ? '$mins:$secs' : '0:$secs';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient overlay at bottom for duration visibility
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black87,
                  Colors.black54,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Play button center
        Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: size * 0.5,
            ),
          ),
        ),

        // Duration badge at bottom right
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

