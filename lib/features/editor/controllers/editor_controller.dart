import 'dart:typed_data';
import 'package:get/get.dart';

import '../../../core/services/ai_pipeline_service.dart';
import '../../../data/models/media_model.dart';

// Filter presets
enum PhotoFilter { none, vivid, warm, cool, bw, fade, chrome }

class EditorController extends GetxController {
  final AiPipelineService _aiService = Get.find<AiPipelineService>();

  // ── The item being edited ────────────────────────────────────
  final Rx<MediaItem?> mediaItem = Rx(null);

  // ── Current edited image bytes (null = show original) ───────
  final Rx<Uint8List?> editedBytes = Rx(null);

  // ── Observable adjustment values (all 0.0 = no change) ──────
  final RxDouble brightness  = 0.0.obs;   // -1.0 to +1.0
  final RxDouble contrast    = 0.0.obs;   // -1.0 to +1.0
  final RxDouble saturation  = 0.0.obs;   // -1.0 to +1.0
  final RxDouble warmth      = 0.0.obs;   // -1.0 to +1.0
  final RxDouble exposure    = 0.0.obs;   // -1.0 to +1.0
  final RxDouble shadows     = 0.0.obs;   // -1.0 to +1.0
  final RxDouble highlights  = 0.0.obs;   // -1.0 to +1.0
  final RxDouble straighten  = 0.0.obs;   // -45.0 to +45.0 degrees

  // ── Rotation (0, 90, 180, 270) ───────────────────────────────
  final RxInt rotationDegrees = 0.obs;

  // ── Flip state ───────────────────────────────────────────────
  final RxBool flipHorizontal = false.obs;
  final RxBool flipVertical   = false.obs;

  // ── Active filter ────────────────────────────────────────────
  final Rx<PhotoFilter> activeFilter = PhotoFilter.none.obs;

  // ── Video trim points (seconds) ──────────────────────────────
  final RxDouble trimStart = 0.0.obs;
  final RxDouble trimEnd   = 0.0.obs;
  final RxBool   isMuted   = false.obs;

  // ── UI state ─────────────────────────────────────────────────
  final RxBool isProcessing = false.obs;
  final RxBool hasUnsavedChanges = false.obs;

  // ── Undo stack ───────────────────────────────────────────────
  final _undoStack = <Uint8List>[];
  static const _maxUndoSteps = 10;

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    mediaItem.value = args?['mediaItem'] as MediaItem?;

    // Init video trim end to full duration
    if (mediaItem.value?.isVideo == true) {
      trimEnd.value = mediaItem.value!.duration.inSeconds.toDouble();
    }
  }

  // ── Image adjustments ────────────────────────────────────────

  void setBrightness(double value)  { brightness.value  = value; _markDirty(); }
  void setContrast(double value)    { contrast.value    = value; _markDirty(); }
  void setSaturation(double value)  { saturation.value  = value; _markDirty(); }
  void setWarmth(double value)      { warmth.value      = value; _markDirty(); }
  void setExposure(double value)    { exposure.value    = value; _markDirty(); }
  void setShadows(double value)     { shadows.value     = value; _markDirty(); }
  void setHighlights(double value)  { highlights.value  = value; _markDirty(); }
  void setStraighten(double value)  { straighten.value  = value; _markDirty(); }

  // ── Rotation & Flip ──────────────────────────────────────────

  void rotateClockwise() {
    rotationDegrees.value = (rotationDegrees.value + 90) % 360;
    _markDirty();
  }

  void rotateCounterClockwise() {
    rotationDegrees.value = (rotationDegrees.value - 90 + 360) % 360;
    _markDirty();
  }

  void toggleFlipHorizontal() { flipHorizontal.value = !flipHorizontal.value; _markDirty(); }
  void toggleFlipVertical()   { flipVertical.value   = !flipVertical.value;   _markDirty(); }

  // ── Filter ───────────────────────────────────────────────────

  void applyFilter(PhotoFilter filter) {
    activeFilter.value = filter;
    _markDirty();
  }

  // ── AI Tools ─────────────────────────────────────────────────

  Future<void> autoEnhance() async {
    final item = mediaItem.value;
    if (item == null || item.isVideo) return;

    isProcessing.value = true;
    try {
      _pushUndo();
      final enhanced = await _aiService.autoEnhance(item.id);
      editedBytes.value = enhanced;
      _markDirty();
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> applyBackgroundBlur(double radius) async {
    final item = mediaItem.value;
    if (item == null || item.isVideo) return;

    isProcessing.value = true;
    try {
      _pushUndo();
      final blurred = await _aiService.applyBackgroundBlur(
        imagePath: item.id,
        blurRadius: radius,
      );
      editedBytes.value = blurred;
      _markDirty();
    } finally {
      isProcessing.value = false;
    }
  }

  // ── Video controls ───────────────────────────────────────────

  void setTrimStart(double seconds) { trimStart.value = seconds; _markDirty(); }
  void setTrimEnd(double seconds)   { trimEnd.value   = seconds; _markDirty(); }
  void toggleMute()                 { isMuted.value   = !isMuted.value; _markDirty(); }

  // ── Undo ─────────────────────────────────────────────────────

  void undo() {
    if (_undoStack.isEmpty) return;
    editedBytes.value = _undoStack.removeLast();
    hasUnsavedChanges.value = _undoStack.isNotEmpty;
  }

  bool get canUndo => _undoStack.isNotEmpty;

  // ── Save ─────────────────────────────────────────────────────

  Future<void> saveEdit() async {
    isProcessing.value = true;
    try {
      // Apply all pending adjustments to produce final bytes
      // Then save via ImageGallerySaver.saveImage(bytes)
      // Implementation depends on image_editor_plus or custom pipeline
      hasUnsavedChanges.value = false;
      Get.back(result: true); // Return true = saved
    } finally {
      isProcessing.value = false;
    }
  }

  void discardEdit() {
    if (hasUnsavedChanges.value) {
      // Show confirmation dialog in view layer
      return;
    }
    Get.back(result: false);
  }

  // ── Reset all adjustments to default ────────────────────────

  void resetAll() {
    brightness.value  = 0;
    contrast.value    = 0;
    saturation.value  = 0;
    warmth.value      = 0;
    exposure.value    = 0;
    shadows.value     = 0;
    highlights.value  = 0;
    straighten.value  = 0;
    rotationDegrees.value = 0;
    flipHorizontal.value  = false;
    flipVertical.value    = false;
    activeFilter.value    = PhotoFilter.none;
    editedBytes.value     = null;
    _undoStack.clear();
    hasUnsavedChanges.value = false;
  }

  // ── Private helpers ─────────────────────────────────────────

  void _markDirty() => hasUnsavedChanges.value = true;

  void _pushUndo() {
    final current = editedBytes.value;
    if (current != null) {
      _undoStack.add(current);
      if (_undoStack.length > _maxUndoSteps) {
        _undoStack.removeAt(0); // Drop oldest step
      }
    }
  }
}