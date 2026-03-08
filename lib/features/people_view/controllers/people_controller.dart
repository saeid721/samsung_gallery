
import 'dart:convert';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/ai_pipeline_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../data/models/face_cluster.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/face_recognition_service.dart';
import '../../../data/repositories/media_repository.dart';

class PeopleController extends GetxController {
  // final FaceRecognitionService _faceService = Get.find<FaceRecognitionService>();
  // final AiPipelineService      _aiService   = Get.find<AiPipelineService>();
  final MediaRepository        _mediaRepo   = Get.find<MediaRepository>();
  final SecureStorageService   _storage     = Get.find<SecureStorageService>();
  final _uuid = const Uuid();

  static const _clustersKey = 'face_clusters_index'; // list of cluster IDs
  static const _clusterPrefix = 'face_cluster_';     // per-cluster JSON key

  // ── Observable state ─────────────────────────────────────────
  final RxList<FaceCluster> clusters        = <FaceCluster>[].obs;
  final RxBool              isLoading       = true.obs;
  final RxBool              isScanning      = false.obs;
  final RxDouble            scanProgress    = 0.0.obs;  // 0.0 – 1.0
  final RxString            scanStatus      = ''.obs;
  final RxBool              isSelectionMode = false.obs;
  final RxSet<String>       selectedIds     = <String>{}.obs;

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _loadClusters();
  }

  // @override
  // void onClose() {
  //   _faceService.dispose();
  //   super.onClose();
  // }

  // ── Load persisted clusters ───────────────────────────────────

  Future<void> _loadClusters() async {
    isLoading.value = true;
    try {
      final indexRaw = await _storage.read(_clustersKey);
      if (indexRaw == null) {
        isLoading.value = false;
        return;
      }

      final ids = List<String>.from(jsonDecode(indexRaw) as List);
      final loaded = <FaceCluster>[];

      for (final id in ids) {
        final raw = await _storage.read('$_clusterPrefix$id');
        if (raw == null) continue;
        try {
          loaded.add(FaceCluster.fromJsonString(raw));
        } catch (_) {
          // Skip corrupt cluster data
        }
      }

      // Sort: named clusters first, then by photo count desc
      loaded.sort((a, b) {
        if (a.isNamed && !b.isNamed) return -1;
        if (!a.isNamed && b.isNamed) return 1;
        return b.photoCount.compareTo(a.photoCount);
      });

      clusters.assignAll(loaded);
    } finally {
      isLoading.value = false;
    }
  }

  // ── FACE SCAN — runs in background, streams progress ─────────

  Future<void> startFaceScan() async {
    if (isScanning.value) return;

    isScanning.value = true;
    scanProgress.value = 0.0;
    scanStatus.value = 'Loading photos…';

    try {
      // 1. Load all image asset IDs
      final timeline = await _mediaRepo.getTimelineStream().first;
      final allItems = timeline
          .expand((g) => g.items)
          .where((item) => item.type == MediaType.image)
          .toList();

      if (allItems.isEmpty) {
        scanStatus.value = 'No photos found.';
        return;
      }

      scanStatus.value = 'Detecting faces…';
      final total = allItems.length;

      // 2. Current clusters (used for incremental assignment)
      final currentClusters = List<FaceCluster>.from(clusters);
      int processed = 0;

      // 3. Process each image via FaceRecognitionService
      // for (final item in allItems) {
      //   final faces = await _faceService.detectFaces(item.id);
      //
      //   for (final face in faces) {
      //     if (!face.isFrontal) continue; // Skip profile faces
      //
      //     // Try to assign to an existing cluster
      //     bool assigned = false;
      //     for (int i = 0; i < currentClusters.length; i++) {
      //       final similarity = FaceRecognitionService.cosineSimilarity(
      //         currentClusters[i].centroidEmbedding,
      //         face.embedding,
      //       );
      //
      //       if (similarity > 0.6) {
      //         // Assign to this cluster
      //         currentClusters[i] =
      //             currentClusters[i].addPhoto(item.id, face.embedding);
      //         await _persistCluster(currentClusters[i]);
      //         assigned = true;
      //         break;
      //       }
      //     }
      //
      //     // No matching cluster — create a new one
      //     if (!assigned) {
      //       final newCluster = FaceCluster.fromFirstPhoto(
      //         clusterId: _uuid.v4(),
      //         assetId: item.id,
      //         embedding: face.embedding,
      //       );
      //       currentClusters.add(newCluster);
      //       await _persistCluster(newCluster);
      //     }
      //   }
      //
      //   processed++;
      //   scanProgress.value = processed / total;
      //   scanStatus.value =
      //   'Scanning ${processed} of ${total} photos…';
      //
      //   // Yield to UI every 20 items to prevent ANR
      //   if (processed % 20 == 0) {
      //     clusters.assignAll(currentClusters);
      //     await Future.delayed(Duration.zero);
      //   }
      // }

      // 4. Remove micro-clusters with < 2 photos (likely false detections)
      final filtered =
      currentClusters.where((c) => c.photoCount >= 2).toList();

      // 5. Persist final cluster index
      await _saveClusterIndex(filtered);
      clusters.assignAll(filtered);
      scanStatus.value = 'Done — found ${filtered.length} people.';
    } catch (e) {
      scanStatus.value = 'Scan failed: $e';
    } finally {
      isScanning.value = false;
      scanProgress.value = 1.0;
    }
  }

  // ── RENAME person ─────────────────────────────────────────────

  Future<void> renamePerson(String clusterId, String newName) async {
    final index = clusters.indexWhere((c) => c.clusterId == clusterId);
    if (index == -1) return;

    final updated = clusters[index].copyWith(personName: newName.trim());
    clusters[index] = updated;
    await _persistCluster(updated);
    clusters.refresh();
  }

  // ── MERGE two clusters (same person identified incorrectly) ───

  Future<void> mergeClusters(String keepId, String mergeId) async {
    final keepIndex  = clusters.indexWhere((c) => c.clusterId == keepId);
    final mergeIndex = clusters.indexWhere((c) => c.clusterId == mergeId);
    if (keepIndex == -1 || mergeIndex == -1) return;

    final keep  = clusters[keepIndex];
    final merge = clusters[mergeIndex];

    // Combine asset ID lists (deduplicated)
    final combinedIds = {...keep.assetIds, ...merge.assetIds}.toList();

    // Average the two centroids weighted by photo count
    final n1 = keep.assetIds.length.toDouble();
    final n2 = merge.assetIds.length.toDouble();
    final combined = List<double>.generate(
      keep.centroidEmbedding.length,
          (i) => (keep.centroidEmbedding[i] * n1 +
          merge.centroidEmbedding[i] * n2) /
          (n1 + n2),
    );

    final merged = keep.copyWith(
      assetIds: combinedIds,
      centroidEmbedding: combined,
      lastUpdatedAt: DateTime.now(),
    );

    // Remove merged cluster from storage
    await _storage.delete('$_clusterPrefix$mergeId');
    clusters.removeAt(mergeIndex);

    // Update keep cluster
    clusters[keepIndex > mergeIndex ? keepIndex - 1 : keepIndex] = merged;
    await _persistCluster(merged);
    await _saveClusterIndex(clusters);
    clusters.refresh();
  }

  // ── REMOVE a single photo from a cluster ─────────────────────

  Future<void> removePhotoFromCluster(
      String clusterId, String assetId) async {
    final index = clusters.indexWhere((c) => c.clusterId == clusterId);
    if (index == -1) return;

    final updated = clusters[index].removePhoto(assetId);
    clusters[index] = updated;
    await _persistCluster(updated);
    clusters.refresh();
  }

  // ── DELETE entire cluster ─────────────────────────────────────

  Future<void> deleteCluster(String clusterId) async {
    await _storage.delete('$_clusterPrefix$clusterId');
    clusters.removeWhere((c) => c.clusterId == clusterId);
    await _saveClusterIndex(clusters);
  }

  // ── SELECTION mode ────────────────────────────────────────────

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

  Future<void> mergeSelected() async {
    if (selectedIds.length < 2) return;
    final ids = selectedIds.toList();
    final keepId = ids.first;
    for (int i = 1; i < ids.length; i++) {
      await mergeClusters(keepId, ids[i]);
    }
    exitSelectionMode();
  }

  // ── Private helpers ───────────────────────────────────────────

  Future<void> _persistCluster(FaceCluster cluster) async {
    await _storage.write(
        '$_clusterPrefix${cluster.clusterId}', cluster.toJsonString());
  }

  Future<void> _saveClusterIndex(List<FaceCluster> list) async {
    final ids = list.map((c) => c.clusterId).toList();
    await _storage.write(_clustersKey, jsonEncode(ids));
  }
}