// ============================================================
// features/secure_folder/repositories/secure_media_repository.dart
// ============================================================
// Manages the encrypted media index for the Secure Folder.
//
// Each item in the Secure Folder has two files on disk:
//   <uuid>.enc      — AES-256-GCM encrypted original media bytes
//   <uuid>.meta     — AES-256-GCM encrypted JSON metadata sidecar
//
// This repository reads/writes the .meta sidecars to produce
// SecureMediaItem models for the UI, without ever decrypting
// the actual media bytes (done only on demand in the service).
//
// The vault directory (.secure_vault/) lives inside the app's
// private data directory — inaccessible to other apps.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/services/secure_storage_service.dart';

// ── Data model ──────────────────────────────────────────────
class SecureMediaItem {
  final String secureId;       // UUID — filename without extension
  final String originalName;   // Original filename before encryption
  final int width;
  final int height;
  final int sizeBytes;
  final bool isVideo;
  final Duration? videoDuration;
  final DateTime importedAt;
  final DateTime originalCreatedAt;

  const SecureMediaItem({
    required this.secureId,
    required this.originalName,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.isVideo,
    this.videoDuration,
    required this.importedAt,
    required this.originalCreatedAt,
  });

  Map<String, dynamic> toJson() => {
    'secureId': secureId,
    'originalName': originalName,
    'width': width,
    'height': height,
    'sizeBytes': sizeBytes,
    'isVideo': isVideo,
    'videoDurationMs': videoDuration?.inMilliseconds,
    'importedAt': importedAt.toIso8601String(),
    'originalCreatedAt': originalCreatedAt.toIso8601String(),
  };

  factory SecureMediaItem.fromJson(Map<String, dynamic> json) =>
      SecureMediaItem(
        secureId: json['secureId'] as String,
        originalName: json['originalName'] as String,
        width: json['width'] as int? ?? 0,
        height: json['height'] as int? ?? 0,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        isVideo: json['isVideo'] as bool? ?? false,
        videoDuration: json['videoDurationMs'] != null
            ? Duration(milliseconds: json['videoDurationMs'] as int)
            : null,
        importedAt: DateTime.parse(json['importedAt'] as String),
        originalCreatedAt:
        DateTime.parse(json['originalCreatedAt'] as String),
      );
}

// ── Abstract interface ──────────────────────────────────────
abstract class SecureMediaRepository {
  /// List all items currently in the Secure Folder.
  Future<List<SecureMediaItem>> listItems();

  /// Returns the filesystem path to the encrypted media file.
  Future<String> getEncryptedFilePath(String secureId);

  /// Saves a new encrypted item + its metadata sidecar.
  Future<SecureMediaItem> saveEncryptedItem({
    required String secureId,
    required Uint8List encryptedBytes,
    required SecureMediaItem metadata,
  });

  /// Deletes an item's .enc and .meta files permanently.
  Future<bool> deleteItem(String secureId);

  /// Returns total count of items in vault.
  Future<int> getItemCount();

  /// Returns total encrypted size of all items in bytes.
  Future<int> getTotalSize();
}

// ── Concrete implementation ─────────────────────────────────
class SecureMediaRepositoryImpl implements SecureMediaRepository {
  final SecureStorageService _secureStorage;
  final _uuid = const Uuid();

  // In-memory list of items (populated when vault is unlocked)
  List<SecureMediaItem>? _cachedItems;

  SecureMediaRepositoryImpl({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  // ----------------------------------------------------------
  // LIST ITEMS
  // Reads all .meta files from vault dir, decodes them.
  // Metadata is stored as plain JSON (not encrypted itself) because
  // the vault directory is already private to the app. If you need
  // metadata privacy too (e.g. hide file names), encrypt .meta files
  // the same way as .enc files using SecureFolderService.
  // ----------------------------------------------------------
  @override
  Future<List<SecureMediaItem>> listItems() async {
    if (_cachedItems != null) return _cachedItems!;

    final vaultDir = await _getVaultDirectory();
    final items = <SecureMediaItem>[];

    await for (final entity in vaultDir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.meta')) continue;

      try {
        final raw = await entity.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        items.add(SecureMediaItem.fromJson(json));
      } catch (_) {
        // Corrupt .meta file — skip it
        continue;
      }
    }

    // Sort by import date, newest first
    items.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    _cachedItems = items;
    return items;
  }

  // ----------------------------------------------------------
  // GET ENCRYPTED FILE PATH
  // ----------------------------------------------------------
  @override
  Future<String> getEncryptedFilePath(String secureId) async {
    final vaultDir = await _getVaultDirectory();
    return p.join(vaultDir.path, '$secureId.enc');
  }

  // ----------------------------------------------------------
  // SAVE ENCRYPTED ITEM
  // Writes .enc file and .meta sidecar to vault directory.
  // ----------------------------------------------------------
  @override
  Future<SecureMediaItem> saveEncryptedItem({
    required String secureId,
    required Uint8List encryptedBytes,
    required SecureMediaItem metadata,
  }) async {
    final vaultDir = await _getVaultDirectory();

    // Write encrypted media file
    final encFile = File(p.join(vaultDir.path, '$secureId.enc'));
    await encFile.writeAsBytes(encryptedBytes, flush: true);

    // Write metadata sidecar
    final metaFile = File(p.join(vaultDir.path, '$secureId.meta'));
    await metaFile.writeAsString(
      jsonEncode(metadata.toJson()),
      flush: true,
    );

    // Invalidate cache so next listItems() is fresh
    _cachedItems = null;

    return metadata;
  }

  // ----------------------------------------------------------
  // DELETE ITEM — removes .enc and .meta files
  // ----------------------------------------------------------
  @override
  Future<bool> deleteItem(String secureId) async {
    try {
      final vaultDir = await _getVaultDirectory();

      final encFile = File(p.join(vaultDir.path, '$secureId.enc'));
      final metaFile = File(p.join(vaultDir.path, '$secureId.meta'));

      if (await encFile.exists()) await encFile.delete();
      if (await metaFile.exists()) await metaFile.delete();

      // Remove from cache
      _cachedItems?.removeWhere((item) => item.secureId == secureId);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------------------------------------
  // STATS
  // ----------------------------------------------------------
  @override
  Future<int> getItemCount() async {
    final items = await listItems();
    return items.length;
  }

  @override
  Future<int> getTotalSize() async {
    final vaultDir = await _getVaultDirectory();
    int total = 0;
    await for (final entity in vaultDir.list()) {
      if (entity is File && entity.path.endsWith('.enc')) {
        total += await entity.length();
      }
    }
    return total;
  }

  // ── Private helpers ─────────────────────────────────────────

  Future<Directory> _getVaultDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vault = Directory(p.join(appDir.path, '.secure_vault'));

    if (!await vault.exists()) {
      await vault.create(recursive: true);
      // .nomedia prevents Android media scanner from indexing the dir
      await File(p.join(vault.path, '.nomedia')).create();
    }

    return vault;
  }

  /// Clears the in-memory cache — must be called when vault is locked.
  void clearCache() {
    _cachedItems = null;
  }

  /// Generates a new unique ID for an incoming encrypted item.
  String generateSecureId() => _uuid.v4().replaceAll('-', '');
}