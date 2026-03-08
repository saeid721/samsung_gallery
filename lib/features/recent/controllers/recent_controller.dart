
import 'package:get/get.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

enum RecentPeriod { today, week, month, custom }

class RecentController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();

  final RxList<MediaItem>   items         = <MediaItem>[].obs;
  final RxBool              isLoading     = true.obs;
  final Rx<RecentPeriod>    period        = RecentPeriod.week.obs;
  final Rx<DateTime?>       customStart   = Rx(null);
  final Rx<DateTime?>       customEnd     = Rx(null);
  final RxBool              isSelectionMode = false.obs;
  final RxSet<String>       selectedIds   = <String>{}.obs;

  // Grouped by date label
  final RxMap<String, List<MediaItem>> grouped = <String, List<MediaItem>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
    ever(period, (_) => _load());
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      final cutoff = _cutoffDate();
      final timeline = await _repo.getTimelineStream().first;
      final all = timeline.expand((g) => g.items).toList();

      final recent = all
          .where((item) => item.createdAt.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      items.assignAll(recent);
      _buildGroups(recent);
    } finally {
      isLoading.value = false;
    }
  }

  void _buildGroups(List<MediaItem> list) {
    final map = <String, List<MediaItem>>{};
    for (final item in list) {
      final label = _dayLabel(item.createdAt);
      map.putIfAbsent(label, () => []).add(item);
    }
    grouped.assignAll(map);
  }

  String _dayLabel(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    final diff  = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7)  return _weekday(dt.weekday);
    return '${dt.day} ${_monthAbbr(dt.month)} ${dt.year}';
  }

  DateTime _cutoffDate() {
    final now = DateTime.now();
    return switch (period.value) {
      RecentPeriod.today  => DateTime(now.year, now.month, now.day),
      RecentPeriod.week   => now.subtract(const Duration(days: 7)),
      RecentPeriod.month  => now.subtract(const Duration(days: 30)),
      RecentPeriod.custom => customStart.value ??
          now.subtract(const Duration(days: 7)),
    };
  }

  Future<void> refresh() => _load();

  void setPeriod(RecentPeriod p) => period.value = p;

  void setCustomRange(DateTime start, DateTime end) {
    customStart.value = start;
    customEnd.value   = end;
    period.value      = RecentPeriod.custom;
  }

  // ── Selection ─────────────────────────────────────────────
  void enterSelectionMode(String id) {
    isSelectionMode.value = true;
    selectedIds.add(id);
  }

  void exitSelectionMode() {
    isSelectionMode.value = false;
    selectedIds.clear();
  }

  void toggleSelection(String id) {
    selectedIds.contains(id)
        ? selectedIds.remove(id)
        : selectedIds.add(id);
    if (selectedIds.isEmpty) exitSelectionMode();
  }

  Future<void> trashSelected() async {
    await _repo.trashItems(selectedIds.toList());
    items.removeWhere((i) => selectedIds.contains(i.id));
    exitSelectionMode();
    _buildGroups(items);
  }

  // ── Helpers ───────────────────────────────────────────────
  String get periodLabel => switch (period.value) {
    RecentPeriod.today  => 'Today',
    RecentPeriod.week   => 'Last 7 days',
    RecentPeriod.month  => 'Last 30 days',
    RecentPeriod.custom => 'Custom range',
  };

  String _weekday(int d) => const [
    '', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday',
  ][d];

  String _monthAbbr(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m];
}