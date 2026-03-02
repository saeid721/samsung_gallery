import 'package:get/get.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

// ── Category model ────────────────────────────────────────────
class MediaCategory {
  final String id;
  final String label;
  final String iconName;      // Material icon name as string
  final int    count;
  final String? coverAssetId;

  const MediaCategory({
    required this.id,
    required this.label,
    required this.iconName,
    required this.count,
    this.coverAssetId,
  });
}

class CategoriesController extends GetxController {
  final MediaRepository _mediaRepo = Get.find<MediaRepository>();

  // ── Observable state ─────────────────────────────────────────
  final RxList<MediaCategory>  categories    = <MediaCategory>[].obs;
  final RxBool                 isLoading     = true.obs;

  // Filtered items for the currently opened category
  final RxList<MediaItem>      filteredItems = <MediaItem>[].obs;
  final Rx<MediaCategory?>     activeCategory = Rx(null);
  final RxBool                 isLoadingItems = false.obs;

  // ── Internal cache: all items indexed by category ─────────────
  final Map<String, List<MediaItem>> _categoryCache = {};

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _buildCategories();
  }

  // ── Build category list ───────────────────────────────────────

  Future<void> _buildCategories() async {
    isLoading.value = true;
    try {
      // Load all items (from in-memory cache in MediaRepository)
      final timeline = await _mediaRepo.getTimelineStream().first;
      final allItems = timeline.expand((g) => g.items).toList();

      // Classify each item into categories
      _categoryCache.clear();
      _categoryCache['videos']        = [];
      _categoryCache['gifs']          = [];
      _categoryCache['screenshots']   = [];
      _categoryCache['downloads']     = [];
      _categoryCache['portraits']     = [];
      _categoryCache['panoramas']     = [];
      _categoryCache['favorites']     = [];
      _categoryCache['recent']        = [];

      final sevenDaysAgo =
      DateTime.now().subtract(const Duration(days: 7));

      for (final item in allItems) {
        if (item.type == MediaType.video) {
          _categoryCache['videos']!.add(item);
        }
        if (item.mimeType == 'image/gif') {
          _categoryCache['gifs']!.add(item);
        }
        if (item.albumName.toLowerCase().contains('screenshot')) {
          _categoryCache['screenshots']!.add(item);
        }
        if (item.albumName.toLowerCase().contains('download')) {
          _categoryCache['downloads']!.add(item);
        }
        if (item.type == MediaType.image && item.isPortrait) {
          _categoryCache['portraits']!.add(item);
        }
        if (item.type == MediaType.image && item.isPanorama) {
          _categoryCache['panoramas']!.add(item);
        }
        if (item.isFavorite.value) {
          _categoryCache['favorites']!.add(item);
        }
        if (item.createdAt.isAfter(sevenDaysAgo)) {
          _categoryCache['recent']!.add(item);
        }
      }

      // Build displayed category list — hide empty categories
      final built = <MediaCategory>[
        _makeCategory('videos',      'Videos',         'videocam'),
        _makeCategory('gifs',        'GIFs',           'gif'),
        _makeCategory('screenshots', 'Screenshots',    'screenshot'),
        _makeCategory('downloads',   'Downloads',      'download'),
        _makeCategory('portraits',   'Portraits',      'portrait'),
        _makeCategory('panoramas',   'Panoramas',      'panorama'),
        _makeCategory('favorites',   'Favorites',      'favorite'),
        _makeCategory('recent',      'Recently Added', 'schedule'),
      ].where((c) => c.count > 0).toList();

      categories.assignAll(built);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _buildCategories();

  // ── Open a category ───────────────────────────────────────────

  void openCategory(MediaCategory category) {
    activeCategory.value = category;
    final items = _categoryCache[category.id] ?? [];
    filteredItems.assignAll(items);
  }

  void closeCategory() {
    activeCategory.value = null;
    filteredItems.clear();
  }

  // ── Load more items for a category (pagination) ──────────────

  Future<void> loadMoreItems(int page) async {
    final category = activeCategory.value;
    if (category == null) return;

    isLoadingItems.value = true;
    try {
      // For virtual categories, items are already in _categoryCache.
      // Pagination is handled by slicing the list in the view:
      //   filteredItems.take(page * 80)
      // No extra IO needed.
    } finally {
      isLoadingItems.value = false;
    }
  }

  // ── Getters ───────────────────────────────────────────────────

  int get totalCategoryCount => categories.length;

  // ── Private helpers ───────────────────────────────────────────

  MediaCategory _makeCategory(String id, String label, String iconName) {
    final items = _categoryCache[id] ?? [];
    return MediaCategory(
      id: id,
      label: label,
      iconName: iconName,
      count: items.length,
      coverAssetId: items.isEmpty ? null : items.first.id,
    );
  }
}