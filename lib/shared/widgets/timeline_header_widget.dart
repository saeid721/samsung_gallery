import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../data/models/media_model.dart';
import '../../../app/theme/theme.dart';

class TimelineHeaderWidget extends StatelessWidget {
  final TimelineGroup group;
  final bool showItemCount;

  const TimelineHeaderWidget({
    super.key,
    required this.group,
    this.showItemCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.background,
      child: Row(
        children: [
          // Date label (Today, Yesterday, or formatted date)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(
                //   _getRelativeDateLabel(group.date),
                //   style: const TextStyle(
                //     fontSize: 15,
                //     fontWeight: FontWeight.w600,
                //     color: Colors.black87,
                //     letterSpacing: -0.3,
                //   ),
                // ),
                if (showItemCount && group.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${group.items.length} ${_pluralize('item', group.items.length)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons (Samsung-style: Select, More)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Select button (appears on long-press in Samsung)
              TextButton(
                onPressed: () {
                  // TODO: Enter selection mode for this date group
                  // Get.snackbar(
                  //   'Select',
                  //   //'Select items from ${_getRelativeDateLabel(group.date)}',
                  //   snackPosition: SnackPosition.BOTTOM,
                  //   duration: const Duration(seconds: 2),
                  // );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Select',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // More options for this date group
              IconButton(
                icon: const Icon(Icons.more_horiz, size: 20),
                onPressed: () => _showDateGroupMenu(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'More options',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRelativeDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groupDate = DateTime(date.year, date.month, date.day);

    if (groupDate == today) return 'Today';
    if (groupDate == yesterday) return 'Yesterday';

    // Same year: show "Mon, Jan 15"
    if (date.year == now.year) {
      return DateFormat('EEE, MMM d').format(date);
    }
    // Different year: show "Jan 15, 2023"
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _pluralize(String word, int count) {
    return count == 1 ? word : '${word}s';
  }

  void _showDateGroupMenu(BuildContext context) {
    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(overlay.size.width - 100, 50, 100, 100),
        Offset.zero & overlay.size,
      ),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              const Text('Create album from date'),
            ],
          ),
          onTap: () {
            Get.snackbar(
              'Create Album',
              'Feature coming soon',
              snackPosition: SnackPosition.BOTTOM,
            );
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              const Text('Share all from this day'),
            ],
          ),
          onTap: () {
            // TODO: Implement share all
          },
        ),
      ],
    );
  }
}

// ── Optional: Sticky Header Variant (for advanced scrolling) ─
class StickyTimelineHeader extends StatelessWidget {
  final TimelineGroup group;
  final bool isSticky;

  const StickyTimelineHeader({
    super.key,
    required this.group,
    this.isSticky = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(16, isSticky ? 8 : 12, 16, 8),
      decoration: BoxDecoration(
        color: isSticky ? AppColors.background.withOpacity(0.95) : AppColors.background,
        border: isSticky
            ? Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        )
            : null,
      ),
      child: TimelineHeaderWidget(group: group, showItemCount: !isSticky),
    );
  }
}