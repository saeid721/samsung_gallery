
import 'package:get/get.dart';
import '../../../core/services/exif_service.dart';
import '../../../data/models/media_model.dart';

class MediaViewerController extends GetxController {
  final ExifService _exifService = Get.find<ExifService>();

  // ── Observable state ────────────────────────────────────────

  /// The item currently centred in the viewer.
  final Rx<MediaItem?> currentItem = Rx(null);

  /// All items in the current browsing context (album or timeline group).
  /// Used for left/right swipe navigation.
  final RxList<MediaItem> items = <MediaItem>[].obs;

  /// Index of currentItem within [items].
  final RxInt currentIndex = 0.obs;

  /// Whether the app bar, action bar, and overlay UI are visible.
  /// Tapping the image toggles this.
  final RxBool showChrome = true.obs;

  /// EXIF data for the current item — loaded lazily on demand.
  final Rx<ExifData?> exifData = Rx(null);
  final RxBool isLoadingExif = false.obs;

  /// Video-specific: is the video currently playing?
  final RxBool isVideoPlaying = false.obs;

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();

    // Read arguments passed via Get.toNamed(AppPages.viewer, arguments: {...})
    final args = Get.arguments as Map<String, dynamic>?;

    if (args != null) {
      final item = args['mediaItem'] as MediaItem?;
      final itemList = args['items'] as List<MediaItem>?;
      final index = args['index'] as int?;

      if (item != null) {
        currentItem.value = item;

        if (itemList != null) {
          items.assignAll(itemList);
          currentIndex.value = index ??
              itemList.indexWhere((i) => i.id == item.id);
        } else {
          // Single-item viewer (e.g. opened from search result)
          items.assignAll([item]);
          currentIndex.value = 0;
        }
      }
    }
  }

  // ── Navigation ───────────────────────────────────────────────

  /// Swipe to the next item (right → left swipe).
  void goToNext() {
    if (currentIndex.value < items.length - 1) {
      currentIndex.value++;
      currentItem.value = items[currentIndex.value];
      _clearExif();
    }
  }

  /// Swipe to the previous item (left → right swipe).
  void goToPrevious() {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      currentItem.value = items[currentIndex.value];
      _clearExif();
    }
  }

  /// Jump directly to a specific index (e.g. from thumbnail strip).
  void goToIndex(int index) {
    if (index < 0 || index >= items.length) return;
    currentIndex.value = index;
    currentItem.value = items[index];
    _clearExif();
  }

  // ── Chrome toggle ────────────────────────────────────────────

  void toggleChrome() => showChrome.value = !showChrome.value;

  void hideChrome() => showChrome.value = false;

  void showChromeForced() => showChrome.value = true;

  // ── EXIF ─────────────────────────────────────────────────────

  /// Loads EXIF data for [currentItem] — called when user opens
  /// the info panel. Not loaded automatically to save IO on swipe.
  Future<void> loadExif() async {
    final item = currentItem.value;
    if (item == null || item.isVideo) return;
    if (exifData.value != null) return; // Already loaded

    isLoadingExif.value = true;
    try {
      // Get file path via photo_manager
      // In real code: final file = await AssetEntity.fromId(item.id)?.originFile
      // Using ExifService stub here
      exifData.value = await _exifService.readExif(item.id);
    } finally {
      isLoadingExif.value = false;
    }
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> toggleFavorite() async {
    final item = currentItem.value;
    if (item == null) return;
    final newValue = !item.isFavorite.value;
    item.isFavorite.value = newValue;
    // Persist via GalleryController (find it if alive)
    // Get.find<GalleryController>().toggleFavorite(item.id, newValue);
  }

  void openEditor() {
    final item = currentItem.value;
    if (item == null) return;
    Get.toNamed('/editor', arguments: {'mediaItem': item});
  }

  void shareCurrentItem() {
    // Delegate to Share.shareXFiles([XFile(filePath)]) via share_plus
    // Implemented in the view layer to access BuildContext if needed
  }

  Future<void> deleteCurrentItem() async {
    final item = currentItem.value;
    if (item == null) return;

    // Remove from current items list
    items.removeWhere((i) => i.id == item.id);

    if (items.isEmpty) {
      Get.back(); // Close viewer if no items left
      return;
    }

    // Navigate to adjacent item
    final newIndex = currentIndex.value.clamp(0, items.length - 1);
    goToIndex(newIndex);

    // Trash via repository
    // Get.find<MediaRepository>().trashItems([item.id]);
  }

  // ── Video ────────────────────────────────────────────────────

  void toggleVideoPlayback() {
    isVideoPlaying.value = !isVideoPlaying.value;
  }

  // ── Private helpers ─────────────────────────────────────────

  void _clearExif() {
    exifData.value = null;
    isLoadingExif.value = false;
  }
}