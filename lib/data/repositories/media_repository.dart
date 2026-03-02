import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../../../core/services/media_index_service.dart';
import '../../../core/services/exif_service.dart';
import '../models/media_model.dart' hide TimelineGroup;
import '../models/timeline_group.dart';

/// ─────────────────────────────────────────────────────────────
/// ABSTRACT REPOSITORY
/// ─────────────────────────────────────────────────────────────
abstract class MediaRepository {
  Future<bool> requestPermission();
  Stream<List<TimelineGroup>> getTimelineStream();

  Future<List<MediaItem>> getMediaPage({
    required int page,
    int pageSize = 80,
    MediaFilter? filter,
  });

  Future<List<AlbumInfo>> getAlbums();
  Future<List<MediaItem>> getAlbumItems(String albumId, {int page = 0});

  Future<void> trashItems(List<String> assetIds);
  Future<void> deleteFromTrash(List<String> assetIds);
  Future<void> restoreFromTrash(List<String> assetIds);

  Future<void> toggleFavorite(String assetId, bool isFavorite);
  Future<void> moveItems(List<String> assetIds, String targetAlbumId);

  Future<List<MediaItem>> search(SearchQuery query);
  Stream<List<DuplicateGroup>> findDuplicates();
}

/// ─────────────────────────────────────────────────────────────
/// IMPLEMENTATION
/// ─────────────────────────────────────────────────────────────
class MediaRepositoryImpl implements MediaRepository {
  final MediaIndexService _indexService;
  final ExifService _exifService;

  final Map<String, MediaItem> _cache = {};

  MediaRepositoryImpl({
    required MediaIndexService indexService,
    required ExifService exifService,
  })  : _indexService = indexService,
        _exifService = exifService;

  /// ─────────────────────────────────────────────────────────
  /// PERMISSION
  /// ─────────────────────────────────────────────────────────
  @override
  Future<bool> requestPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth;
  }

  /// ─────────────────────────────────────────────────────────
  /// TIMELINE
  /// ─────────────────────────────────────────────────────────
  @override
  Stream<List<TimelineGroup>> getTimelineStream() async* {
    if (_cache.isNotEmpty) {
      yield _buildTimeline(_cache.values.toList());
    }

    final allAssets = await _indexService.loadAllAssets();

    final items =
    await Future.wait(allAssets.map((asset) => _toMediaItem(asset)));

    for (final item in items) {
      _cache[item.id] = item;
    }

    yield _buildTimeline(items);
  }

  /// ─────────────────────────────────────────────────────────
  /// PAGINATION
  /// ─────────────────────────────────────────────────────────
  @override
  Future<List<MediaItem>> getMediaPage({
    required int page,
    int pageSize = 80,
    MediaFilter? filter,
  }) async {
    final assets = await _indexService.loadPage(
      page: page,
      pageSize: pageSize,
      type: _mapMediaTypeToAssetType(filter?.type), // ✅ FIXED
    );

    return Future.wait(assets.map(_toMediaItem));
  }

  /// ─────────────────────────────────────────────────────────
  /// ALBUMS
  /// ─────────────────────────────────────────────────────────
  @override
  Future<List<AlbumInfo>> getAlbums() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );

    return Future.wait(paths.map((path) async {
      final count = await path.assetCountAsync;

      return AlbumInfo(
        id: path.id,
        name: path.name,
        coverAssetId: null,
        itemCount: count,
      );
    }));
  }

  @override
  Future<List<MediaItem>> getAlbumItems(String albumId,
      {int page = 0}) async {
    final path = await _indexService.getAlbumPath(albumId);
    if (path == null) return [];

    final assets =
    await path.getAssetListPaged(page: page, size: 80);

    return Future.wait(assets.map(_toMediaItem));
  }

  /// ─────────────────────────────────────────────────────────
  /// TRASH
  /// ─────────────────────────────────────────────────────────
  @override
  Future<void> trashItems(List<String> assetIds) async {
    await _indexService.markAsTrashed(assetIds);
    for (final id in assetIds) {
      _cache.remove(id);
    }
  }

  @override
  Future<void> deleteFromTrash(List<String> assetIds) async {
    await PhotoManager.editor.deleteWithIds(assetIds);
    await _indexService.clearTrashRecords(assetIds);
  }

  @override
  Future<void> restoreFromTrash(List<String> assetIds) async {
    await _indexService.restoreFromTrash(assetIds);
  }

  /// ─────────────────────────────────────────────────────────
  /// FAVORITE (Cross-platform safe)
  /// ─────────────────────────────────────────────────────────
  @override
  Future<void> toggleFavorite(String assetId, bool isFavorite) async {
    // ❌ photo_manager no longer exposes ios.favoriteAsset
    // So we manage favorites in local index (cross-platform safe)
    await _indexService.setFavorite(assetId, isFavorite);
    _cache[assetId]?.isFavorite.value = isFavorite;
  }

  /// ─────────────────────────────────────────────────────────
  /// MOVE
  /// ─────────────────────────────────────────────────────────
  @override
  Future<void> moveItems(
      List<String> assetIds, String targetAlbumId) async {
    await _indexService.moveAssets(assetIds, targetAlbumId);
  }

  /// ─────────────────────────────────────────────────────────
  /// SEARCH
  /// ─────────────────────────────────────────────────────────
  @override
  Future<List<MediaItem>> search(SearchQuery query) async {
    return _cache.values.where((item) {
      if (query.startDate != null &&
          item.createdAt.isBefore(query.startDate!)) {
        return false;
      }
      if (query.endDate != null &&
          item.createdAt.isAfter(query.endDate!)) {
        return false;
      }
      if (query.albumName != null &&
          !item.albumName
              .toLowerCase()
              .contains(query.albumName!.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  /// ─────────────────────────────────────────────────────────
  /// DUPLICATES
  /// ─────────────────────────────────────────────────────────
  @override
  @override
  Stream<List<DuplicateGroup>> findDuplicates() async* {
    final stream = _indexService.streamDuplicateGroups();

    await for (final groups in stream) {
      yield groups.map((g) {
        // Map each assetId in DuplicateGroupData to cached MediaItem if exists
        final items = <MediaItem>[];
        try {
          for (final id in g.assetIds) {
            final item = _cache[id];
            if (item != null) items.add(item);
          }
        } catch (_) {
          // ignore any unexpected errors
        }

        // similarity unknown → default to 0.0
        return DuplicateGroup(
          items: items,
          similarity: 0.0,
        );
      }).toList();
    }
  }

  /// ─────────────────────────────────────────────────────────
  /// PRIVATE HELPERS
  /// ─────────────────────────────────────────────────────────
  Future<MediaItem> _toMediaItem(AssetEntity asset) async {
    if (_cache.containsKey(asset.id)) return _cache[asset.id]!;

    ExifData? exif;

    if (asset.type == AssetType.image) {
      final file = await asset.originFile;
      if (file != null) {
        exif = await _exifService.readExif(file.path);
      }
    }

    final item = MediaItem(
      id: asset.id,
      type: asset.type == AssetType.video
          ? MediaType.video
          : MediaType.image,
      width: asset.width,
      height: asset.height,
      duration: asset.videoDuration,
      createdAt: asset.createDateTime,
      modifiedAt: asset.modifiedDateTime,
      albumName: asset.relativePath ?? '',
      mimeType: asset.mimeType ?? '',
      size: asset.size.width.toInt() ?? 0,
      latitude: exif?.latitude,
      longitude: exif?.longitude,
      isFavorite: RxBool(asset.isFavorite),
    );

    _cache[item.id] = item;
    return item;
  }

  AssetType? _mapMediaTypeToAssetType(MediaType? type) {
    if (type == null) return null;
    if (type == MediaType.image) return AssetType.image;
    if (type == MediaType.video) return AssetType.video;
    return null;
  }

  List<TimelineGroup> _buildTimeline(List<MediaItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final grouped =
    groupBy<MediaItem, String>(items, (item) {
      final d = DateTime(
          item.createdAt.year,
          item.createdAt.month,
          item.createdAt.day);

      if (d == today) return 'Today';
      if (d == yesterday) return 'Yesterday';
      if (d.isAfter(lastWeek)) return 'Last 7 Days';
      return DateFormat('MMMM yyyy').format(item.createdAt);
    });

    return grouped.entries
        .map((e) =>
        TimelineGroup(label: e.key, items: e.value))
        .toList();
  }
}

/// ─────────────────────────────────────────────────────────
/// SUPPORT MODELS
/// ─────────────────────────────────────────────────────────
class MediaFilter {
  final MediaType? type;
  final DateTimeRange? dateRange;
  MediaFilter({this.type, this.dateRange});
}

class SearchQuery {
  final String? text;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? albumName;
  final String? location;

  SearchQuery({
    this.text,
    this.startDate,
    this.endDate,
    this.albumName,
    this.location,
  });
}

class AlbumInfo {
  final String id;
  final String name;
  final String? coverAssetId;
  final int itemCount;

  AlbumInfo({
    required this.id,
    required this.name,
    this.coverAssetId,
    required this.itemCount,
  });
}

class DuplicateGroup {
  final List<MediaItem> items;
  final double similarity;

  DuplicateGroup({
    required this.items,
    required this.similarity,
  });
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange({
    required this.start,
    required this.end,
  });
}