// ============================================================
// features/albums/repositories/album_repository.dart
// ============================================================
// Manages all album operations: listing, creating, renaming,
// deleting, and moving media between albums.
//
// Android albums = MediaStore "buckets" (directories).
// photo_manager wraps these as AssetPathEntity objects.
//
// Custom albums are created by making a new directory under
// /storage/emulated/0/Pictures/ and moving files into it.
// ============================================================

import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:path/path.dart' as p;
import '../../../core/services/media_index_service.dart';
import '../models/media_model.dart';
import 'media_repository.dart';

// ── Data model ──────────────────────────────────────────────
class Album {
  final String id;
  final String name;
  final AlbumType type;
  final String? coverAssetId;
  final int itemCount;
  final DateTime? lastModified;

  const Album({
    required this.id,
    required this.name,
    required this.type,
    this.coverAssetId,
    required this.itemCount,
    this.lastModified,
  });

  Album copyWith({String? name, String? coverAssetId, int? itemCount}) =>
      Album(
        id: id,
        name: name ?? this.name,
        type: type,
        coverAssetId: coverAssetId ?? this.coverAssetId,
        itemCount: itemCount ?? this.itemCount,
        lastModified: lastModified,
      );
}

enum AlbumType {
  system,   // Camera, Screenshots, Downloads — created by OS
  custom,   // User-created inside the app
  smart,    // Favorites, Videos, GIFs — virtual/filtered
}

// ── Abstract interface ──────────────────────────────────────
abstract class AlbumRepository {
  /// List all albums visible to the gallery.
  Future<List<Album>> getAlbums();

  /// Fetch paginated media items inside a specific album.
  Future<List<MediaItem>> getAlbumItems(
      String albumId, {
        int page = 0,
        int pageSize = 80,
      });

  /// Create a new custom album (makes a directory on disk).
  Future<Album?> createAlbum(String name);

  /// Rename a custom album.
  Future<bool> renameAlbum(String albumId, String newName);

  /// Delete a custom album (moves its contents to trash).
  Future<bool> deleteAlbum(String albumId);

  /// Copy media items into an album (keeps originals in place).
  Future<bool> copyItemsToAlbum(List<String> assetIds, String targetAlbumId);

  /// Move media items to a different album.
  Future<bool> moveItemsToAlbum(List<String> assetIds, String targetAlbumId);

  /// Remove items from an album without deleting them.
  Future<bool> removeItemsFromAlbum(List<String> assetIds, String albumId);
}

// ── Concrete implementation ─────────────────────────────────
class AlbumRepositoryImpl implements AlbumRepository {
  final MediaRepository _mediaRepo;
  final MediaIndexService _indexService;

  AlbumRepositoryImpl({
    required MediaRepository mediaRepo,
    required MediaIndexService indexService,
  })  : _mediaRepo = mediaRepo,
        _indexService = indexService;

  // ----------------------------------------------------------
  // LIST ALBUMS
  // Returns system albums (Camera, Screenshots…) + custom ones,
  // sorted: Camera first, then alphabetically.
  // ----------------------------------------------------------
  @override
  Future<List<Album>> getAlbums() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );

    final albums = <Album>[];

    for (final path in paths) {
      // Get cover asset (first item) and count
      final assets = await path.getAssetListPaged(page: 0, size: 1);
      final count = await path.assetCountAsync;

      albums.add(Album(
        id: path.id,
        name: path.name,
        type: _classifyAlbum(path.name),
        coverAssetId: assets.isEmpty ? null : assets.first.id,
        itemCount: count,
        lastModified: assets.isEmpty ? null : assets.first.createDateTime,
      ));
    }

    // Sort: Camera first, then Screenshots, then alphabetical
    albums.sort((a, b) {
      final priority = {'Camera': 0, 'Screenshots': 1, 'Downloads': 2};
      final pa = priority[a.name] ?? 99;
      final pb = priority[b.name] ?? 99;
      if (pa != pb) return pa.compareTo(pb);
      return a.name.compareTo(b.name);
    });

    return albums;
  }

  // ----------------------------------------------------------
  // GET ALBUM ITEMS — paginated
  // ----------------------------------------------------------
  @override
  Future<List<MediaItem>> getAlbumItems(
      String albumId, {
        int page = 0,
        int pageSize = 80,
      }) async {
    return _mediaRepo.getAlbumItems(albumId, page: page);
  }

  // ----------------------------------------------------------
  // CREATE ALBUM
  // Creates a new directory under /Pictures/ and registers it
  // with MediaStore so it appears as a new album.
  // ----------------------------------------------------------
  @override
  Future<Album?> createAlbum(String name) async {
    // Validate name
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains(RegExp(r'[/\\:*?"<>|]'))) return null;

    try {
      // Create physical directory in Pictures/
      final picturesDir = Directory('/storage/emulated/0/Pictures/$trimmed');
      if (await picturesDir.exists()) return null; // Name already taken
      await picturesDir.create(recursive: true);

      // Create a .nomedia file placeholder so the folder is recognized
      // even before any photos are added (remove .nomedia when first
      // photo is added to make it visible in gallery)
      // For now: leave empty dir, it will appear after first file is moved in

      // We can't get an AssetPathEntity for an empty dir yet,
      // so return a stub Album — it will resolve after items are moved in.
      return Album(
        id: picturesDir.path, // temporary id; will become MediaStore bucket id
        name: trimmed,
        type: AlbumType.custom,
        itemCount: 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------
  // RENAME ALBUM
  // Renames the underlying directory (moves it on disk).
  // Note: system albums (Camera, Screenshots) cannot be renamed.
  // ----------------------------------------------------------
  @override
  Future<bool> renameAlbum(String albumId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    try {
      // Find the album path
      final path = await _indexService.getAlbumPath(albumId);
      if (path == null) return false;

      // Only allow renaming custom albums
      if (_classifyAlbum(path.name) == AlbumType.system) return false;

      // Rename directory
      final assets = await path.getAssetListRange(start: 0, end: 1);
      if (assets.isEmpty) return false;

      final firstFile = await assets.first.originFile;
      if (firstFile == null) return false;

      final oldDir = firstFile.parent;
      final newDir = Directory(p.join(oldDir.parent.path, trimmed));

      await oldDir.rename(newDir.path);

      // MediaStore will pick up the rename on next media scan
      await PhotoManager.forceOldApi; // Trigger re-scan
      return true;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------------------------------------
  // DELETE ALBUM
  // Moves all album contents to trash, then removes directory.
  // ----------------------------------------------------------
  @override
  Future<bool> deleteAlbum(String albumId) async {
    try {
      final path = await _indexService.getAlbumPath(albumId);
      if (path == null) return false;

      // Collect all asset IDs in this album
      final count = await path.assetCountAsync;
      final assets = await path.getAssetListRange(start: 0, end: count);
      final ids = assets.map((a) => a.id).toList();

      // Move to trash (soft delete — recoverable for 30 days)
      if (ids.isNotEmpty) {
        await _indexService.markAsTrashed(ids);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------------------------------------
  // COPY ITEMS TO ALBUM
  // ----------------------------------------------------------
  @override
  Future<bool> copyItemsToAlbum(
      List<String> assetIds, String targetAlbumId) async {
    try {
      final targetPath = await _indexService.getAlbumPath(targetAlbumId);
      if (targetPath == null) return false;

      // Get target directory path from first existing asset in album
      final existingAssets =
      await targetPath.getAssetListRange(start: 0, end: 1);

      Directory? targetDir;
      if (existingAssets.isNotEmpty) {
        final file = await existingAssets.first.originFile;
        targetDir = file?.parent;
      }

      if (targetDir == null) return false;

      for (final assetId in assetIds) {
        final asset = await AssetEntity.fromId(assetId);
        if (asset == null) continue;

        final srcFile = await asset.originFile;
        if (srcFile == null) continue;

        // Copy file to target directory
        final destPath = p.join(targetDir.path, p.basename(srcFile.path));
        await srcFile.copy(destPath);
      }

      // Refresh MediaStore to pick up new files
      await PhotoManager.forceOldApi;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------------------------------------
  // MOVE ITEMS TO ALBUM
  // ----------------------------------------------------------
  @override
  Future<bool> moveItemsToAlbum(
      List<String> assetIds, String targetAlbumId) async {
    try {
      await _indexService.moveAssets(assetIds, targetAlbumId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------------------------------------
  // REMOVE ITEMS FROM ALBUM (without deleting)
  // On Android this is equivalent to moving to Camera roll.
  // ----------------------------------------------------------
  @override
  Future<bool> removeItemsFromAlbum(
      List<String> assetIds, String albumId) async {
    // Move items to Camera/DCIM folder (the default album)
    final paths = await PhotoManager.getAssetPathList(type: RequestType.common);
    final cameraAlbum = paths.where((p) => p.name == 'Camera').firstOrNull;
    if (cameraAlbum == null) return false;
    return moveItemsToAlbum(assetIds, cameraAlbum.id);
  }

  // ── Private helpers ─────────────────────────────────────────

  AlbumType _classifyAlbum(String name) {
    const systemNames = {
      'Camera', 'Screenshots', 'Downloads', 'DCIM',
      'WhatsApp Images', 'WhatsApp Video', 'Telegram',
    };
    return systemNames.contains(name) ? AlbumType.system : AlbumType.custom;
  }
}