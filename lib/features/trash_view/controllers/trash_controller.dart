import 'package:get/get.dart';
import '../../../core/services/media_index_service.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../data/models/trash_model.dart'; // Import the TrashedItem model

class TrashController extends GetxController {
  final MediaIndexService _indexService = Get.find<MediaIndexService>();
  final MediaRepository _mediaRepo = Get.find<MediaRepository>();

  final RxList<TrashedItem> trashedItems = <TrashedItem>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSelectionMode = false.obs;
  final RxSet<String> selectedIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    isLoading.value = true;
    try {
      // 1. Auto-purge expired items first
      await _purgeExpired();

      // 2. Load trash index from service
      final trashIndex = _indexService.trashIndex;

      if (trashIndex.isEmpty) {
        trashedItems.clear();
        return;
      }

      // 3. Load MediaItem metadata for each trashed assetId
      final loaded = <TrashedItem>[];
      for (final entry in trashIndex.entries) {
        try {
          // ✅ Use a proper method to fetch by ID
          final mediaItem = await _mediaRepo.getItemById(entry.key);
          if (mediaItem != null) {
            loaded.add(TrashedItem(
              item: mediaItem,
              deletedAt: entry.value,
            ));
          }
        } catch (e) {
          // Skip unresolvable items (already deleted from device)
          _indexService.removeFromTrash(entry.key);
        }
      }

      // Sort by deletion date — oldest first (closest to auto-delete)
      loaded.sort((a, b) => a.deletedAt.compareTo(b.deletedAt));
      trashedItems.assignAll(loaded);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _loadTrash();

  // ── RESTORE ───────────────────────────────────────────────────
  Future<void> restoreItem(String assetId) async {
    await _mediaRepo.restoreFromTrash([assetId]);
    _indexService.removeFromTrash(assetId); // ✅ Sync index
    trashedItems.removeWhere((t) => t.item.id == assetId);

    Get.snackbar(
      'Restored',
      'Photo restored to gallery',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> restoreSelected() async {
    if (selectedIds.isEmpty) return;
    final ids = selectedIds.toList();

    await _mediaRepo.restoreFromTrash(ids);
    for (final id in ids) {
      _indexService.removeFromTrash(id); // ✅ Sync index
    }
    trashedItems.removeWhere((t) => ids.contains(t.item.id));

    exitSelectionMode();
    Get.snackbar(
      'Restored',
      '${ids.length} item(s) restored to gallery',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // ── PERMANENT DELETE ──────────────────────────────────────────
  Future<void> deleteItemPermanently(String assetId) async {
    await _mediaRepo.deleteFromTrash([assetId]);
    _indexService.removeFromTrash(assetId); // ✅ Sync index
    trashedItems.removeWhere((t) => t.item.id == assetId);
  }

  Future<void> deleteSelected() async {
    if (selectedIds.isEmpty) return;
    final ids = selectedIds.toList();

    await _mediaRepo.deleteFromTrash(ids);
    for (final id in ids) {
      _indexService.removeFromTrash(id); // ✅ Sync index
    }
    trashedItems.removeWhere((t) => ids.contains(t.item.id));
    exitSelectionMode();

    Get.snackbar(
      'Deleted',
      '${ids.length} item(s) permanently deleted',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> emptyTrash() async {
    final allIds = trashedItems.map((t) => t.item.id).toList();
    if (allIds.isEmpty) return;

    await _mediaRepo.deleteFromTrash(allIds);
    for (final id in allIds) {
      _indexService.removeFromTrash(id); // ✅ Sync index
    }
    trashedItems.clear();
    exitSelectionMode();

    Get.snackbar(
      'Trash emptied',
      '${allIds.length} item(s) permanently deleted',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // ── SELECTION ─────────────────────────────────────────────────
  void enterSelectionMode(String firstId) {
    isSelectionMode.value = true;
    selectedIds.add(firstId);
  }

  void exitSelectionMode() {
    isSelectionMode.value = false;
    selectedIds.clear();
  }

  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
      if (selectedIds.isEmpty) exitSelectionMode();
    } else {
      selectedIds.add(id);
    }
  }

  void selectAll() {
    selectedIds.assignAll(trashedItems.map((t) => t.item.id));
    isSelectionMode.value = true;
  }

  // ── Computed getters ──────────────────────────────────────────
  List<TrashedItem> get expiringSoon =>
      trashedItems.where((t) => t.isExpiringSoon).toList();

  int get itemCount => trashedItems.length;

  // ── Private helpers ───────────────────────────────────────────
  Future<void> _purgeExpired() async {
    final expiredIds = _indexService.getExpiredTrashItems();
    if (expiredIds.isEmpty) return;

    await _mediaRepo.deleteFromTrash(expiredIds);
    for (final id in expiredIds) {
      _indexService.removeFromTrash(id); // ✅ Sync index
    }
  }
}