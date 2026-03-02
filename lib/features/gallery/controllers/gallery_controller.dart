import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/ai_pipeline_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

class GalleryController extends GetxController {
  // ── Injected dependencies ──────────────────────────────────
  final MediaRepository _mediaRepo = Get.find<MediaRepository>();
  final AiPipelineService _aiService = Get.find<AiPipelineService>();

  // ── Observable State ────────────────────────────────────────
  final RxBool isLoading = true.obs;
  final RxBool hasPermission = false.obs;
  final RxBool isSelectionMode = false.obs;
  final RxList<TimelineGroup> timelineGroups = <TimelineGroup>[].obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  final RxInt scrollOffset = 0.obs;
  final RxString errorMessage = ''.obs;

  // ── Lifecycle ────────────────────────────────────────────────
  StreamSubscription? _timelineSubscription;
  List<String>? _lastTrashedIds; // Moved here for proper scope

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  @override
  void onClose() {
    _timelineSubscription?.cancel(); // Safe null-aware cancellation
    super.onClose();
  }

  // ── Internal ─────────────────────────────────────────────────
  Future<void> _initialize() async {
    isLoading.value = true;
    errorMessage.value = '';

    hasPermission.value = await _mediaRepo.requestPermission();
    if (!hasPermission.value) {
      isLoading.value = false;
      errorMessage.value = 'Storage permission required to view photos.';
      return;
    }

    _timelineSubscription?.cancel(); // Cancel previous if any
    _timelineSubscription = _mediaRepo.getTimelineStream().listen(
          (groups) {
        // Cast to ensure type compatibility
        timelineGroups.assignAll(groups as Iterable<TimelineGroup>);
        isLoading.value = false;
      },
      onError: (e) {
        errorMessage.value = 'Failed to load media: $e';
        isLoading.value = false;
      },
    );
  }

  // ── Public Actions ───────────────────────────────────────────
  Future<void> refresh() async {
    isLoading.value = true;
    await _initialize();
  }

  // ── Selection Mode ──────────────────────────────────────────
  void enterSelectionMode(String firstSelectedId) {
    isSelectionMode.value = true;
    selectedIds.clear();
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

    // Save IDs for undo BEFORE removing from UI
    _lastTrashedIds = selectedIds.toList();

    await _mediaRepo.trashItems(_lastTrashedIds!);

    // Optimistic UI update
    _removeItemsFromTimeline(selectedIds.toSet());
    exitSelectionMode();

    Get.snackbar(
      'Moved to Trash',
      '${_lastTrashedIds!.length} item(s) will be deleted after 30 days',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      mainButton: TextButton(
        onPressed: _undoLastTrash,
        child: const Text('UNDO'),
      ),
    );
  }

  void _undoLastTrash() {
    if (_lastTrashedIds != null && _lastTrashedIds!.isNotEmpty) {
      _mediaRepo.restoreFromTrash(_lastTrashedIds!);
      _lastTrashedIds = null;
      refresh(); // Reload to show restored items
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
  Future<void> startFaceGrouping() async {
    final allItems = timelineGroups.expand((g) => g.items).toList();
    await _aiService.clusterFaces(allItems);
  }

  // ── Private Helpers ─────────────────────────────────────────
  void _removeItemsFromTimeline(Set<String> ids) {
    for (var group in timelineGroups) {
      group.items.removeWhere((item) => ids.contains(item.id));
    }
    timelineGroups.removeWhere((g) => g.items.isEmpty);
    timelineGroups.refresh(); // Force reactive rebuild
  }

  MediaItem? _findItem(String id) {
    for (final group in timelineGroups) {
      final match = group.items.firstWhere((item) => item.id == id, orElse: () => null as MediaItem);
      if (match != null) return match;
    }
    return null;
  }
}