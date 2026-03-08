
import 'package:get/get.dart';

import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

enum FavSortOrder { newest, oldest, type }
enum FavViewMode { grid, list }

class FavouritesController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();

  final RxList<MediaItem>  items          = <MediaItem>[].obs;
  final RxBool             isLoading      = true.obs;
  final RxBool             isSelectionMode = false.obs;
  final RxSet<String>      selectedIds    = <String>{}.obs;
  final Rx<FavSortOrder>   sortOrder      = FavSortOrder.newest.obs;
  final Rx<FavViewMode>    viewMode       = FavViewMode.grid.obs;
  final RxBool             showOnlyPhotos = false.obs;
  final RxBool             showOnlyVideos = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
    ever(sortOrder, (_) => _sort());
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      final timeline = await _repo.getTimelineStream().first;
      final favs = timeline
          .expand((g) => g.items)
          .where((item) => item.isFavorite.value)
          .toList();
      items.assignAll(favs);
      _sort();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _load();

  void _sort() {
    final list = List<MediaItem>.from(items);
    list.sort(switch (sortOrder.value) {
      FavSortOrder.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
      FavSortOrder.oldest => (a, b) => a.createdAt.compareTo(b.createdAt),
      FavSortOrder.type   => (a, b) => a.type.index.compareTo(b.type.index),
    });
    items.assignAll(list);
  }

  // ── Filter getters ────────────────────────────────────────
  List<MediaItem> get displayedItems {
    if (showOnlyPhotos.value) {
      return items.where((i) => !i.isVideo).toList();
    }
    if (showOnlyVideos.value) {
      return items.where((i) => i.isVideo).toList();
    }
    return items;
  }

  void togglePhotoFilter() {
    showOnlyPhotos.value = !showOnlyPhotos.value;
    if (showOnlyPhotos.value) showOnlyVideos.value = false;
  }

  void toggleVideoFilter() {
    showOnlyVideos.value = !showOnlyVideos.value;
    if (showOnlyVideos.value) showOnlyPhotos.value = false;
  }

  // ── Remove from favorites ─────────────────────────────────
  Future<void> unfavouriteItem(String id) async {
    await _repo.toggleFavorite(id, false);
    items.removeWhere((i) => i.id == id);
    selectedIds.remove(id);
  }

  Future<void> unfavouriteSelected() async {
    for (final id in selectedIds.toList()) {
      await _repo.toggleFavorite(id, false);
    }
    items.removeWhere((i) => selectedIds.contains(i.id));
    exitSelectionMode();
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

  void selectAll() =>
      selectedIds.assignAll(displayedItems.map((i) => i.id));

  void toggleViewMode() {
    viewMode.value = viewMode.value == FavViewMode.grid
        ? FavViewMode.list
        : FavViewMode.grid;
  }

  void setSortOrder(FavSortOrder s) => sortOrder.value = s;

  int get photoCount => items.where((i) => !i.isVideo).length;
  int get videoCount => items.where((i) => i.isVideo).length;
}