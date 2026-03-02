// ============================================================
// features/ai/models/face_cluster.dart
// ============================================================
// Represents a cluster of photos that all contain the same person,
// as determined by face embedding similarity.
//
// LIFECYCLE:
//   1. FaceRecognitionService detects faces → DetectedFace list
//   2. AiPipelineService.clusterFaces() groups DetectedFaces
//      by cosine similarity of their embeddings
//   3. Each group becomes a FaceCluster saved to secure_folder_view storage
//   4. PeopleView reads clusters and shows one cover photo per person
//
// STORAGE:
//   Clusters are persisted as JSON in SecureStorageService so they
//   survive app restarts without re-running the full scan.
//   Key pattern: "face_cluster_<clusterId>"
// ============================================================

import 'dart:convert';

class FaceCluster {
  /// Unique ID for this cluster (UUID).
  final String clusterId;

  /// User-assigned name (e.g. "Mom", "John") — null until named.
  final String? personName;

  /// Asset ID of the photo used as the cover/representative image.
  final String coverAssetId;

  /// All asset IDs of photos that contain this person's face.
  final List<String> assetIds;

  /// Centroid embedding — average of all face embeddings in the cluster.
  /// Used to assign new photos to an existing cluster on incremental scans.
  final List<double> centroidEmbedding;

  /// When this cluster was first created.
  final DateTime createdAt;

  /// When a new photo was last added to this cluster.
  final DateTime lastUpdatedAt;

  FaceCluster({
    required this.clusterId,
    this.personName,
    required this.coverAssetId,
    required this.assetIds,
    required this.centroidEmbedding,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  /// Number of photos featuring this person.
  int get photoCount => assetIds.length;

  /// True if the user has given this person a name.
  bool get isNamed => personName != null && personName!.isNotEmpty;

  /// Display name — falls back to "Person N" if unnamed.
  String displayName(int index) => isNamed ? personName! : 'Person $index';

  // ── Immutable update helpers ────────────────────────────────

  FaceCluster copyWith({
    String? personName,
    String? coverAssetId,
    List<String>? assetIds,
    List<double>? centroidEmbedding,
    DateTime? lastUpdatedAt,
  }) =>
      FaceCluster(
        clusterId: clusterId,
        personName: personName ?? this.personName,
        coverAssetId: coverAssetId ?? this.coverAssetId,
        assetIds: assetIds ?? this.assetIds,
        centroidEmbedding: centroidEmbedding ?? this.centroidEmbedding,
        createdAt: createdAt,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      );

  /// Returns a new cluster with [assetId] added and centroid updated.
  FaceCluster addPhoto(String assetId, List<double> embedding) {
    if (assetIds.contains(assetId)) return this;

    // Update centroid: incremental average
    // newCentroid = (oldCentroid * n + newEmbedding) / (n + 1)
    final n = assetIds.length;
    final newCentroid = List<double>.generate(
      centroidEmbedding.length,
          (i) => (centroidEmbedding[i] * n + embedding[i]) / (n + 1),
    );

    return copyWith(
      assetIds: [...assetIds, assetId],
      centroidEmbedding: newCentroid,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Returns a new cluster with [assetId] removed.
  FaceCluster removePhoto(String assetId) {
    if (!assetIds.contains(assetId)) return this;
    final updated = assetIds.where((id) => id != assetId).toList();
    return copyWith(
      assetIds: updated,
      // Update cover if the removed photo was the cover
      coverAssetId: coverAssetId == assetId && updated.isNotEmpty
          ? updated.first
          : coverAssetId,
      lastUpdatedAt: DateTime.now(),
    );
  }

  // ── JSON serialization ───────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'clusterId': clusterId,
    'personName': personName,
    'coverAssetId': coverAssetId,
    'assetIds': assetIds,
    'centroidEmbedding': centroidEmbedding,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
  };

  factory FaceCluster.fromJson(Map<String, dynamic> json) => FaceCluster(
    clusterId: json['clusterId'] as String,
    personName: json['personName'] as String?,
    coverAssetId: json['coverAssetId'] as String,
    assetIds: List<String>.from(json['assetIds'] as List),
    centroidEmbedding:
    List<double>.from(json['centroidEmbedding'] as List),
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
  );

  String toJsonString() => jsonEncode(toJson());

  factory FaceCluster.fromJsonString(String raw) =>
      FaceCluster.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  // ── Factory: create a brand-new cluster from the first photo ──

  factory FaceCluster.fromFirstPhoto({
    required String clusterId,
    required String assetId,
    required List<double> embedding,
  }) =>
      FaceCluster(
        clusterId: clusterId,
        coverAssetId: assetId,
        assetIds: [assetId],
        centroidEmbedding: List<double>.from(embedding),
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
      );
}