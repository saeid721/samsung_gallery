import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';

/// ------------------------------------------------------------
/// MODEL: Detected Face
/// ------------------------------------------------------------
class DetectedFace {
  final Face mlkitFace;
  final String assetId;
  final ui.Rect boundingBox;
  final List<double> embedding;

  const DetectedFace({
    required this.mlkitFace,
    required this.assetId,
    required this.boundingBox,
    required this.embedding,
  });

  double get headEulerAngleY => mlkitFace.headEulerAngleY ?? 0;
  double get headEulerAngleZ => mlkitFace.headEulerAngleZ ?? 0;

  bool get isFrontal =>
      headEulerAngleY.abs() < 30 && headEulerAngleZ.abs() < 20;
}

/// ------------------------------------------------------------
/// SERVICE: Face Recognition
/// ------------------------------------------------------------
class FaceRecognitionService {
  FaceDetector? _detector;

  /// Initialize MLKit detector (reused)
  FaceDetector _getDetector() {
    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate, // ✅ FIXED
        enableLandmarks: true,
        enableClassification: false,
        enableTracking: false,
        minFaceSize: 0.1,
      ),
    );
    return _detector!;
  }

  /// ----------------------------------------------------------
  /// DETECT FACES IN SINGLE IMAGE
  /// ----------------------------------------------------------
  Future<List<DetectedFace>> detectFaces(String assetId) async {
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return [];

      final file = await asset.originFile;
      if (file == null) return [];

      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _getDetector().processImage(inputImage);

      if (faces.isEmpty) return [];

      final imageBytes = await file.readAsBytes();
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return [];

      final results = <DetectedFace>[];

      for (final face in faces) {
        final box = face.boundingBox; // This is dart:ui Rect

        Uint8List? cropBytes = _cropFace(decoded, box);

        final embedding = cropBytes != null
            ? await _extractEmbedding(cropBytes)
            : List<double>.filled(128, 0.0);

        results.add(
          DetectedFace(
            mlkitFace: face,
            assetId: assetId,
            boundingBox: box, // ✅ No conversion needed
            embedding: embedding,
          ),
        );
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// ----------------------------------------------------------
  /// BATCH DETECT
  /// ----------------------------------------------------------
  Stream<DetectedFace> detectFacesInBatch(
      List<String> assetIds) async* {
    int index = 0;

    for (final assetId in assetIds) {
      final faces = await detectFaces(assetId);

      for (final face in faces) {
        yield face;
      }

      index++;
      if (index % 10 == 0) {
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// ----------------------------------------------------------
  /// COSINE SIMILARITY
  /// ----------------------------------------------------------
  static double cosineSimilarity(
      List<double> a,
      List<double> b,
      ) {
    if (a.length != b.length) return 0;

    double dot = 0, normA = 0, normB = 0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0;

    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// ----------------------------------------------------------
  /// EMBEDDING STUB (Replace with TFLite later)
  /// ----------------------------------------------------------
  Future<List<double>> _extractEmbedding(
      Uint8List faceCropBytes) async {
    return List<double>.filled(128, 0.0);
  }

  /// ----------------------------------------------------------
  /// CROP FACE WITH PADDING
  /// ----------------------------------------------------------
  Uint8List? _cropFace(img.Image source, ui.Rect box) {
    try {
      final padX = box.width * 0.2;
      final padY = box.height * 0.2;

      final x = (box.left - padX)
          .clamp(0, source.width.toDouble())
          .toInt();

      final y = (box.top - padY)
          .clamp(0, source.height.toDouble())
          .toInt();

      final w = (box.width + padX * 2)
          .clamp(1, source.width - x.toDouble())
          .toInt();

      final h = (box.height + padY * 2)
          .clamp(1, source.height - y.toDouble())
          .toInt();

      final cropped = img.copyCrop(
        source,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      // ✅ FIXED: encodeJpg instead of encodeJpeg
      return Uint8List.fromList(
        img.encodeJpg(cropped, quality: 90),
      );
    } catch (_) {
      return null;
    }
  }

  /// ----------------------------------------------------------
  /// DISPOSE
  /// ----------------------------------------------------------
  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}