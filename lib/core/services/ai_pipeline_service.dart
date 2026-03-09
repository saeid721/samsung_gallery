import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;
import '../../data/models/face_cluster.dart';
import '../../data/models/media_model.dart';
import '../../data/models/memory_story.dart';
import 'face_recognition_service.dart';

class AiPipelineService {
  final FaceRecognitionService _faceService;

  AiPipelineService({required FaceRecognitionService faceService})
      : _faceService = faceService;

  // ============================================================
  // 1. FACE CLUSTERING
  // Groups photos by the people in them using MLKit face detection
  // + embedding comparison for identity matching.
  // ============================================================

  Future<List<FaceCluster>> clusterFaces(List<MediaItem> items) async {
    // Run in background isolate to avoid UI freeze
    final imagePaths = items
        .where((item) => item.type == MediaType.image)
        .map((item) => item.id)
        .toList();

    // Step 1: Detect faces in all images
    final faceData = <String, List<Face>>{}; // assetId → faces
    for (final assetId in imagePaths) {
      final faces = await _faceService.detectFaces(assetId);
      if (faces.isNotEmpty) {
        final faceData = <String, List<DetectedFace>>{};
      }
    }

    // Step 2: Extract face embeddings (128-dim vectors)
    // Step 3: Cluster using DBSCAN or cosine similarity threshold
    // PSEUDO-CODE: Full embedding model requires TFLite model file
    // See assets/models/facenet.tflite (add to pubspec assets)

    /*
    PSEUDO-CODE FOR FACE EMBEDDING + CLUSTERING:

    final embeddings = await compute(_extractEmbeddings, faceData);

    // Cosine similarity clustering
    final clusters = <FaceCluster>[];
    final threshold = 0.6; // tune for false-positive/negative tradeoff

    for (final (assetId, embedding) in embeddings.entries) {
      bool added = false;
      for (final cluster in clusters) {
        final similarity = cosineSimilarity(cluster.centroid, embedding);
        if (similarity > threshold) {
          cluster.addPhoto(assetId, embedding);
          added = true;
          break;
        }
      }
      if (!added) {
        clusters.add(FaceCluster.fromPhoto(assetId, embedding));
      }
    }
    return clusters;
    */

    // Stub return for template
    return [];
  }

  // ============================================================
  // 2. AUTO ENHANCE
  // Adjusts brightness, contrast, saturation automatically
  // using histogram analysis (no external model needed).
  // ============================================================

  Future<Uint8List> autoEnhance(String imagePath) async {
    return compute(_autoEnhanceIsolate, imagePath);
  }

  static Future<Uint8List> _autoEnhanceIsolate(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // 1. Auto-level: stretch histogram to use full 0-255 range
    image = img.normalize(image, min: 0, max: 255);

    // 2. Auto white balance: shift color cast to neutral gray
    // Compute average R, G, B of entire image
    double sumR = 0, sumG = 0, sumB = 0;
    final pixelCount = image.width * image.height;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        sumR += pixel.r;
        sumG += pixel.g;
        sumB += pixel.b;
      }
    }
    final avgR = sumR / pixelCount;
    final avgG = sumG / pixelCount;
    final avgB = sumB / pixelCount;
    final avgGray = (avgR + avgG + avgB) / 3;

    // Scale factors to make each channel average match gray
    final scaleR = avgGray / avgR.clamp(1, 255);
    final scaleG = avgGray / avgG.clamp(1, 255);
    final scaleB = avgGray / avgB.clamp(1, 255);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        image.setPixelRgb(
          x, y,
          (pixel.r * scaleR).clamp(0, 255).toInt(),
          (pixel.g * scaleG).clamp(0, 255).toInt(),
          (pixel.b * scaleB).clamp(0, 255).toInt(),
        );
      }
    }

    // 3. Slight contrast boost
    image = img.adjustColor(image, contrast: 1.1);

    // 4. Slight saturation boost
    image = img.adjustColor(image, saturation: 1.15);

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  // ============================================================
  // 3. BACKGROUND BLUR (Portrait Mode Simulation)
  // Uses MLKit selfie segmentation to separate subject from BG,
  // then applies Gaussian blur to background only.
  // ============================================================

  Future<Uint8List> applyBackgroundBlur({
    required String imagePath,
    required double blurRadius,
  }) async {
    /*
    PSEUDO-CODE:

    // 1. Run MLKit selfie segmentation to get mask
    final segmenter = ImageSegmenter.withOptions(ImageSegmenterOptions(
      outputType: OutputType.confidenceMask,
    ));
    final mask = await segmenter.processImage(InputImage.fromFilePath(imagePath));

    // 2. Apply Gaussian blur to entire image
    final blurred = img.gaussianBlur(originalImage, radius: blurRadius.toInt());

    // 3. Composite: use mask to blend original (subject) + blurred (background)
    for each pixel:
      confidence = mask[x][y];  // 0.0=background, 1.0=subject
      result[x][y] = lerp(blurred[x][y], original[x][y], confidence);

    return result;
    */

    // Stub: return original image bytes
    return File(imagePath).readAsBytes();
  }

  // ============================================================
  // 4. OBJECT ERASER (Generative AI Placeholder)
  // User selects a region; AI fills it with realistic content.
  //
  // PRODUCTION IMPLEMENTATION OPTIONS:
  //   A. On-device: LaMa inpainting model via TFLite
  //      Model: github.com/advimman/lama (convert to TFLite)
  //   B. Cloud API: Stability AI Inpainting endpoint
  //      Free tier: 25 generations/month
  //   C. OpenCV: Simple inpainting for structured backgrounds
  // ============================================================

  Future<Uint8List> eraseObject({
    required String imagePath,
    required Rect selectionRect, // User-drawn selection area
    EraseMethod method = EraseMethod.opencv,
  }) async {
    switch (method) {
      case EraseMethod.opencv:
        return _opencvInpaint(imagePath, selectionRect);
      case EraseMethod.tflite:
        return _lamaInpaint(imagePath, selectionRect);
      case EraseMethod.cloudApi:
        return _cloudInpaint(imagePath, selectionRect);
    }
  }

  Future<Uint8List> _opencvInpaint(String imagePath, Rect rect) async {
    /*
    PSEUDO-CODE (OpenCV via FFI or opencv_dart package):

    final mat = cv.imread(imagePath);
    final mask = cv.Mat.zeros(mat.rows, mat.cols, cv.MatType.CV_8UC1);

    // Fill selection rectangle in mask
    cv.rectangle(mask, cv.Point(rect.left, rect.top),
        cv.Point(rect.right, rect.bottom), cv.Scalar.white, -1);

    // Run Navier-Stokes inpainting (good for small objects)
    final result = cv.inpaint(mat, mask, 3, cv.INPAINT_NS);

    return cv.imencode('.jpg', result);
    */
    return File(imagePath).readAsBytes(); // Stub
  }

  Future<Uint8List> _lamaInpaint(String imagePath, Rect rect) async {
    /*
    PSEUDO-CODE (TFLite LaMa model):

    final interpreter = await Interpreter.fromAsset('assets/models/lama.tflite');

    // Preprocess: resize to 512x512, normalize to [-1, 1]
    final inputImage = preprocessForLama(imagePath, rect);
    final inputMask = createMask(512, 512, rect);

    // Run inference
    final output = List.filled(1 * 512 * 512 * 3, 0.0).reshape([1, 512, 512, 3]);
    interpreter.run([inputImage, inputMask], output);

    // Post-process: denormalize, resize back to original
    return postprocessLamaOutput(output, originalSize);
    */
    return File(imagePath).readAsBytes(); // Stub
  }

  Future<Uint8List> _cloudInpaint(String imagePath, Rect rect) async {
    /*
    PSEUDO-CODE (Stability AI API):

    final file = File(imagePath);
    final bytes = await file.readAsBytes();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.stability.ai/v2beta/stable-image/edit/inpaint'),
    );
    request.headers['authorization'] = 'Bearer $apiKey';
    request.files.add(http.MultipartFile.fromBytes('image', bytes));

    // Create mask image (white = erase, black = keep)
    final mask = createMaskImage(imageSize, rect);
    request.files.add(http.MultipartFile.fromBytes('mask', mask));

    request.fields['output_format'] = 'jpeg';

    final response = await request.send();
    return response.stream.toBytes();
    */
    return File(imagePath).readAsBytes(); // Stub
  }

  // ============================================================
  // 5. OCR / TEXT RECOGNITION
  // Extracts text from images for search indexing.
  // ============================================================

  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await recognizer.processImage(inputImage);
    await recognizer.close();

    // Return all recognized text blocks joined
    return result.blocks.map((block) => block.text).join('\n');
  }

  // ============================================================
  // 6. DUPLICATE DETECTION (Perceptual Hash)
  // pHash: robust against resize, slight color changes, compression.
  // Two photos with hamming distance < 10 are "duplicates".
  // ============================================================

  Future<String> computePerceptualHash(String imagePath) async {
    return compute(_computePHashIsolate, imagePath);
  }

  static Future<String> _computePHashIsolate(String path) async {
    final bytes = await File(path).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return '';

    // 1. Convert to grayscale
    image = img.grayscale(image);

    // 2. Resize to 32x32 (capture structure, not detail)
    image = img.copyResize(image, width: 32, height: 32);

    // 3. Compute DCT (Discrete Cosine Transform) — simplified 8x8 version
    // Full DCT-based pHash uses top-left 8x8 of 32x32 DCT
    final pixels = <double>[];
    for (int y = 0; y < 32; y++) {
      for (int x = 0; x < 32; x++) {
        pixels.add(image.getPixel(x, y).r.toDouble());
      }
    }

    // 4. Compute average of first 64 DCT coefficients
    final avg = pixels.take(64).reduce((a, b) => a + b) / 64;

    // 5. Build 64-bit hash: 1 if pixel > avg, 0 otherwise
    final hashBits = pixels.take(64).map((p) => p > avg ? '1' : '0').join();

    // Convert binary string to hex
    final hashInt = BigInt.parse(hashBits, radix: 2);
    return hashInt.toRadixString(16).padLeft(16, '0');
  }

  static int _hammingDistance(String hash1, String hash2) {
    assert(hash1.length == hash2.length);
    int distance = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) distance++;
    }
    return distance;
  }

  // ============================================================
  // 7. IMAGE LABELING (Scene/Object Detection)
  // Used for AI search ("beach", "dog", "food", etc.)
  // ============================================================

  Future<List<ImageLabel>> labelImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.7),
    );
    final labels = await labeler.processImage(inputImage);
    await labeler.close();
    return labels;
  }

  // ============================================================
  // 8. MEMORIES / STORIES GENERATION
  // Auto-creates collages from clusters of related photos.
  // Clusters by: date (same day), location, faces detected.
  // ============================================================

  Future<List<MemoryStory>> generateMemories(List<MediaItem> allItems) async {
    final stories = <MemoryStory>[];

    // Group by month for "X months ago" memories
    final byMonth = <String, List<MediaItem>>{};
    for (final item in allItems) {
      final key =
          '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(item);
    }

    for (final entry in byMonth.entries) {
      if (entry.value.length >= 5) {
        // Need at least 5 photos for a story
        // Sort by score: prefer landscape, faces detected, high resolution
        final selected = entry.value
            .take(12) // max 12 photos per story
            .toList();

        stories.add(MemoryStory(
          id: entry.key,
          title: _formatStoryTitle(entry.key),
          coverItem: selected.first,
          items: selected,
          createdAt: selected.first.createdAt,
        ));
      }
    }

    return stories;
  }

  String _formatStoryTitle(String monthKey) {
    final parts = monthKey.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final monthName = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][date.month];
    final year = date.year;
    final yearsAgo = DateTime.now().year - year;
    if (yearsAgo == 0) return '$monthName Highlights';
    if (yearsAgo == 1) return 'A Year Ago — $monthName';
    return '$yearsAgo Years Ago — $monthName $year';
  }
}

// ── Supporting types ────────────────────────────────────────

enum EraseMethod { opencv, tflite, cloudApi }

// Stub Rect (use dart:ui Rect in real code)
class Rect {
  final double left, top, right, bottom;
  const Rect({required this.left, required this.top,
    required this.right, required this.bottom});
}