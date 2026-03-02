import 'media_model.dart';

class TimelineGroup {
  /// Human-readable date label shown as a section header.
  /// e.g. "Today", "Yesterday", "Last 7 Days", "March 2024"
  final String label;

  /// All media items that belong to this date section,
  /// sorted newest-first within the group.
  final List<MediaItem> items;

  TimelineGroup({
    required this.label,
    required this.items,
  });

  /// Total item count — convenience for header badge display.
  int get count => items.length;

  /// True when every item in the group is selected.
  bool isFullySelected(Set<String> selectedIds) =>
      items.isNotEmpty && items.every((item) => selectedIds.contains(item.id));

  /// Returns only video items in this group.
  List<MediaItem> get videos =>
      items.where((item) => item.type == MediaType.video).toList();

  /// Returns only image items in this group.
  List<MediaItem> get images =>
      items.where((item) => item.type == MediaType.image).toList();
}