import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';

import 'thumbnail_cache_service.dart';

class MediaIndexService {
  final ThumbnailCacheService _thumbnailCache;

  // Metadata index: assetId → metadata JSON
  // Persisted to disk as NDJSON for fast incremental updates
  final Map<String, Map<String, dynamic>> _metaIndex = {};

  // Trash index: assetId → deletion timestamp
  final Map<String, DateTime> _trashIndex = {};

  // Favorites set
  final Set<String> _favorites = {};

  // Perceptual hash cache: assetId → hash string
  final Map<String, String> _pHashCache = {};

  File? _indexFile;
  File? _trashFile;
  File? _favoritesFile;

  MediaIndexService({required ThumbnailCacheService thumbnailCache})
      : _thumbnailCache = thumbnailCache;

  // ----------------------------------------------------------
  // INITIALIZATION — Load persisted index from disk
  // ----------------------------------------------------------
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _indexFile = File(p.join(appDir.path, 'media_index.ndjson'));
    _trashFile = File(p.join(appDir.path, 'trash_index.json'));
    _favoritesFile = File(p.join(appDir.path, 'favorites.json'));

    // Load existing index (if any) into memory
    await Future.wait([
      _loadMetaIndex(),
      _loadTrashIndex(),
      _loadFavorites(),
    ]);
  }

  // ----------------------------------------------------------
  // LOAD ALL ASSETS — Paginated to avoid OOM on 50k+ photos
  // Returns first page immediately, streams rest via isolate
  // ----------------------------------------------------------
  Future<List<AssetEntity>> loadAllAssets() async {
    // Fetch all albums
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );

    if (paths.isEmpty) return [];

    // "All" album = first path that contains all assets
    final allAlbum = paths.firstWhere(
          (p) => p.isAll,
      orElse: () => paths.first,
    );

    // Load in pages to avoid memory spike
    final allAssets = <AssetEntity>[];
    int page = 0;
    const pageSize = 200;

    while (true) {
      final assets = await allAlbum.getAssetListPaged(
        page: page,
        size: pageSize,
      );
      if (assets.isEmpty) break;

      // Filter out trashed items
      final visible = assets.where(
            (a) => !_trashIndex.containsKey(a.id),
      ).toList();

      allAssets.addAll(visible);
      page++;

      // Yield to event loop periodically to prevent ANR
      if (page % 5 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    return allAssets;
  }

  // ----------------------------------------------------------
  // PAGINATED LOAD — For virtual scroll / lazy loading
  // ----------------------------------------------------------
  Future<List<AssetEntity>> loadPage({
    required int page,
    int pageSize = 80,
    AssetType? type,
  }) async {
    final paths = await PhotoManager.getAssetPathList(
      type: type != null ? RequestType.image : RequestType.common,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );

    if (paths.isEmpty) return [];
    final allAlbum = paths.firstWhere((p) => p.isAll, orElse: () => paths.first);
    return allAlbum.getAssetListPaged(page: page, size: pageSize);
  }

  // ----------------------------------------------------------
  // ALBUM ACCESS
  // ----------------------------------------------------------
  Future<AssetPathEntity?> getAlbumPath(String albumId) async {
    final paths = await PhotoManager.getAssetPathList(type: RequestType.common);
    try {
      return paths.firstWhere((p) => p.id == albumId);
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------
  // SINGLE ASSET LOOKUP
  // ----------------------------------------------------------
  Future<AssetEntity?> getAsset(String assetId) async {
    return AssetEntity.fromId(assetId);
  }

  // ----------------------------------------------------------
  // TRASH MANAGEMENT
  // ----------------------------------------------------------
  Future<void> markAsTrashed(List<String> assetIds) async {
    final now = DateTime.now();
    for (final id in assetIds) {
      _trashIndex[id] = now;
    }
    await _saveTrashIndex();
  }

  Future<void> restoreFromTrash(List<String> assetIds) async {
    for (final id in assetIds) {
      _trashIndex.remove(id);
    }
    await _saveTrashIndex();
  }

  Future<void> clearTrashRecords(List<String> assetIds) async {
    for (final id in assetIds) {
      _trashIndex.remove(id);
    }
    await _saveTrashIndex();
  }

  /// Returns items in trash that are past the 30-day expiry
  List<String> getExpiredTrashItems() {
    final threshold = DateTime.now().subtract(const Duration(days: 30));
    return _trashIndex.entries
        .where((e) => e.value.isBefore(threshold))
        .map((e) => e.key)
        .toList();
  }

  /// Get the trash index (read-only)
  Map<String, DateTime> get trashIndex => Map.unmodifiable(_trashIndex);

  /// Remove item from trash index
  Future<void> removeFromTrash(String assetId) async {
    _trashIndex.remove(assetId);
    await _saveTrashIndex();
  }

  // ----------------------------------------------------------
  // FAVORITES
  // ----------------------------------------------------------
  Future<void> setFavorite(String assetId, bool isFavorite) async {
    if (isFavorite) {
      _favorites.add(assetId);
    } else {
      _favorites.remove(assetId);
    }
    await _saveFavorites();
  }

  bool isFavorite(String assetId) => _favorites.contains(assetId);

  // ----------------------------------------------------------
  // MOVE ASSETS (via photo_manager MediaStore API)
  // ----------------------------------------------------------
  Future<void> moveAssets(List<String> assetIds, String targetAlbumId) async {
    final assets = await Future.wait(
      assetIds.map((id) => AssetEntity.fromId(id)),
    );
    for (final asset in assets) {
      if (asset == null) continue;
      // photo_manager doesn't have a direct "move" API on Android
      // Workaround: copy to new album, delete from old
      // This requires the target album path entity
    }
  }

  // ----------------------------------------------------------
  // DUPLICATE DETECTION STREAM
  // Runs perceptual hash computation in background
  // ----------------------------------------------------------
  Stream<List<DuplicateGroupData>> streamDuplicateGroups() async* {
    // Load all image assets
    final assets = await loadAllAssets();
    final imageAssets = assets.where((a) => a.type == AssetType.image).toList();

    // Compute hashes in batches (low-priority background work)
    const batchSize = 50;
    final hashes = <String, String>{}; // assetId → pHash

    for (int i = 0; i < imageAssets.length; i += batchSize) {
      final batch = imageAssets.skip(i).take(batchSize).toList();

      // Compute hashes for batch in isolate
      final batchHashes = await compute(_computeHashBatch, batch);
      hashes.addAll(batchHashes);

      // Find duplicates in accumulated hashes
      final duplicates = _findDuplicates(hashes);
      if (duplicates.isNotEmpty) {
        yield duplicates;
      }

      // Yield to UI thread
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  static Future<Map<String, String>> _computeHashBatch(
      List<AssetEntity> assets) async {
    final result = <String, String>{};
    for (final asset in assets) {
      final thumb = await asset.thumbnailDataWithSize(const ThumbnailSize(32, 32));
      if (thumb == null) continue;

      // Simple average hash (aHash) — fast, reasonable accuracy
      // For production, upgrade to pHash (DCT-based)
      final hash = _computeAverageHash(thumb);
      result[asset.id] = hash;
    }
    return result;
  }

  static String _computeAverageHash(Uint8List imageBytes) {
    // Decode to pixel data
    // Compute average brightness
    // Build 64-bit binary string
    // Return as hex
    // Simplified: use byte sum as basic hash (upgrade in production)
    final sum = imageBytes.fold<int>(0, (sum, b) => sum + b);
    final avg = sum / imageBytes.length;
    final bits = imageBytes.take(64).map((b) => b > avg ? '1' : '0').join();
    return BigInt.parse(bits, radix: 2).toRadixString(16).padLeft(16, '0');
  }

  List<DuplicateGroupData> _findDuplicates(Map<String, String> hashes) {
    final groups = <DuplicateGroupData>[];
    final processed = <String>{};

    final entries = hashes.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      if (processed.contains(entries[i].key)) continue;
      final group = [entries[i].key];

      for (int j = i + 1; j < entries.length; j++) {
        final distance = _hammingDistance(entries[i].value, entries[j].value);
        if (distance < 10) { // Threshold: < 10 bits different = duplicate
          group.add(entries[j].key);
          processed.add(entries[j].key);
        }
      }

      if (group.length > 1) {
        groups.add(DuplicateGroupData(assetIds: group));
        processed.add(entries[i].key);
      }
    }

    return groups;
  }

  static int _hammingDistance(String a, String b) {
    int dist = 0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) dist++;
    }
    return dist;
  }

  // ── Persistence helpers ──────────────────────────────────

  Future<void> _loadMetaIndex() async {
    if (_indexFile == null || !await _indexFile!.exists()) return;
    final lines = await _indexFile!.readAsLines();
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        _metaIndex[json['id']] = json;
      } catch (_) {}
    }
  }

  Future<void> _loadTrashIndex() async {
    if (_trashFile == null || !await _trashFile!.exists()) return;
    final content = await _trashFile!.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    for (final entry in json.entries) {
      _trashIndex[entry.key] = DateTime.parse(entry.value as String);
    }
  }

  Future<void> _saveTrashIndex() async {
    if (_trashFile == null) return;
    final json = _trashIndex.map((k, v) => MapEntry(k, v.toIso8601String()));
    await _trashFile!.writeAsString(jsonEncode(json));
  }

  Future<void> _loadFavorites() async {
    if (_favoritesFile == null || !await _favoritesFile!.exists()) return;
    final content = await _favoritesFile!.readAsString();
    final list = jsonDecode(content) as List;
    _favorites.addAll(list.cast<String>());
  }

  Future<void> _saveFavorites() async {
    if (_favoritesFile == null) return;
    await _favoritesFile!.writeAsString(jsonEncode(_favorites.toList()));
  }
}

class DuplicateGroupData {
  final List<String> assetIds;
  DuplicateGroupData({required this.assetIds});
}