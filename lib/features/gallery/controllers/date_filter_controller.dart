import 'package:get/get.dart';
import '../../../data/models/timeline_group.dart';

enum DateFilterType {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  allTime,
}

class DateFilterController extends GetxController {
  // ── Observable State ────────────────────────────────────────
  final RxString filterType = DateFilterType.today.name.obs;
  final RxList<TimelineGroup> filteredGroups = <TimelineGroup>[].obs;

  // ── Get selected filter type ────────────────────────────────
  DateFilterType get selectedFilter {
    return DateFilterType.values.firstWhere(
      (e) => e.name == filterType.value,
      orElse: () => DateFilterType.today,
    );
  }

  // ── Apply filter to groups ──────────────────────────────────
  void applyFilter(List<TimelineGroup> allGroups) {
    final filtered = <TimelineGroup>[];

    for (final group in allGroups) {
      final itemsInRange = group.items
          .where((item) => _isInDateRange(item.createdAt))
          .toList();

      if (itemsInRange.isNotEmpty) {
        filtered.add(
          TimelineGroup(
            label: group.label,
            items: itemsInRange,
          ),
        );
      }
    }

    filteredGroups.assignAll(filtered);
  }

  // ── Check if date is in range ───────────────────────────────
  bool _isInDateRange(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (selectedFilter) {
      case DateFilterType.today:
        final dateOnly = DateTime(date.year, date.month, date.day);
        return dateOnly == today;

      case DateFilterType.thisWeek:
        final weekAgo = today.subtract(const Duration(days: 7));
        return date.isAfter(weekAgo) && date.isBefore(now);

      case DateFilterType.thisMonth:
        final monthAgo = today.subtract(const Duration(days: 30));
        return date.isAfter(monthAgo) && date.isBefore(now);

      case DateFilterType.thisYear:
        final yearAgo = DateTime(now.year - 1);
        return date.isAfter(yearAgo) && date.isBefore(now);

      case DateFilterType.allTime:
        return true;
    }
  }

  // ── Set filter type ────────────────────────────────────────
  void setFilter(DateFilterType type) {
    filterType.value = type.name;
  }

  // ── Get filter label ───────────────────────────────────────
  String getFilterLabel() {
    switch (selectedFilter) {
      case DateFilterType.today:
        return 'Today';
      case DateFilterType.thisWeek:
        return 'This Week';
      case DateFilterType.thisMonth:
        return 'This Month';
      case DateFilterType.thisYear:
        return 'This Year';
      case DateFilterType.allTime:
        return 'All Time';
    }
  }

  // ── Get all filter options ─────────────────────────────────
  List<(DateFilterType, String)> getFilterOptions() {
    return [
      (DateFilterType.today, 'Today'),
      (DateFilterType.thisWeek, 'This Week'),
      (DateFilterType.thisMonth, 'This Month'),
      (DateFilterType.thisYear, 'This Year'),
      (DateFilterType.allTime, 'All Time'),
    ];
  }
}

