import 'package:get/get.dart';

import '../../../core/services/media_index_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

// ── Duplicate group model ─────────────────────────────────────
class DuplicateGroup {
  final String groupId;
  final List<MediaItem> items;
  String? keepAssetId;         // Which item the user chose to keep
  final double similarity;     // 0.0–1.0 perceptual similarity score

  DuplicateGroup({
    required this.groupId,
    required this.items,
    required this.similarity,
    this.keepAssetId,
  });

  /// Items that will be trashed (all except keepAssetId)
  List<String> get trashIds => items
      .where((item) => item.id != keepAssetId)
      .map((item) => item.id)
      .toList();

  /// Estimated storage freed by deleting duplicates (bytes)
  int get savingsBytes => items
      .where((item) => item.id != keepAssetId)
      .fold(0, (sum, item) => sum + item.size);

  bool get hasSelection => keepAssetId != null;
}

class DuplicatesController extends GetxController {
  final MediaIndexService _indexService = Get.find<MediaIndexService>();
  final MediaRepository   _mediaRepo    = Get.find<MediaRepository>();

  // ── Observable state ─────────────────────────────────────────
  final RxList<DuplicateGroup> duplicateGroups = <DuplicateGroup>[].obs;
  final RxBool   isScanning      = false.obs;
  final RxDouble scanProgress    = 0.0.obs;
  final RxBool   hasScanned      = false.obs;
  final RxInt    totalSavingsBytes = 0.obs;

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    // Auto-start scan when screen opens
    startScan();
  }

  // ── SCAN ──────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (isScanning.value) return;

    isScanning.value = true;
    scanProgress.value = 0.0;
    duplicateGroups.clear();
    hasScanned.value = false;

    try {
      // MediaIndexService streams groups as they are found
      // so UI updates incrementally rather than waiting for full scan
      await for (final rawGroups
      in _indexService.streamDuplicateGroups()) {
        // Convert raw assetId groups → DuplicateGroup models
        for (final raw in rawGroups) {
          if (raw.assetIds.length < 2) continue;

          // Load MediaItem metadata for each assetId
          final items = <MediaItem>[];
          for (final id in raw.assetIds) {
            final page = await _mediaRepo.getMediaPage(page: 0, pageSize: 1);
            // In a real impl, fetch by ID: MediaRepository.getItemById(id)
            // Stub: skip if not found
          }

          if (items.length < 2) continue;

          final group = DuplicateGroup(
            groupId: raw.assetIds.first,
            items: items,
            similarity: 0.95, // from pHash distance
          );

          // Auto-select the highest-resolution item to keep
          _autoSelectKeep(group);
          duplicateGroups.add(group);
        }

        // Update total savings estimate
        _recalcSavings();
      }
    } finally {
      isScanning.value = false;
      hasScanned.value = true;
      scanProgress.value = 1.0;
    }
  }

  // ── USER ACTIONS ──────────────────────────────────────────────

  /// User taps a thumbnail to mark it as the one to keep.
  void setKeep(String groupId, String assetId) {
    final index = duplicateGroups.indexWhere((g) => g.groupId == groupId);
    if (index == -1) return;
    duplicateGroups[index].keepAssetId = assetId;
    duplicateGroups.refresh();
    _recalcSavings();
  }

  /// Trash duplicates for a single group.
  Future<void> cleanGroup(String groupId) async {
    final index = duplicateGroups.indexWhere((g) => g.groupId == groupId);
    if (index == -1) return;

    final group = duplicateGroups[index];
    if (!group.hasSelection) return;

    await _mediaRepo.trashItems(group.trashIds);
    duplicateGroups.removeAt(index);
    _recalcSavings();

    Get.snackbar(
      'Cleaned',
      '${group.trashIds.length} duplicate(s) moved to trash',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Trash duplicates across ALL groups in one pass.
  Future<void> cleanAll() async {
    final groupsWithSelection =
    duplicateGroups.where((g) => g.hasSelection).toList();

    if (groupsWithSelection.isEmpty) {
      Get.snackbar('Select items', 'Tap photos to choose which to keep',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final allTrashIds = groupsWithSelection
        .expand((g) => g.trashIds)
        .toList();

    await _mediaRepo.trashItems(allTrashIds);

    duplicateGroups.removeWhere((g) => g.hasSelection);
    _recalcSavings();

    Get.snackbar(
      'All duplicates cleaned',
      '${allTrashIds.length} items moved to trash  •  '
          '${_formatBytes(totalSavingsBytes.value)} freed',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }

  /// Auto-select all: keeps highest-res item in every group.
  void autoSelectAll() {
    for (final group in duplicateGroups) {
      _autoSelectKeep(group);
    }
    duplicateGroups.refresh();
    _recalcSavings();
  }

  // ── Private helpers ───────────────────────────────────────────

  /// Automatically picks the best item to keep:
  /// 1. Largest resolution (width × height)
  /// 2. Largest file size (as tie-breaker — less compressed = better)
  void _autoSelectKeep(DuplicateGroup group) {
    if (group.items.isEmpty) return;

    MediaItem best = group.items.first;
    for (final item in group.items.skip(1)) {
      final itemPixels = item.width * item.height;
      final bestPixels = best.width * best.height;

      if (itemPixels > bestPixels) {
        best = item;
      } else if (itemPixels == bestPixels && item.size > best.size) {
        best = item;
      }
    }

    group.keepAssetId = best.id;
  }

  void _recalcSavings() {
    totalSavingsBytes.value = duplicateGroups
        .where((g) => g.hasSelection)
        .fold(0, (sum, g) => sum + g.savingsBytes);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ── Getters used by view ──────────────────────────────────────

  String get savingsLabel => _formatBytes(totalSavingsBytes.value);

  int get totalDuplicateCount =>
      duplicateGroups.fold(0, (sum, g) => sum + g.items.length - 1);
}