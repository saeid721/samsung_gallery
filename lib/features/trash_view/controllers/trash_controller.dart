import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/services/media_index_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';
// ── Trashed item model ────────────────────────────────────────

class TrashedItem {
  final MediaItem item;
  final DateTime  deletedAt;

  TrashedItem({required this.item, required this.deletedAt});

  static const int _retentionDays = 30;

  int get daysRemaining {
    final elapsed = DateTime.now().difference(deletedAt).inDays;
    return (_retentionDays - elapsed).clamp(0, _retentionDays);
  }

  bool get isExpired      => daysRemaining <= 0;
  bool get isExpiringSoon => daysRemaining <= 3;

  String get timeRemainingLabel {
    if (daysRemaining == 0) return 'Today';
    if (daysRemaining == 1) return '1 day';
    return '$daysRemaining days';
  }
}

// ══════════════════════════════════════════════════════════════
// TRASH CONTROLLER  —  GetBuilder pattern (update() based)
// ══════════════════════════════════════════════════════════════

class TrashController extends GetxController {
  final MediaIndexService _indexService = Get.find<MediaIndexService>();
  final MediaRepository   _mediaRepo    = Get.find<MediaRepository>();

  // ── Plain (non-Rx) state — update() triggers rebuild ─────────
  List<TrashedItem> trashedItems    = [];
  bool              isLoading       = true;
  bool              isSelectionMode = false;
  Set<String>       selectedIds     = {};

  // ── Computed ──────────────────────────────────────────────────
  int get imageCount => trashedItems
      .where((t) =>
  t.item.type == MediaType.image ||
      t.item.type == MediaType.gif)
      .length;

  int get videoCount =>
      trashedItems.where((t) => t.item.type == MediaType.video).length;

  int get itemCount => trashedItems.length;

  bool get allSelected =>
      selectedIds.length == trashedItems.length &&
          trashedItems.isNotEmpty;

  List<TrashedItem> get expiringSoon =>
      trashedItems.where((t) => t.isExpiringSoon).toList();

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _loadTrash();
  }

  // ── Load ──────────────────────────────────────────────────────

  Future<void> _loadTrash() async {
    isLoading = true;
    update();

    try {
      await _purgeExpired();
      final trashIndex = _indexService.trashIndex;

      if (trashIndex.isEmpty) {
        trashedItems = [];
        return;
      }

      final loaded = <TrashedItem>[];
      for (final entry in trashIndex.entries) {
        try {
          final asset = await AssetEntity.fromId(entry.key);
          if (asset == null) continue;

          final item = MediaItem(
            id:         asset.id,
            type:       asset.type == AssetType.video
                ? MediaType.video
                : (asset.mimeType == 'image/gif'
                ? MediaType.gif
                : MediaType.image),
            width:      asset.width,
            height:     asset.height,
            duration:   asset.videoDuration,
            createdAt:  asset.createDateTime,
            modifiedAt: asset.modifiedDateTime ?? asset.createDateTime,
            albumName:  '',
            mimeType:   asset.mimeType ?? '',
            size:       0,
            isFavorite: false.obs,
          );
          loaded.add(TrashedItem(item: item, deletedAt: entry.value));
        } catch (_) {
          _indexService.removeFromTrash(entry.key);
        }
      }

      // Oldest first → closest to auto-delete at top
      loaded.sort((a, b) => a.deletedAt.compareTo(b.deletedAt));
      trashedItems = loaded;
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<void> refresh() => _loadTrash();

  // ── RESTORE ───────────────────────────────────────────────────

  Future<void> restoreItem(String assetId) async {
    await _mediaRepo.restoreFromTrash([assetId]);
    _indexService.removeFromTrash(assetId);
    trashedItems.removeWhere((t) => t.item.id == assetId);
    update();

    Get.snackbar('Restored', 'Photo restored to gallery',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2));
  }

  Future<void> restoreSelected() async {
    if (selectedIds.isEmpty) return;
    final ids = List<String>.from(selectedIds);

    await _mediaRepo.restoreFromTrash(ids);
    for (final id in ids) _indexService.removeFromTrash(id);
    trashedItems.removeWhere((t) => ids.contains(t.item.id));

    exitSelectionMode(); // calls update()
    Get.snackbar('Restored', '${ids.length} item(s) restored',
        snackPosition: SnackPosition.BOTTOM);
  }

  // ── DELETE ────────────────────────────────────────────────────

  Future<void> deleteItemPermanently(String assetId) async {
    await _mediaRepo.deleteFromTrash([assetId]);
    _indexService.removeFromTrash(assetId);
    trashedItems.removeWhere((t) => t.item.id == assetId);
    update();
  }

  Future<void> deleteSelected() async {
    if (selectedIds.isEmpty) return;
    final ids = List<String>.from(selectedIds);

    await _mediaRepo.deleteFromTrash(ids);
    for (final id in ids) _indexService.removeFromTrash(id);
    trashedItems.removeWhere((t) => ids.contains(t.item.id));

    exitSelectionMode();
    Get.snackbar('Deleted', '${ids.length} item(s) permanently deleted',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> emptyTrash() async {
    final allIds = trashedItems.map((t) => t.item.id).toList();
    if (allIds.isEmpty) return;

    await _mediaRepo.deleteFromTrash(allIds);
    for (final id in allIds) _indexService.removeFromTrash(id);
    trashedItems = [];
    exitSelectionMode();

    Get.snackbar('Trash emptied',
        '${allIds.length} item(s) permanently deleted',
        snackPosition: SnackPosition.BOTTOM);
  }

  // ── SELECTION ─────────────────────────────────────────────────

  void enterSelectionMode({String? firstId}) {
    isSelectionMode = true;
    selectedIds = {};
    if (firstId != null) selectedIds.add(firstId);
    update();
  }

  void exitSelectionMode() {
    isSelectionMode = false;
    selectedIds = {};
    update();
  }

  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
      if (selectedIds.isEmpty) {
        isSelectionMode = false;
      }
    } else {
      selectedIds.add(id);
    }
    update();
  }

  void toggleSelectAll() {
    if (allSelected) {
      selectedIds = {};
      isSelectionMode = false;
    } else {
      selectedIds = trashedItems.map((t) => t.item.id).toSet();
      isSelectionMode = true;
    }
    update();
  }

  // ── Private helpers ───────────────────────────────────────────

  Future<void> _purgeExpired() async {
    final expiredIds = _indexService.getExpiredTrashItems();
    if (expiredIds.isEmpty) return;
    await _mediaRepo.deleteFromTrash(expiredIds);
    for (final id in expiredIds) _indexService.removeFromTrash(id);
  }
}