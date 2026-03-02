// features/gallery/models/media_item.dart
import 'package:get/get.dart';

enum MediaType { image, video, gif }

class MediaItem {
  final String id;
  final MediaType type;
  final int width;
  final int height;
  final Duration duration;       // Only for videos
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String albumName;
  final String mimeType;
  final int size;                // Bytes
  final double? latitude;
  final double? longitude;
  final RxBool isFavorite;       // Reactive — UI rebuilds on change
  final bool isSecure;
  final List<String> tags;

  MediaItem({
    required this.id,
    required this.type,
    required this.width,
    required this.height,
    required this.duration,
    required this.createdAt,
    required this.modifiedAt,
    required this.albumName,
    required this.mimeType,
    required this.size,
    this.latitude,
    this.longitude,
    required this.isFavorite,
    this.isSecure = false,
    this.tags = const [],
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get isVideo => type == MediaType.video;
  bool get isGif => mimeType == 'image/gif';
  bool get isPortrait => height > width;
  bool get isPanorama => width > height * 2.5;
  double get aspectRatio => width / height.clamp(1, double.infinity);
}

class TimelineGroup {
  final String label;
  final List<MediaItem> items;
  TimelineGroup({required this.label, required this.items});
}