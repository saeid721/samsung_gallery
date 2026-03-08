
import 'package:get/get.dart';

import '../../../data/repositories/album_repository.dart';

class AlbumsController extends GetxController {
  AlbumRepository get _albumRepo => Get.find<AlbumRepository>();

  // ── Observable state ────────────────────────────────────────

  final RxBool isLoading = true.obs;
  final RxList<Album> albums = <Album>[].obs;
  final RxBool isSelectionMode = false.obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  final RxString errorMessage = ''.obs;

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    loadAlbums();
  }

  // ── Load ────────────────────────────────────────────────────

  Future<void> loadAlbums() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await _albumRepo.getAlbums();
      albums.assignAll(result);
    } catch (e) {
      errorMessage.value = 'Failed to load albums: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => loadAlbums();

  // ── Create ───────────────────────────────────────────────────

  Future<void> createAlbum(String name) async {
    final album = await _albumRepo.createAlbum(name);
    if (album != null) {
      albums.add(album);
    } else {
      Get.snackbar('Error', 'Could not create album "$name"',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ── Rename ───────────────────────────────────────────────────

  Future<void> renameAlbum(String albumId, String newName) async {
    final success = await _albumRepo.renameAlbum(albumId, newName);
    if (success) {
      final index = albums.indexWhere((a) => a.id == albumId);
      if (index != -1) {
        albums[index] = albums[index].copyWith(name: newName);
      }
    } else {
      Get.snackbar('Error', 'Could not rename album',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ── Delete ───────────────────────────────────────────────────

  Future<void> deleteSelectedAlbums() async {
    for (final id in selectedIds) {
      final success = await _albumRepo.deleteAlbum(id);
      if (success) albums.removeWhere((a) => a.id == id);
    }
    exitSelectionMode();
  }

  // ── Selection ────────────────────────────────────────────────

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
}