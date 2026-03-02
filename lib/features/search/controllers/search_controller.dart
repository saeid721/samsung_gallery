
import 'package:get/get.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

// Renamed to avoid conflict with Flutter's built-in SearchController
class GallerySearchController extends GetxController {
  final MediaRepository _mediaRepo = Get.find<MediaRepository>();

  // ── Observable state ────────────────────────────────────────

  final RxString query = ''.obs;
  final RxList<MediaItem> results = <MediaItem>[].obs;
  final RxBool isSearching = false.obs;
  final RxBool hasSearched = false.obs;

  // ── Active filters ───────────────────────────────────────────
  final Rx<DateTime?> filterStartDate = Rx(null);
  final Rx<DateTime?> filterEndDate   = Rx(null);
  final RxString filterAlbumName      = ''.obs;
  final RxString filterLocation       = ''.obs;

  // ── Recent searches (persisted locally) ──────────────────────
  final RxList<String> recentSearches = <String>[].obs;

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();

    // Debounce: wait 300ms after last keystroke before searching.
    // Prevents firing a search on every character typed.
    debounce(
      query,
          (_) => _runSearch(),
      time: const Duration(milliseconds: 300),
    );
  }

  // ── Query input ─────────────────────────────────────────────

  void onQueryChanged(String text) {
    query.value = text;
    if (text.isEmpty) {
      results.clear();
      hasSearched.value = false;
    }
  }

  void clearQuery() {
    query.value = '';
    results.clear();
    hasSearched.value = false;
    filterStartDate.value = null;
    filterEndDate.value   = null;
    filterAlbumName.value = '';
    filterLocation.value  = '';
  }

  // ── Date filter ──────────────────────────────────────────────

  void setDateRange(DateTime? start, DateTime? end) {
    filterStartDate.value = start;
    filterEndDate.value   = end;
    _runSearch();
  }

  void clearDateFilter() => setDateRange(null, null);

  // ── Execute search ───────────────────────────────────────────

  Future<void> _runSearch() async {
    final q = query.value.trim();
    final hasFilters = filterStartDate.value != null ||
        filterEndDate.value != null ||
        filterAlbumName.value.isNotEmpty ||
        filterLocation.value.isNotEmpty;

    if (q.isEmpty && !hasFilters) {
      results.clear();
      hasSearched.value = false;
      return;
    }

    isSearching.value = true;

    try {
      final searchQuery = SearchQuery(
        text: q.isEmpty ? null : q,
        startDate: filterStartDate.value,
        endDate: filterEndDate.value,
        albumName: filterAlbumName.value.isEmpty ? null : filterAlbumName.value,
        location: filterLocation.value.isEmpty ? null : filterLocation.value,
      );

      final found = await _mediaRepo.search(searchQuery);
      results.assignAll(found);
      hasSearched.value = true;

      // Save to recent searches (text queries only, not filter-only runs)
      if (q.isNotEmpty && !recentSearches.contains(q)) {
        recentSearches.insert(0, q);
        if (recentSearches.length > 10) recentSearches.removeLast();
      }
    } finally {
      isSearching.value = false;
    }
  }

  void searchFromRecent(String recentQuery) {
    query.value = recentQuery;
    _runSearch();
  }

  void removeRecent(String q) => recentSearches.remove(q);
  void clearAllRecent()       => recentSearches.clear();
}