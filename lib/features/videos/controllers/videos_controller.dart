
import 'package:get/get.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

enum VideoSortOrder { newest, oldest, longest, shortest, largest }
enum VideoFilter { all, short, medium, long }   // short<1m, medium 1-5m, long>5m

class VideosController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();

  // ── State ─────────────────────────────────────────────────
  final RxList<MediaItem>   allVideos      = <MediaItem>[].obs;
  final RxList<MediaItem>   filteredVideos = <MediaItem>[].obs;
  final RxBool              isLoading      = true.obs;
  final RxBool              isSelectionMode = false.obs;
  final RxSet<String>       selectedIds    = <String>{}.obs;
  final Rx<VideoSortOrder>  sortOrder      = VideoSortOrder.newest.obs;
  final Rx<VideoFilter>     activeFilter   = VideoFilter.all.obs;
  final RxString            searchQuery    = ''.obs;

  // Stats
  final RxInt    totalCount      = 0.obs;
  final RxInt    totalDurationSec = 0.obs;
  final RxInt    totalSizeBytes  = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadVideos();
    // React to sort/filter changes
    ever(sortOrder,  (_) => _applyFilters());
    ever(activeFilter, (_) => _applyFilters());
    debounce(searchQuery, (_) => _applyFilters(),
        time: const Duration(milliseconds: 280));
  }

  // ── Load ──────────────────────────────────────────────────
  Future<void> _loadVideos() async {
    isLoading.value = true;
    try {
      final timeline = await _repo.getTimelineStream().first;
      final videos = timeline
          .expand((g) => g.items)
          .where((item) => item.isVideo)
          .toList();

      allVideos.assignAll(videos);
      _calcStats(videos);
      _applyFilters();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() async {
    isLoading.value = true;
    await _loadVideos();
  }

  // ── Filter + Sort ─────────────────────────────────────────
  void _applyFilters() {
    var list = List<MediaItem>.from(allVideos);

    // Text search
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list.where((v) =>
      v.albumName.toLowerCase().contains(q) ||
          _fmtDate(v.createdAt).contains(q)).toList();
    }

    // Duration filter
    list = switch (activeFilter.value) {
      VideoFilter.short  => list.where((v) => v.duration.inSeconds < 60).toList(),
      VideoFilter.medium => list.where((v) =>
      v.duration.inSeconds >= 60 && v.duration.inSeconds < 300).toList(),
      VideoFilter.long   => list.where((v) => v.duration.inSeconds >= 300).toList(),
      VideoFilter.all    => list,
    };

    // Sort
    list.sort(switch (sortOrder.value) {
      VideoSortOrder.newest   => (a, b) => b.createdAt.compareTo(a.createdAt),
      VideoSortOrder.oldest   => (a, b) => a.createdAt.compareTo(b.createdAt),
      VideoSortOrder.longest  => (a, b) => b.duration.compareTo(a.duration),
      VideoSortOrder.shortest => (a, b) => a.duration.compareTo(b.duration),
      VideoSortOrder.largest  => (a, b) => b.size.compareTo(a.size),
    });

    filteredVideos.assignAll(list);
  }

  void setFilter(VideoFilter f) => activeFilter.value = f;
  void setSortOrder(VideoSortOrder s) => sortOrder.value = s;
  void onSearchChanged(String q) => searchQuery.value = q;

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

  void selectAll() =>
      selectedIds.assignAll(filteredVideos.map((v) => v.id));

  Future<void> trashSelected() async {
    await _repo.trashItems(selectedIds.toList());
    allVideos.removeWhere((v) => selectedIds.contains(v.id));
    exitSelectionMode();
    _calcStats(allVideos);
    _applyFilters();
  }

  // ── Stats ─────────────────────────────────────────────────
  void _calcStats(List<MediaItem> videos) {
    totalCount.value = videos.length;
    totalDurationSec.value =
        videos.fold(0, (s, v) => s + v.duration.inSeconds);
    totalSizeBytes.value =
        videos.fold(0, (s, v) => s + v.size);
  }

  // ── Computed getters ──────────────────────────────────────
  String get totalDurationLabel {
    final sec = totalDurationSec.value;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${sec % 60}s';
  }

  String get totalSizeLabel {
    final mb = totalSizeBytes.value / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }

  String durationLabel(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
}