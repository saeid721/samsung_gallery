import 'dart:io';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Manages video thumbnail playback to prevent performance issues
class VideoThumbnailManager extends GetxController {
  static const int maxActiveVideos = 3; // Limit concurrent video playback

  final Map<String, VideoPlayerController> _controllers = {};
  final Set<String> _activeVideos = {};

  /// Get or create a video controller for a thumbnail
  VideoPlayerController? getController(String assetId, Future<String?> Function() filePathGetter) {
    if (_controllers.containsKey(assetId)) {
      return _controllers[assetId];
    }

    // Create new controller
    _controllers[assetId] = VideoPlayerController.asset('') // Placeholder
      ..setVolume(0.0)
      ..setLooping(true);

    // Initialize with file path
    filePathGetter().then((filePath) {
      if (filePath != null && _controllers.containsKey(assetId)) {
        final controller = _controllers[assetId]!;
        controller.dispose(); // Dispose placeholder
        _controllers[assetId] = VideoPlayerController.file(File(filePath))
          ..setVolume(0.0)
          ..setLooping(true)
          ..initialize().then((_) {
            // Auto-play if within active limit
            if (_activeVideos.length < maxActiveVideos) {
              _activateVideo(assetId);
            }
          });
      }
    });

    return _controllers[assetId];
  }

  /// Activate video playback (start playing)
  void activateVideo(String assetId) {
    if (_controllers.containsKey(assetId) && !_activeVideos.contains(assetId)) {
      // Deactivate oldest video if at limit
      if (_activeVideos.length >= maxActiveVideos) {
        final oldestId = _activeVideos.first;
        _deactivateVideo(oldestId);
      }

      _activateVideo(assetId);
    }
  }

  /// Deactivate video playback (pause)
  void deactivateVideo(String assetId) {
    if (_activeVideos.contains(assetId)) {
      _deactivateVideo(assetId);
    }
  }

  void _activateVideo(String assetId) {
    if (_controllers.containsKey(assetId)) {
      _controllers[assetId]?.play();
      _activeVideos.add(assetId);
    }
  }

  void _deactivateVideo(String assetId) {
    if (_controllers.containsKey(assetId)) {
      _controllers[assetId]?.pause();
      _activeVideos.remove(assetId);
    }
  }

  /// Clean up all controllers
  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _activeVideos.clear();
  }

  /// Get active video count for debugging
  int get activeVideoCount => _activeVideos.length;
  Set<String> get activeVideoIds => Set.from(_activeVideos);
}
