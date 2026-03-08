
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/theme/theme.dart';
import 'controllers/editor_controller.dart';

class EditorView extends GetView<EditorController> {
  const EditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (controller.hasUnsavedChanges.value) {
          return await _showDiscardDialog(context) ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Edit'),
          actions: [
            // Undo
            Obx(() => IconButton(
              icon: const Icon(Icons.undo),
              onPressed: controller.canUndo ? controller.undo : null,
              color: controller.canUndo ? Colors.white : Colors.grey,
            )),
            // Save
            Obx(() => TextButton(
              onPressed: controller.hasUnsavedChanges.value
                  ? controller.saveEdit
                  : null,
              child: Text(
                'Save',
                style: TextStyle(
                  color: controller.hasUnsavedChanges.value
                      ? AppColors.accent
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )),
          ],
        ),
        body: Column(
          children: [
            // ── Preview area ─────────────────────────────────
            Expanded(child: _PreviewArea(controller: controller)),

            // ── Processing indicator ─────────────────────────
            Obx(() => controller.isProcessing.value
                ? const LinearProgressIndicator(
              backgroundColor: Colors.black,
              color: AppColors.accent,
            )
                : const SizedBox.shrink()),

            // ── Editing tools ────────────────────────────────
            Container(
              color: const Color(0xFF1A1A1A),
              child: Obx(() {
                final item = controller.mediaItem.value;
                if (item == null) return const SizedBox.shrink();
                return DefaultTabController(
                  length: item.isVideo ? 5 : 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelColor: AppColors.accent,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.accent,
                        tabs: [
                          const Tab(text: 'Adjust'),
                          const Tab(text: 'Crop'),
                          const Tab(text: 'Filters'),
                          const Tab(text: 'AI'),
                          if (item.isVideo) const Tab(text: 'Video'),
                        ],
                      ),
                      SizedBox(
                        height: 160,
                        child: TabBarView(
                          children: [
                            _AdjustPanel(controller: controller),
                            _CropPanel(controller: controller),
                            _FiltersPanel(controller: controller),
                            _AiPanel(controller: controller),
                            if (item.isVideo)
                              _VideoPanel(controller: controller),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDiscardDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Keep editing')),
          TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Discard',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// ── Preview ─────────────────────────────────────────────────
class _PreviewArea extends StatelessWidget {
  final EditorController controller;
  const _PreviewArea({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bytes = controller.editedBytes.value;
      final item = controller.mediaItem.value;
      if (item == null) return const SizedBox.shrink();

      return Center(
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.contain)
            : FutureBuilder(
          future: _loadOriginal(item.id),
          builder: (_, snap) => snap.hasData
              ? Image.memory(snap.data!, fit: BoxFit.contain)
              : const CircularProgressIndicator(color: Colors.white),
        ),
      );
    });
  }

  Future<dynamic> _loadOriginal(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    return asset?.originBytes;
  }
}

// ── Adjust panel ─────────────────────────────────────────────
class _AdjustPanel extends StatelessWidget {
  final EditorController controller;
  const _AdjustPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _Slider('Brightness', controller.brightness, controller.setBrightness),
        _Slider('Contrast',   controller.contrast,   controller.setContrast),
        _Slider('Saturation', controller.saturation, controller.setSaturation),
        _Slider('Warmth',     controller.warmth,     controller.setWarmth),
        _Slider('Exposure',   controller.exposure,   controller.setExposure),
        _Slider('Shadows',    controller.shadows,    controller.setShadows),
        _Slider('Highlights', controller.highlights, controller.setHighlights),
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  final String label;
  final RxDouble value;
  final void Function(double) onChanged;
  const _Slider(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
          Obx(() => Slider(
            value: value.value,
            min: -1,
            max: 1,
            activeColor: AppColors.accent,
            onChanged: onChanged,
          )),
          Obx(() => Text(
            value.value.toStringAsFixed(2),
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          )),
        ],
      ),
    );
  }
}

// ── Crop panel ──────────────────────────────────────────────
class _CropPanel extends StatelessWidget {
  final EditorController controller;
  const _CropPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CropAction(Icons.rotate_left,  'Rotate L', controller.rotateCounterClockwise),
        _CropAction(Icons.rotate_right, 'Rotate R', controller.rotateClockwise),
        _CropAction(Icons.flip,         'Flip H',   controller.toggleFlipHorizontal),
        _CropAction(Icons.flip,         'Flip V',   controller.toggleFlipVertical),
      ],
    );
  }
}

class _CropAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CropAction(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Filters panel ───────────────────────────────────────────
class _FiltersPanel extends StatelessWidget {
  final EditorController controller;
  const _FiltersPanel({required this.controller});

  static const _filters = [
    (PhotoFilter.none,   'Original'),
    (PhotoFilter.vivid,  'Vivid'),
    (PhotoFilter.warm,   'Warm'),
    (PhotoFilter.cool,   'Cool'),
    (PhotoFilter.bw,     'B&W'),
    (PhotoFilter.fade,   'Fade'),
    (PhotoFilter.chrome, 'Chrome'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: _filters.map((f) {
        return Obx(() {
          final isActive = controller.activeFilter.value == f.$1;
          return GestureDetector(
            onTap: () => controller.applyFilter(f.$1),
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade800,
                      border: isActive
                          ? Border.all(color: AppColors.accent, width: 2)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(f.$2,
                      style: TextStyle(
                          color: isActive ? AppColors.accent : Colors.white,
                          fontSize: 11)),
                ],
              ),
            ),
          );
        });
      }).toList(),
    );
  }
}

// ── AI tools panel ──────────────────────────────────────────
class _AiPanel extends StatelessWidget {
  final EditorController controller;
  const _AiPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // _AiTool(Icons.auto_fix_high,  'Auto\nEnhance', controller.autoEnhance),
        // _AiTool(Icons.blur_on,        'BG\nBlur',      () => controller.applyBackgroundBlur(15)),
        _AiTool(Icons.auto_fix_normal,'Erase\nObject', () {}),
      ],
    );
  }
}

class _AiTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AiTool(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Video trim panel ─────────────────────────────────────────
class _VideoPanel extends StatelessWidget {
  final EditorController controller;
  const _VideoPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final totalDuration =
        controller.mediaItem.value?.duration.inSeconds.toDouble() ?? 60;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Trim start
          Obx(() => Row(
            children: [
              const Text('Start ', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: controller.trimStart.value,
                  min: 0,
                  max: controller.trimEnd.value,
                  activeColor: AppColors.accent,
                  onChanged: controller.setTrimStart,
                ),
              ),
              Text(
                _fmtSecs(controller.trimStart.value),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          )),
          // Trim end
          Obx(() => Row(
            children: [
              const Text('End   ', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: controller.trimEnd.value,
                  min: controller.trimStart.value,
                  max: totalDuration,
                  activeColor: AppColors.accent,
                  onChanged: controller.setTrimEnd,
                ),
              ),
              Text(
                _fmtSecs(controller.trimEnd.value),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          )),
          // Mute toggle
          Obx(() => Row(
            children: [
              const Icon(Icons.volume_up, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Audio', style: TextStyle(color: Colors.white)),
              const Spacer(),
              Switch(
                value: !controller.isMuted.value,
                activeColor: AppColors.accent,
                onChanged: (_) => controller.toggleMute(),
              ),
            ],
          )),
        ],
      ),
    );
  }

  String _fmtSecs(double s) {
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
