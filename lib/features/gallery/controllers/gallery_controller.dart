import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/media_model.dart' hide TimelineGroup;
import '../../../data/models/timeline_group.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../data/repositories/album_repository.dart';
import 'date_filter_controller.dart';

class GalleryController extends GetxController {
  // ── Injected dependencies (resolved lazily) ────────────────
  MediaRepository get _mediaRepo => Get.find<MediaRepository>();
  AlbumRepository get _albumRepo => Get.find<AlbumRepository>();
  //AiPipelineService get _aiService => Get.find<AiPipelineService>();

  // ── Observable State ────────────────────────────────────────
  final RxBool isLoading = true.obs;
  final RxBool hasPermission = false.obs;
  final RxBool isSelectionMode = false.obs;
  final RxList<TimelineGroup> timelineGroups = <TimelineGroup>[].obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  final RxInt scrollOffset = 0.obs;
  final RxString errorMessage = ''.obs;

  // Album filtering support
  final RxString currentAlbumId = ''.obs;
  final RxString currentAlbumName = ''.obs;

  // ── Lifecycle ────────────────────────────────────────────────
  StreamSubscription? _timelineSubscription;
  List<String>? _lastTrashedIds; // Moved here for proper scope

  @override
  void onInit() {
    super.onInit();
    // Get album ID from route arguments if present
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('albumId')) {
      currentAlbumId.value = args['albumId'] as String;
      currentAlbumName.value = args['albumName'] as String? ?? 'Album';
    }
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

    // If viewing a specific album, load only its items
    if (currentAlbumId.value.isNotEmpty) {
      await _loadAlbumMedia();
    } else {
      _loadTimelineStream();
    }
  }

  Future<void> _loadAlbumMedia() async {
    try {
      final items = await _albumRepo.getAlbumItems(currentAlbumId.value);
      if (items.isNotEmpty) {
        // Sort items by date descending
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Group items by date
        final groupedItems = _groupItemsByDate(items);
        timelineGroups.assignAll(groupedItems);
      }
      isLoading.value = false;
    } catch (e) {
      errorMessage.value = 'Failed to load album media: $e';
      isLoading.value = false;
    }
  }

  void _loadTimelineStream() {
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

  List<TimelineGroup> _groupItemsByDate(List<MediaItem> items) {
    final grouped = <String, List<MediaItem>>{};

    for (final item in items) {
      final label = _formatDate(item.createdAt);
      if (!grouped.containsKey(label)) {
        grouped[label] = [];
      }
      grouped[label]!.add(item);
    }

    // Sort by date descending
    final sortedLabels = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedLabels.map((label) {
      return TimelineGroup(
        label: label,
        items: grouped[label] ?? [],
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == DateTime(today.year, today.month, today.day)) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  // ── Public Actions ───────────────────────────────────────────
  @override
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
        .toList();
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
  // Future<void> startFaceGrouping() async {
  //   final allItems = timelineGroups.expand((g) => g.items).toList();
  //   await _aiService.clusterFaces(allItems);
  // }

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
      try {
        return group.items.firstWhere((item) => item.id == id);
      } catch (_) {
        // Item not in this group, continue to next
      }
    }
    return null;
  }

  // ── Date Filter Support ─────────────────────────────────
  void applyDateFilter(DateFilterType filterType) {
    try {
      final dateFilterController = Get.find<DateFilterController>();
      // Convert RxList to List for the filter method
      dateFilterController.applyFilter(timelineGroups.toList());
      // UI will rebuild automatically due to Obx observation
    } catch (e) {
      debugPrint('Error applying date filter: $e');
    }
  }
}