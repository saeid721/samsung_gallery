// ============================================================
// features/gallery/controllers/gallery_controller.dart
// ============================================================
// GetX Controller for the main gallery/timeline screen.
//
// RESPONSIBILITIES:
//   • Request storage permissions on first launch
//   • Load & group media items into timeline sections
//   • Handle multi-selection mode
//   • Coordinate trash, favorite, move operations
//   • Expose reactive observables (Rx*) for UI to watch
//
// PATTERN: Controller owns observable state; Repository owns data.
// UI never talks to repository directly.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/services/ai_pipeline_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

class GalleryController extends GetxController {
  // ── Injected dependencies ──────────────────────────────────
  final MediaRepository _mediaRepo = Get.find<MediaRepository>();
  final AiPipelineService _aiService = Get.find<AiPipelineService>();

  // ── Observable State ────────────────────────────────────────
  // Rx<T> = reactive wrapper; UI rebuilds when value changes

  final RxBool isLoading = true.obs;
  final RxBool hasPermission = false.obs;
  final RxBool isSelectionMode = false.obs;

  /// Grouped timeline sections (Today, Yesterday, Month…)
  final RxList<TimelineGroup> timelineGroups = <TimelineGroup>[].obs;

  /// Currently selected asset IDs in selection mode
  final RxSet<String> selectedIds = <String>{}.obs;

  /// Current scroll position for restoring after navigation
  final RxInt scrollOffset = 0.obs;

  /// Error message if permission denied or IO error
  final RxString errorMessage = ''.obs;

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    // Kick off permission check + load immediately
    _initialize();
  }

  @override
  void onClose() {
    // Cancel any active streams to prevent memory leaks
    _timelineSubscription?.cancel();
    super.onClose();
  }

  // ── Internal ─────────────────────────────────────────────────

  StreamSubscription? _timelineSubscription;

  Future<void> _initialize() async {
    isLoading.value = true;

    // 1. Check / request permission
    hasPermission.value = await _mediaRepo.requestPermission();
    if (!hasPermission.value) {
      isLoading.value = false;
      errorMessage.value = 'Storage permission required to view photos.';
      return;
    }

    // 2. Subscribe to timeline stream (emits cached, then fresh data)
    _timelineSubscription = _mediaRepo.getTimelineStream().listen(
          (groups) {
        timelineGroups.assignAll(groups);
        isLoading.value = false;
      },
      onError: (e) {
        errorMessage.value = 'Failed to load media: $e';
        isLoading.value = false;
      },
    );
  }

  // ── Public Actions (called by UI widgets) ───────────────────

  /// Refresh gallery (e.g., pull-to-refresh)
  Future<void> refresh() async {
    isLoading.value = true;
    await _initialize();
  }

  // ── Selection Mode ──────────────────────────────────────────

  void enterSelectionMode(String firstSelectedId) {
    isSelectionMode.value = true;
    selectedIds.add(firstSelectedId);
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
    final allIds = timelineGroups
        .expand((g) => g.items)
        .map((item) => item.id)
        .toSet();
    selectedIds.assignAll(allIds);
  }

  // ── Media Operations ────────────────────────────────────────

  Future<void> trashSelected() async {
    if (selectedIds.isEmpty) return;

    await _mediaRepo.trashItems(selectedIds.toList());

    // Remove from UI immediately (optimistic update)
    _removeItemsFromTimeline(selectedIds.toSet());
    exitSelectionMode();

    Get.snackbar(
      'Moved to Trash',
      '${selectedIds.length} item(s) will be deleted after 30 days',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      mainButton: TextButton(
        onPressed: _undoLastTrash,
        child: const Text('UNDO'),
      ),
    );
  }

  List<String>? _lastTrashedIds;

  void _undoLastTrash() {
    if (_lastTrashedIds != null) {
      _mediaRepo.restoreFromTrash(_lastTrashedIds!);
      refresh(); // Reload timeline to show restored items
      _lastTrashedIds = null;
    }
  }

  Future<void> toggleFavoriteSelected() async {
    for (final id in selectedIds) {
      final item = _findItem(id);
      if (item != null) {
        await _mediaRepo.toggleFavorite(id, !item.isFavorite.value);
      }
    }
    exitSelectionMode();
  }

  Future<void> moveSelectedTo(String albumId) async {
    await _mediaRepo.moveItems(selectedIds.toList(), albumId);
    exitSelectionMode();
    refresh();
  }

  // ── AI Triggers ─────────────────────────────────────────────

  /// Start face grouping analysis in background isolate
  Future<void> startFaceGrouping() async {
    final allItems = timelineGroups.expand((g) => g.items).toList();
    // Runs in compute() isolate — won't block UI thread
    await _aiService.clusterFaces(allItems);
    // Result is saved to secure_folder_view storage and exposed via FaceController
  }

  // ── Private Helpers ─────────────────────────────────────────

  void _removeItemsFromTimeline(Set<String> ids) {
    for (var group in timelineGroups) {
      group.items.removeWhere((item) => ids.contains(item.id));
    }
    // Remove empty groups
    timelineGroups.removeWhere((g) => g.items.isEmpty);
    timelineGroups.refresh(); // Force Obx rebuild
  }

  MediaItem? _findItem(String id) {
    for (final group in timelineGroups) {
      try {
        return group.items.firstWhere((item) => item.id == id);
      } catch (_) {}
    }
    return null;
  }
}