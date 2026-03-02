// ============================================================
// core/services/thumbnail_cache_service.dart
// ============================================================
// Two-level thumbnail cache:
//   Level 1 — Memory: Flutter's ImageCache (200MB, process lifetime)
//   Level 2 — Disk:   App cache dir (500MB, 30 days TTL)
//
// Usage:
//   final bytes = await thumbnailCache.get(assetId, size: 256);
//   if (bytes == null) {
//     bytes = await generateThumbnail(assetId);
//     await thumbnailCache.put(assetId, bytes, size: 256);
//   }
// ============================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import '../config/app_config.dart';

class ThumbnailCacheService {
  Directory? _cacheDir;

  // ── Initialization ──────────────────────────────────────────
  Future<void> initialize() async {
    // Expand Flutter's in-memory image cache to 200MB
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        200 * 1024 * 1024; // 200 MB

    // Prepare disk cache directory
    final appCacheDir = await getTemporaryDirectory();
    _cacheDir = Directory(p.join(appCacheDir.path, 'thumbnails'));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    // Evict stale disk cache entries on startup (async, non-blocking)
    _evictStaleDiskCache();
  }

  // ── GET — returns cached thumbnail bytes, or null if miss ───
  Future<Uint8List?> get(String assetId, {int size = 256}) async {
    final file = _diskCacheFile(assetId, size);
    if (await file.exists()) {
      // Touch modification time so TTL resets on access
      await file.setLastModified(DateTime.now());
      return file.readAsBytes();
    }
    return null;
  }

  // ── PUT — saves thumbnail bytes to disk cache ───────────────
  Future<void> put(String assetId, Uint8List bytes, {int size = 256}) async {
    if (_cacheDir == null) await initialize();
    final file = _diskCacheFile(assetId, size);
    await file.writeAsBytes(bytes, flush: true);
    await _enforceDiskCacheLimit();
  }

  // ── GENERATE + CACHE — convenience method ──────────────────
  /// Fetches thumbnail from photo_manager, caches it, returns bytes.
  Future<Uint8List?> getOrGenerate(String assetId, {int size = 256}) async {
    // 1. Check disk cache first
    final cached = await get(assetId, size: size);
    if (cached != null) return cached;

    // 2. Generate via photo_manager
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;

    final bytes = await asset.thumbnailDataWithSize(
      ThumbnailSize(size, size),
      format: ThumbnailFormat.jpeg,
      quality: 85,
    );
    if (bytes == null) return null;

    // 3. Persist to disk cache
    await put(assetId, bytes, size: size);
    return bytes;
  }

  // ── DELETE — remove single entry ───────────────────────────
  Future<void> evict(String assetId, {int? size}) async {
    if (size != null) {
      final file = _diskCacheFile(assetId, size);
      if (await file.exists()) await file.delete();
    } else {
      // Evict all sizes for this asset
      for (final s in [64, 128, 256, 512]) {
        final file = _diskCacheFile(assetId, s);
        if (await file.exists()) await file.delete();
      }
    }
  }

  // ── CLEAR ALL ───────────────────────────────────────────────
  Future<void> clearAll() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create();
    }
    PaintingBinding.instance.imageCache.clear();
  }

  // ── Returns current disk cache size in bytes ────────────────
  Future<int> diskCacheSize() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) return 0;
    int total = 0;
    await for (final entity in _cacheDir!.list(recursive: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  // ── Private helpers ─────────────────────────────────────────

  File _diskCacheFile(String assetId, int size) {
    // Sanitize assetId (may contain slashes on some devices)
    final safeId = assetId.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    return File(p.join(_cacheDir!.path, '${safeId}_$size.jpg'));
  }

  /// Evict disk cache entries older than 30 days (runs in background).
  Future<void> _evictStaleDiskCache() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    await for (final entity in _cacheDir!.list(recursive: false)) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    }
  }

  /// If disk cache exceeds 500MB, delete oldest files until under limit.
  Future<void> _enforceDiskCacheLimit() async {
    if (_cacheDir == null) return;

    // Collect all cache files with their sizes and mod times
    final files = <({File file, int size, DateTime modified})>[];
    await for (final entity in _cacheDir!.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        files.add((file: entity, size: stat.size, modified: stat.modified));
      }
    }

    // Calculate total size
    final total = files.fold<int>(0, (sum, f) => sum + f.size);
    if (total <= AppConfig.thumbnailCacheMaxBytes) return;

    // Sort oldest-first, delete until under limit
    files.sort((a, b) => a.modified.compareTo(b.modified));
    int remaining = total;
    for (final f in files) {
      if (remaining <= AppConfig.thumbnailCacheMaxBytes) break;
      await f.file.delete();
      remaining -= f.size;
    }
  }
}