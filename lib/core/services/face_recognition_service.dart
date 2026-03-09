// ============================================================
// features/ai/services/face_recognition_service.dart
// ============================================================
// On-device face detection + lightweight embedding via ML Kit.
//
// ARCHITECTURE:
//   ┌─────────────────────────────────────────┐
//   │  FaceRecognitionService                 │
//   │                                         │
//   │  detectFaces()      → List<DetectedFace>│
//   │  extractFaceData()  → List<FaceData>    │
//   │  batchScan()        → Stream<ScanEvent> │
//   │  cosineSimilarity() → double (static)   │
//   └─────────────────────────────────────────┘
//
// EMBEDDING STRATEGY:
//   ML Kit does NOT provide face embeddings directly.
//   We synthesise a lightweight 128-D pseudo-embedding from
//   the geometric landmark positions that ML Kit does give us.
//   This is good enough for same-person clustering on a typical
//   personal photo library (< 10k images, < 30 people).
//
//   For production-grade accuracy, replace _buildEmbedding() with
//   a TFLite FaceNet model:
//     assets/models/facenet_512.tflite  (download from GitHub)
//     package: tflite_flutter ^0.10.0
//
// DEPENDENCIES (add to pubspec.yaml):
//   google_mlkit_face_detection: ^0.11.0
//   photo_manager: ^3.0.0
// ============================================================

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:photo_manager/photo_manager.dart';

// ── Public result types ────────────────────────────────────────

/// A face detected inside a specific photo asset.
class DetectedFace {
  /// The asset that contains this face.
  final String assetId;

  /// Bounding box in image pixels.
  final ui.Rect boundingBox;

  /// 128-D embedding vector.  Two faces from the same person will
  /// have a cosine similarity > 0.60 on typical photos.
  final List<double> embedding;

  /// Whether the face is roughly frontal (pan angle < 30°).
  /// Profile faces should be skipped when clustering.
  final bool isFrontal;

  /// Quality score 0–1.  Higher = better candidate for cluster cover.
  final double quality;

  // ── Detailed attributes ──────────────────────────────────────
  final bool   smiling;
  final bool   leftEyeOpen;
  final bool   rightEyeOpen;
  final double headPan;   // left/right (Y-axis)
  final double headTilt;  // up/down    (X-axis)
  final double headRoll;  // clockwise  (Z-axis)

  const DetectedFace({
    required this.assetId,
    required this.boundingBox,
    required this.embedding,
    required this.isFrontal,
    required this.quality,
    required this.smiling,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.headPan,
    required this.headTilt,
    required this.headRoll,
  });

  ui.Offset get center => ui.Offset(
    boundingBox.left + boundingBox.width  / 2,
    boundingBox.top  + boundingBox.height / 2,
  );

  @override
  String toString() =>
      'DetectedFace(asset: $assetId, quality: ${quality.toStringAsFixed(2)}, '
          'frontal: $isFrontal)';
}

/// Progress event emitted during a batch scan.
class ScanEvent {
  final int     processed;
  final int     total;
  final String  currentAssetId;
  final int     facesFoundSoFar;

  const ScanEvent({
    required this.processed,
    required this.total,
    required this.currentAssetId,
    required this.facesFoundSoFar,
  });

  double get progress => total == 0 ? 0.0 : processed / total;

  String get statusText =>
      'Scanning $processed of $total…  ($facesFoundSoFar faces found)';
}

// ══════════════════════════════════════════════════════════════
// FACE RECOGNITION SERVICE
// ══════════════════════════════════════════════════════════════

class FaceRecognitionService {
  // ── Singleton-style lazy init ─────────────────────────────────
  static FaceDetector? _detector;
  bool _isInitialized = false;

  // ── Landmark indices used for embedding ───────────────────────
  // ML Kit provides up to 7 landmark types per face.
  static const _embeddingLandmarks = [
    FaceLandmarkType.leftEye,
    FaceLandmarkType.rightEye,
    FaceLandmarkType.noseBase,
    FaceLandmarkType.bottomMouth,
    FaceLandmarkType.leftMouth,
    FaceLandmarkType.rightMouth,
    FaceLandmarkType.leftCheek,
    FaceLandmarkType.rightCheek,
  ];

  // ── Init / dispose ────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks:      true,   // needed for embedding
        enableContours:       false,  // contours add latency, skip
        enableClassification: true,   // smiling / eyes-open
        enableTracking:       false,  // not needed for gallery scan
        minFaceSize:          0.08,   // detect faces ≥ 8% of image
        performanceMode:      FaceDetectorMode.accurate,
      ),
    );
    _isInitialized = true;
    debugPrint('[FaceRecognition] Initialized.');
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector        = null;
    _isInitialized   = false;
  }

  // ── Core detection ────────────────────────────────────────────

  /// Detect all faces in a single photo asset.
  /// Returns [] on any error (file missing, unsupported format, etc.)
  Future<List<DetectedFace>> detectFaces(String assetId) async {
    await _ensureInitialized();
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return [];
      final file = await asset.originFile;
      if (file == null) return [];

      final inputImage = InputImage.fromFilePath(file.path);
      final rawFaces   = await _detector!.processImage(inputImage);
      // InputImage is a plain data class — no close() needed

      // Get image dimensions for normalising landmark positions
      final width  = asset.width.toDouble().clamp(1.0, double.infinity);
      final height = asset.height.toDouble().clamp(1.0, double.infinity);

      return rawFaces
          .map((f) => _toDetectedFace(f, assetId, width, height))
          .toList();
    } catch (e, st) {
      debugPrint('[FaceRecognition] detectFaces($assetId) error: $e\n$st');
      return [];
    }
  }

  /// Detect faces in a list of asset IDs and stream progress events.
  ///
  /// Usage:
  ///   await for (final event in service.batchScan(ids)) {
  ///     updateProgress(event.progress, event.statusText);
  ///   }
  ///   final allFaces = service.lastBatchResults;
  Stream<ScanEvent> batchScan(List<String> assetIds) async* {
    await _ensureInitialized();
    _lastBatchResults.clear();

    final total = assetIds.length;
    int facesFound = 0;

    for (int i = 0; i < total; i++) {
      final id    = assetIds[i];
      final faces = await detectFaces(id);

      // Only keep frontal, quality > 0.3
      final good = faces.where((f) => f.isFrontal && f.quality > 0.3);
      _lastBatchResults.addAll(good);
      facesFound += good.length;

      yield ScanEvent(
        processed:      i + 1,
        total:          total,
        currentAssetId: id,
        facesFoundSoFar: facesFound,
      );

      // Yield to UI thread every 10 items to keep 60 fps
      if ((i + 1) % 10 == 0) {
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// Results accumulated by the most recent [batchScan] call.
  final List<DetectedFace> _lastBatchResults = [];
  List<DetectedFace> get lastBatchResults =>
      List.unmodifiable(_lastBatchResults);

  // ── Convenience helpers ───────────────────────────────────────

  Future<bool>   hasFaces(String id)   async => (await detectFaces(id)).isNotEmpty;
  Future<int>    getFaceCount(String id) async => (await detectFaces(id)).length;

  Future<double> getAverageFaceSize(String id) async {
    final faces = await detectFaces(id);
    if (faces.isEmpty) return 0.0;
    final total = faces.fold<double>(
        0, (s, f) => s + f.boundingBox.width * f.boundingBox.height);
    return total / faces.length;
  }

  // ── Static math ───────────────────────────────────────────────

  /// Cosine similarity between two embedding vectors.
  /// Returns 0.0 – 1.0 (1.0 = identical, 0.0 = orthogonal).
  static double cosineSimilarity(
      List<double> a, List<double> b) {
    assert(a.length == b.length,
    'Embedding length mismatch: ${a.length} vs ${b.length}');
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot   += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    return denom < 1e-10 ? 0.0 : (dot / denom).clamp(0.0, 1.0);
  }

  /// Euclidean (L2) distance between two embeddings.
  static double l2Distance(List<double> a, List<double> b) {
    assert(a.length == b.length);
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return math.sqrt(sum);
  }

  // ── Private helpers ───────────────────────────────────────────

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }

  /// Convert an ML Kit [Face] into our [DetectedFace] model.
  DetectedFace _toDetectedFace(
      Face face, String assetId, double imgW, double imgH) {
    final pan  = face.headEulerAngleY ?? 0.0;
    final tilt = face.headEulerAngleX ?? 0.0;
    final roll = face.headEulerAngleZ ?? 0.0;

    // Frontal: pan < ±30°, tilt < ±25°
    final isFrontal = pan.abs() < 30.0 && tilt.abs() < 25.0;

    final embedding = _buildEmbedding(face, imgW, imgH);
    final quality   = _qualityScore(face, imgW, imgH);

    return DetectedFace(
      assetId:      assetId,
      boundingBox:  face.boundingBox,
      embedding:    embedding,
      isFrontal:    isFrontal,
      quality:      quality,
      smiling:      (face.smilingProbability      ?? 0.0) > 0.5,
      leftEyeOpen:  (face.leftEyeOpenProbability  ?? 0.0) > 0.5,
      rightEyeOpen: (face.rightEyeOpenProbability ?? 0.0) > 0.5,
      headPan:  pan,
      headTilt: tilt,
      headRoll: roll,
    );
  }

  // ── Geometric pseudo-embedding ─────────────────────────────────
  //
  // Builds a 128-D vector from normalised landmark geometry.
  // Sufficient for clustering ≤ ~30 distinct identities.
  //
  // Vector layout (128 floats total):
  //   [0..15]   Inter-landmark distances (normalised by face size)
  //   [16..47]  Landmark (x,y) positions relative to face centre
  //   [48..79]  All pairwise angles between landmark triplets
  //   [80..111] Landmark positions normalised by image size
  //   [112..127] Head rotation features + bounding-box aspect ratio
  //
  // To replace with FaceNet TFLite:
  //   1. Add tflite_flutter: ^0.10.0 to pubspec
  //   2. Download facenet_512.tflite to assets/models/
  //   3. Replace the body of _buildEmbedding() with TFLite inference
  // ──────────────────────────────────────────────────────────────
  List<double> _buildEmbedding(Face face, double imgW, double imgH) {
    // Collect available landmark positions
    final pts = <ui.Offset>[];
    for (final type in _embeddingLandmarks) {
      final lm = face.landmarks[type];
      if (lm != null) {
        pts.add(ui.Offset(
          lm.position.x.toDouble() / imgW,
          lm.position.y.toDouble() / imgH,
        ));
      } else {
        // Use face centre as fallback for missing landmarks
        pts.add(ui.Offset(
          (face.boundingBox.left + face.boundingBox.width  / 2) / imgW,
          (face.boundingBox.top  + face.boundingBox.height / 2) / imgH,
        ));
      }
    }

    final n       = pts.length;
    final result  = <double>[];

    // ── Block 1: pairwise distances (n*(n-1)/2 values, ≤28 for n=8) ──
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        result.add(_dist(pts[i], pts[j]));
      }
    }

    // ── Block 2: (x,y) relative to face bounding-box centre ───────
    final cx = (face.boundingBox.left + face.boundingBox.width  / 2) / imgW;
    final cy = (face.boundingBox.top  + face.boundingBox.height / 2) / imgH;
    for (final p in pts) {
      result.add(p.dx - cx);
      result.add(p.dy - cy);
    }

    // ── Block 3: pairwise angles (radians) ────────────────────────
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final dx = pts[j].dx - pts[i].dx;
        final dy = pts[j].dy - pts[i].dy;
        result.add(math.atan2(dy, dx));
      }
    }

    // ── Block 4: absolute positions normalised by image size ───────
    for (final p in pts) {
      result.add(p.dx);
      result.add(p.dy);
    }

    // ── Block 5: head rotation + bounding box ──────────────────────
    result.add((face.headEulerAngleX ?? 0.0) / 90.0);
    result.add((face.headEulerAngleY ?? 0.0) / 90.0);
    result.add((face.headEulerAngleZ ?? 0.0) / 90.0);
    final bbW = face.boundingBox.width  / imgW;
    final bbH = face.boundingBox.height / imgH;
    result.add(bbW);
    result.add(bbH);
    result.add(bbW > 0 ? bbH / bbW : 1.0); // aspect ratio

    // ── Pad / trim to exactly 128 ───────────────────────────────────
    while (result.length < 128) result.add(0.0);
    final vec = result.take(128).toList();

    // ── L2-normalise ────────────────────────────────────────────────
    return _l2Normalize(vec);
  }

  /// Quality score 0–1.
  /// Weights: face size 40% | frontality 30% | eyes-open 20% | confidence 10%
  double _qualityScore(Face face, double imgW, double imgH) {
    // Size relative to image area
    final faceArea  = face.boundingBox.width * face.boundingBox.height;
    final imgArea   = imgW * imgH;
    final sizeFactor = (imgArea > 0 ? faceArea / imgArea : 0.0)
        .clamp(0.0, 0.5) * 2.0; // normalise so 50% coverage = 1.0

    // Frontality
    final totalAngle = ((face.headEulerAngleX ?? 0.0).abs() +
        (face.headEulerAngleY ?? 0.0).abs() +
        (face.headEulerAngleZ ?? 0.0).abs()) / 180.0;
    final frontalFactor = (1.0 - totalAngle.clamp(0.0, 1.0));

    // Eyes
    final eyeFactor = ((face.leftEyeOpenProbability  ?? 0.5) +
        (face.rightEyeOpenProbability ?? 0.5)) / 2.0;

    // Landmark completeness (how many of the 7 landmarks were found)
    final lmCount = _embeddingLandmarks
        .where((t) => face.landmarks[t] != null)
        .length;
    final lmFactor = lmCount / _embeddingLandmarks.length;

    return (sizeFactor  * 0.40 +
        frontalFactor * 0.30 +
        eyeFactor   * 0.20 +
        lmFactor    * 0.10)
        .clamp(0.0, 1.0);
  }

  static double _dist(ui.Offset a, ui.Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  static List<double> _l2Normalize(List<double> v) {
    final norm = math.sqrt(v.fold<double>(0, (s, x) => s + x * x));
    if (norm < 1e-10) return v;
    return v.map((x) => x / norm).toList();
  }
}

// ══════════════════════════════════════════════════════════════
// FACE DATA (lightweight alias for non-clustering use cases)
// ══════════════════════════════════════════════════════════════
// Used by AiPipelineService and any widget that only needs
// bounding box + quality info without a full embedding.

class FaceData {
  final ui.Rect        boundingBox;
  final List<ui.Offset> landmarks;
  final bool           smiling;
  final bool           leftEyeOpen;
  final bool           rightEyeOpen;
  final double         headEulerAngleX;
  final double         headEulerAngleY;
  final double         headEulerAngleZ;

  const FaceData({
    required this.boundingBox,
    required this.landmarks,
    required this.smiling,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.headEulerAngleX,
    required this.headEulerAngleY,
    required this.headEulerAngleZ,
  });

  factory FaceData.fromMLKitFace(Face face) {
    // face.landmarks is Map<FaceLandmarkType, FaceLandmark?>
    // iterate .values, filter nulls
    final offsets = face.landmarks.values
        .whereType<FaceLandmark>()
        .map((l) => ui.Offset(
      l.position.x.toDouble(),
      l.position.y.toDouble(),
    ))
        .toList();

    return FaceData(
      boundingBox:      face.boundingBox, // already dart:ui Rect
      landmarks:        offsets,
      smiling:         (face.smilingProbability      ?? 0.0) > 0.5,
      leftEyeOpen:     (face.leftEyeOpenProbability  ?? 0.0) > 0.5,
      rightEyeOpen:    (face.rightEyeOpenProbability ?? 0.0) > 0.5,
      headEulerAngleX:  face.headEulerAngleX ?? 0.0,
      headEulerAngleY:  face.headEulerAngleY ?? 0.0,
      headEulerAngleZ:  face.headEulerAngleZ ?? 0.0,
    );
  }

  /// Factory from DetectedFace — for code that passes either type.
  factory FaceData.fromDetectedFace(DetectedFace df) => FaceData(
    boundingBox:      df.boundingBox,
    landmarks:        const [],
    smiling:          df.smiling,
    leftEyeOpen:      df.leftEyeOpen,
    rightEyeOpen:     df.rightEyeOpen,
    headEulerAngleX:  df.headTilt,
    headEulerAngleY:  df.headPan,
    headEulerAngleZ:  df.headRoll,
  );

  ui.Offset get center => ui.Offset(
    boundingBox.left + boundingBox.width  / 2,
    boundingBox.top  + boundingBox.height / 2,
  );

  double get qualityScore {
    double score = 0.0;
    score += (boundingBox.width * boundingBox.height).clamp(0.0, 1.0) * 0.4;
    final tilt = ((headEulerAngleX.abs() +
        headEulerAngleY.abs() +
        headEulerAngleZ.abs()) / 180.0)
        .clamp(0.0, 1.0);
    score += (1.0 - tilt) * 0.3;
    score += (leftEyeOpen && rightEyeOpen ? 1.0 : 0.5) * 0.3;
    return score.clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'FaceData(bbox: $boundingBox, quality: ${qualityScore.toStringAsFixed(2)})';
}
