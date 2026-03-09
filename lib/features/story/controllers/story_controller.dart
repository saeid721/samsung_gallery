import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/story_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/models/story_model.dart';
import '../../../data/repositories/media_repository.dart';

class StoryController extends GetxController
    with GetTickerProviderStateMixin {

  // ── Lazy dependencies ─────────────────────────────────────────
  StoryService get _service => Get.find<StoryService>();

  // ── Slide / UI timing ─────────────────────────────────────────
  static const Duration _defaultSlideDuration = Duration(seconds: 5);
  static const Duration _uiHideDelay          = Duration(seconds: 3);

  // ══════════════════════════════════════════════════════════════
  // OBSERVABLE STATE — LIST SCREEN
  // ══════════════════════════════════════════════════════════════

  final RxList<StoryModel>  stories          = <StoryModel>[].obs;
  final RxList<StoryModel>  suggestions      = <StoryModel>[].obs;
  final RxBool              isLoading        = true.obs;
  final RxBool              isGenerating     = false.obs;
  final RxString            error            = ''.obs;

  // ══════════════════════════════════════════════════════════════
  // OBSERVABLE STATE — PLAYER SCREEN
  // ══════════════════════════════════════════════════════════════

  final Rx<StoryModel?> activeStory    = Rx(null);
  final RxInt           currentIndex   = 0.obs;
  final RxBool          isPlaying      = true.obs;
  final RxBool          showUI         = true.obs;

  // Per-slide progress animation (rebuilt each openPlayer / nextSlide)
  AnimationController? progressAnim;

  // ── Timers ────────────────────────────────────────────────────
  Timer? _slideTimer;
  Timer? _uiHideTimer;

  // ══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════

  @override
  void onInit() {
    super.onInit();
    loadStories();
  }

  @override
  void onClose() {
    _cancelAll();
    progressAnim?.dispose();
    super.onClose();
  }

  // ══════════════════════════════════════════════════════════════
  // LIST — LOAD / CREATE / DELETE
  // ══════════════════════════════════════════════════════════════

  Future<void> loadStories() async {
    isLoading.value = true;
    error.value     = '';
    try {
      final loaded = await _service.loadAll();
      stories.assignAll(loaded);
    } catch (e) {
      error.value = 'Could not load stories: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Generate story suggestions from the full media library.
  Future<void> generateSuggestions() async {
    isGenerating.value = true;
    try {
      final repo   = Get.find<MediaRepository>();
      final groups = await repo.getTimelineStream().first;
      final all    = groups.expand((g) => g.items).toList();
      final sug    = await _service.autoGenerate(all);
      suggestions.assignAll(sug);
    } finally {
      isGenerating.value = false;
    }
  }

  /// Accept a suggestion → persist it as a real story.
  Future<void> acceptSuggestion(StoryModel suggestion) async {
    final saved = await _service.createStory(
      title:        suggestion.title,
      items:        suggestion.items,
      coverAssetId: suggestion.coverAssetId,
      transition:   suggestion.transition,
      music:        suggestion.music,
      theme:        suggestion.theme,
    );
    stories.insert(0, saved);
    suggestions.remove(suggestion);
  }

  /// Dismiss (ignore) a suggestion without saving.
  void dismissSuggestion(StoryModel suggestion) =>
      suggestions.remove(suggestion);

  /// Create a new story manually (called from selection flow).
  Future<StoryModel?> createStory({
    required String          title,
    required List<MediaItem> items,
    String?                  coverAssetId,
    StoryTransition          transition   = StoryTransition.fade,
    StoryMusic               music        = StoryMusic.calm,
    StoryTheme               theme        = StoryTheme.dark,
    Duration                 slideDuration = const Duration(seconds: 5),
  }) async {
    try {
      final story = await _service.createStory(
        title:         title,
        items:         items,
        coverAssetId:  coverAssetId,
        transition:    transition,
        music:         music,
        theme:         theme,
        slideDuration: slideDuration,
      );
      stories.insert(0, story);
      return story;
    } catch (e) {
      error.value = 'Could not create story: $e';
      return null;
    }
  }

  Future<void> deleteStory(String id) async {
    await _service.deleteStory(id);
    stories.removeWhere((s) => s.id == id);
  }

  Future<void> renameStory(String id, String newTitle) async {
    final updated = await _service.rename(id, newTitle);
    if (updated == null) return;
    final i = stories.indexWhere((s) => s.id == id);
    if (i != -1) {
      stories[i] = updated;
      stories.refresh();
    }
  }

  Future<void> setCover(String storyId, String assetId) async {
    final updated = await _service.setCover(storyId, assetId);
    if (updated == null) return;
    _replaceInList(updated);
  }

  Future<void> removeItemFromStory(
      String storyId, String assetId) async {
    final updated =
    await _service.removeItem(storyId, assetId);
    if (updated == null) {
      // Story was deleted because it became empty
      stories.removeWhere((s) => s.id == storyId);
    } else {
      _replaceInList(updated);
    }

    // If we're in the player for this story, also update it
    if (activeStory.value?.id == storyId) {
      if (updated == null) {
        closePlayer();
      } else {
        activeStory.value = updated;
        currentIndex.value =
            currentIndex.value.clamp(0, updated.items.length - 1);
      }
    }
  }

  Future<void> reorderItems(
      String storyId, List<MediaItem> reordered) async {
    final updated =
    await _service.reorderItems(storyId, reordered);
    if (updated == null) return;
    _replaceInList(updated);
  }

  // ══════════════════════════════════════════════════════════════
  // PLAYER — OPEN / CLOSE
  // ══════════════════════════════════════════════════════════════

  /// Open the immersive full-screen story player.
  void openPlayer(StoryModel story, {int startIndex = 0}) {
    _cancelAll();
    progressAnim?.dispose();

    final duration = story.slideDuration;
    progressAnim = AnimationController(
      vsync: this,
      duration: duration,
    );

    activeStory.value  = story;
    currentIndex.value = startIndex;
    isPlaying.value    = true;
    showUI.value       = true;

    _beginSlide();
    _scheduleUIHide();
  }

  void closePlayer() {
    _cancelAll();
    progressAnim?.dispose();
    progressAnim = null;

    activeStory.value  = null;
    currentIndex.value = 0;
    isPlaying.value    = true;
    showUI.value       = true;
  }

  // ══════════════════════════════════════════════════════════════
  // PLAYER — NAVIGATION
  // ══════════════════════════════════════════════════════════════

  void nextSlide() {
    final story = activeStory.value;
    if (story == null) return;
    _cancelAll();

    if (currentIndex.value < story.items.length - 1) {
      currentIndex.value++;
      if (isPlaying.value) _beginSlide();
    } else {
      closePlayer(); // Finished last slide
    }
    _userInteracted();
  }

  void prevSlide() {
    if (currentIndex.value == 0) return;
    _cancelAll();
    currentIndex.value--;
    if (isPlaying.value) _beginSlide();
    _userInteracted();
  }

  void jumpToSlide(int index) {
    final story = activeStory.value;
    if (story == null) return;
    if (index < 0 || index >= story.items.length) return;
    _cancelAll();
    currentIndex.value = index;
    if (isPlaying.value) _beginSlide();
    _userInteracted();
  }

  // ══════════════════════════════════════════════════════════════
  // PLAYER — PLAYBACK CONTROL
  // ══════════════════════════════════════════════════════════════

  void togglePlayPause() {
    isPlaying.value = !isPlaying.value;
    if (isPlaying.value) {
      // Resume: restart from current progress (not perfect,
      // but avoids complexity of partial-timer resume)
      _beginSlide();
    } else {
      _cancelAll();
      progressAnim?.stop();
    }
    _userInteracted();
  }

  void onScreenTap() {
    showUI.value = !showUI.value;
    if (showUI.value) _scheduleUIHide();
  }

  void onSwipe(double velocityX) {
    if (velocityX < -400) nextSlide();
    if (velocityX > 400) prevSlide();
  }

  // ══════════════════════════════════════════════════════════════
  // COMPUTED GETTERS
  // ══════════════════════════════════════════════════════════════

  MediaItem? get currentItem {
    final story = activeStory.value;
    if (story == null) return null;
    final i = currentIndex.value;
    if (i < 0 || i >= story.items.length) return null;
    return story.items[i];
  }

  String get counterLabel {
    final story = activeStory.value;
    if (story == null) return '';
    return '${currentIndex.value + 1} / ${story.items.length}';
  }

  bool get isFirstSlide => currentIndex.value == 0;

  bool get isLastSlide {
    final s = activeStory.value;
    if (s == null) return true;
    return currentIndex.value >= s.items.length - 1;
  }

  int get totalSlides => activeStory.value?.items.length ?? 0;

  // ══════════════════════════════════════════════════════════════
  // EXPORT
  // ══════════════════════════════════════════════════════════════

  Future<String?> exportActiveStory(String outputDir) async {
    final story = activeStory.value;
    if (story == null) return null;
    try {
      return await _service.exportToVideo(
        story:     story,
        outputDir: outputDir,
      );
    } catch (e) {
      Get.snackbar('Export failed', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PRIVATE — SLIDE ENGINE
  // ══════════════════════════════════════════════════════════════

  void _beginSlide() {
    _cancelAll();
    progressAnim?.reset();
    progressAnim?.forward();

    final dur =
        activeStory.value?.slideDuration ?? _defaultSlideDuration;
    _slideTimer = Timer(dur, nextSlide);
  }

  void _cancelAll() {
    _slideTimer?.cancel();
    _slideTimer = null;
    _uiHideTimer?.cancel();
    _uiHideTimer = null;
  }

  void _userInteracted() {
    showUI.value = true;
    _scheduleUIHide();
  }

  void _scheduleUIHide() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(_uiHideDelay, () {
      showUI.value = false;
    });
  }

  void _replaceInList(StoryModel updated) {
    final i = stories.indexWhere((s) => s.id == updated.id);
    if (i != -1) {
      stories[i] = updated;
      stories.refresh();
    }
  }
}