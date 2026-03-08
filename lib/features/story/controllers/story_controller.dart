// import 'dart:convert';
// import 'package:get/get.dart';
//
// import '../../../core/services/ai_pipeline_service.dart';
// import '../../../core/services/secure_storage_service.dart';
// import '../../../data/models/media_model.dart';
// import '../../../data/models/memory_story.dart';
// import '../../../data/repositories/media_repository.dart';
//
// class StoryController extends GetxController {
//   final AiPipelineService _aiService     = Get.find<AiPipelineService>();
//   final MediaRepository   _mediaRepo     = Get.find<MediaRepository>();
//   final SecureStorageService _storage    = Get.find<SecureStorageService>();
//
//   // ── Storage key prefix ───────────────────────────────────────
//   static const _storiesKey     = 'memories_stories';
//   static const _dismissedKey   = 'memories_dismissed';
//   static const _lastGenerated  = 'memories_last_generated';
//
//   // ── Observable state ─────────────────────────────────────────
//   final RxList<MemoryStory>  stories          = <MemoryStory>[].obs;
//   final RxBool               isLoading        = true.obs;
//   final RxBool               isGenerating     = false.obs;
//   final Rx<MemoryStory?>     activeSlideshow  = Rx(null);
//   final RxInt                slideshowIndex   = 0.obs;
//   final RxBool               isSlideshowPlaying = false.obs;
//
//   // ── Lifecycle ─────────────────────────────────────────────────
//
//   @override
//   void onInit() {
//     super.onInit();
//     _loadStories();
//   }
//
//   // ── Load: try cache first, regenerate if stale ───────────────
//
//   Future<void> _loadStories() async {
//     isLoading.value = true;
//     try {
//       // 1. Load persisted stories from storage (instant)
//       final cached = await _loadFromStorage();
//       if (cached.isNotEmpty) {
//         stories.assignAll(cached);
//         isLoading.value = false;
//       }
//
//       // 2. Regenerate if never generated or older than 7 days
//       if (await _shouldRegenerate()) {
//         await _generateStories();
//       }
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   Future<void> refresh() => _generateStories();
//
//   // ── Generate stories via AI pipeline ─────────────────────────
//
//   Future<void> _generateStories() async {
//     isGenerating.value = true;
//     try {
//       // Load all media items for analysis
//       final allItems = <MediaItem>[];
//       final timeline = await _mediaRepo.getTimelineStream().first;
//       for (final group in timeline) {
//         allItems.addAll(group.items);
//       }
//
//       if (allItems.isEmpty) return;
//
//       // Generate via AI service (groups by month, scores photos)
//       final generated = await _aiService.generateMemories(allItems);
//
//       // Filter out dismissed stories
//       final dismissed = await _loadDismissedIds();
//       final visible = generated
//           .where((s) => !dismissed.contains(s.id))
//           .toList();
//
//       stories.assignAll(visible);
//
//       // Persist to storage for fast reload next time
//       await _saveToStorage(visible);
//       await _storage.write(
//           _lastGenerated, DateTime.now().toIso8601String());
//     } finally {
//       isGenerating.value = false;
//     }
//   }
//
//   // ── Story actions ─────────────────────────────────────────────
//
//   Future<void> dismissStory(String storyId) async {
//     stories.removeWhere((s) => s.id == storyId);
//
//     // Persist dismissed ID so it doesn't reappear after regeneration
//     final dismissed = await _loadDismissedIds();
//     dismissed.add(storyId);
//     await _storage.write(_dismissedKey, jsonEncode(dismissed.toList()));
//   }
//
//   void openSlideshow(MemoryStory story) {
//     activeSlideshow.value = story;
//     slideshowIndex.value  = 0;
//     isSlideshowPlaying.value = true;
//   }
//
//   void closeSlideshow() {
//     activeSlideshow.value    = null;
//     isSlideshowPlaying.value = false;
//     slideshowIndex.value     = 0;
//   }
//
//   void nextSlideshowPhoto() {
//     final story = activeSlideshow.value;
//     if (story == null) return;
//     if (slideshowIndex.value < story.items.length - 1) {
//       slideshowIndex.value++;
//     } else {
//       closeSlideshow(); // Auto-close at end
//     }
//   }
//
//   void previousSlideshowPhoto() {
//     if (slideshowIndex.value > 0) slideshowIndex.value--;
//   }
//
//   void toggleSlideshowPlayback() {
//     isSlideshowPlaying.value = !isSlideshowPlaying.value;
//   }
//
//   void jumpToSlideshowIndex(int index) {
//     final story = activeSlideshow.value;
//     if (story == null) return;
//     if (index >= 0 && index < story.items.length) {
//       slideshowIndex.value = index;
//     }
//   }
//
//   // ── Private helpers ───────────────────────────────────────────
//
//   Future<bool> _shouldRegenerate() async {
//     final lastRaw = await _storage.read(_lastGenerated);
//     if (lastRaw == null) return true;
//     final last = DateTime.tryParse(lastRaw);
//     if (last == null) return true;
//     return DateTime.now().difference(last).inDays >= 7;
//   }
//
//   Future<List<MemoryStory>> _loadFromStorage() async {
//     final raw = await _storage.read(_storiesKey);
//     if (raw == null) return [];
//     try {
//       final list = jsonDecode(raw) as List;
//       // Stories are stored as lightweight JSON (only asset IDs)
//       // Re-hydrate: map stored IDs back to MediaItem objects
//       // For simplicity here we return a stub — in production
//       // you'd call MediaRepository.getItemsByIds(ids)
//       return [];
//     } catch (_) {
//       return [];
//     }
//   }
//
//   Future<void> _saveToStorage(List<MemoryStory> storiesToSave) async {
//     // Store only IDs, not full MediaItem objects, to keep storage lean
//     final json = storiesToSave.map((s) => s.toJson()).toList();
//     await _storage.write(_storiesKey, jsonEncode(json));
//   }
//
//   Future<Set<String>> _loadDismissedIds() async {
//     final raw = await _storage.read(_dismissedKey);
//     if (raw == null) return {};
//     try {
//       return Set<String>.from(jsonDecode(raw) as List);
//     } catch (_) {
//       return {};
//     }
//   }
// }