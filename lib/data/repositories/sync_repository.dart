// ============================================================
// features/sync/repositories/sync_repository.dart
// ============================================================
// Persists sync state between app sessions:
//   • Upload queue  — local assetIds waiting to be uploaded
//   • Sync index    — assetId ↔ Google Photos mediaId mapping
//   • Settings      — wifi-only, auto-sync enabled, last sync time
//   • Auth state    — whether user is signed in to Google
//
// All data stored via SecureStorageService (no plaintext on disk).
// The actual HTTP sync work lives in:
//   features/sync/services/google_photos_sync_service.dart
// ============================================================

import 'dart:convert';

import '../../../core/services/secure_storage_service.dart';

// ── Data models ─────────────────────────────────────────────

class SyncSettings {
  final bool autoSyncEnabled;
  final bool wifiOnly;
  final bool syncVideos;
  final DateTime? lastSyncAt;
  final String? connectedEmail;

  const SyncSettings({
    this.autoSyncEnabled = false,
    this.wifiOnly = true,
    this.syncVideos = true,
    this.lastSyncAt,
    this.connectedEmail,
  });

  SyncSettings copyWith({
    bool? autoSyncEnabled,
    bool? wifiOnly,
    bool? syncVideos,
    DateTime? lastSyncAt,
    String? connectedEmail,
  }) =>
      SyncSettings(
        autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        syncVideos: syncVideos ?? this.syncVideos,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        connectedEmail: connectedEmail ?? this.connectedEmail,
      );

  Map<String, dynamic> toJson() => {
    'autoSyncEnabled': autoSyncEnabled,
    'wifiOnly': wifiOnly,
    'syncVideos': syncVideos,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'connectedEmail': connectedEmail,
  };

  factory SyncSettings.fromJson(Map<String, dynamic> json) => SyncSettings(
    autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? false,
    wifiOnly: json['wifiOnly'] as bool? ?? true,
    syncVideos: json['syncVideos'] as bool? ?? true,
    lastSyncAt: json['lastSyncAt'] != null
        ? DateTime.tryParse(json['lastSyncAt'] as String)
        : null,
    connectedEmail: json['connectedEmail'] as String?,
  );
}

// ── Abstract interface ──────────────────────────────────────
abstract class SyncRepository {
  Future<SyncSettings> getSettings();
  Future<void> saveSettings(SyncSettings settings);

  /// Returns assetIds queued for upload to Google Photos.
  Future<List<String>> getUploadQueue();

  /// Adds assetIds to the upload queue.
  Future<void> enqueueForUpload(List<String> assetIds);

  /// Removes assetIds from the upload queue (after successful upload).
  Future<void> dequeueUploaded(List<String> assetIds);

  /// Returns the Google Photos mediaId for a local assetId, or null.
  Future<String?> getGoogleMediaId(String assetId);

  /// Saves the assetId ↔ Google mediaId mapping after upload.
  Future<void> saveSyncMapping(String assetId, String googleMediaId);

  /// Returns all local assetIds that have been successfully synced.
  Future<Set<String>> getSyncedAssetIds();

  /// Clears all sync data (called on Google sign-out).
  Future<void> clearAllSyncData();
}

// ── Concrete implementation ─────────────────────────────────
class SyncRepositoryImpl implements SyncRepository {
  final SecureStorageService _secureStorage;

  // Storage keys
  static const _settingsKey = 'sync_settings';
  static const _uploadQueueKey = 'sync_upload_queue';
  static const _syncIndexKey = 'sync_index'; // JSON map: assetId → googleId

  SyncRepositoryImpl({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  // ----------------------------------------------------------
  // SETTINGS
  // ----------------------------------------------------------
  @override
  Future<SyncSettings> getSettings() async {
    final raw = await _secureStorage.read(_settingsKey);
    if (raw == null) return const SyncSettings();
    try {
      return SyncSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SyncSettings();
    }
  }

  @override
  Future<void> saveSettings(SyncSettings settings) async {
    await _secureStorage.write(_settingsKey, jsonEncode(settings.toJson()));
  }

  // ----------------------------------------------------------
  // UPLOAD QUEUE
  // Stored as a JSON array of assetId strings.
  // ----------------------------------------------------------
  @override
  Future<List<String>> getUploadQueue() async {
    final raw = await _secureStorage.read(_uploadQueueKey);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> enqueueForUpload(List<String> assetIds) async {
    final queue = await getUploadQueue();
    // Avoid duplicates
    final toAdd = assetIds.where((id) => !queue.contains(id));
    queue.addAll(toAdd);
    await _secureStorage.write(_uploadQueueKey, jsonEncode(queue));
  }

  @override
  Future<void> dequeueUploaded(List<String> assetIds) async {
    final queue = await getUploadQueue();
    queue.removeWhere((id) => assetIds.contains(id));
    await _secureStorage.write(_uploadQueueKey, jsonEncode(queue));
  }

  // ----------------------------------------------------------
  // SYNC INDEX — assetId ↔ googleMediaId mapping
  // Stored as a flat JSON object: { "assetId": "googleId", ... }
  // For 10k+ items this could grow large; consider chunking if needed.
  // ----------------------------------------------------------
  @override
  Future<String?> getGoogleMediaId(String assetId) async {
    final index = await _loadSyncIndex();
    return index[assetId];
  }

  @override
  Future<void> saveSyncMapping(String assetId, String googleMediaId) async {
    final index = await _loadSyncIndex();
    index[assetId] = googleMediaId;
    await _secureStorage.write(_syncIndexKey, jsonEncode(index));
  }

  @override
  Future<Set<String>> getSyncedAssetIds() async {
    final index = await _loadSyncIndex();
    return index.keys.toSet();
  }

  // ----------------------------------------------------------
  // CLEAR ALL (on sign-out)
  // ----------------------------------------------------------
  @override
  Future<void> clearAllSyncData() async {
    await _secureStorage.delete(_settingsKey);
    await _secureStorage.delete(_uploadQueueKey);
    await _secureStorage.delete(_syncIndexKey);
  }

  // ── Private helpers ─────────────────────────────────────────

  Future<Map<String, String>> _loadSyncIndex() async {
    final raw = await _secureStorage.read(_syncIndexKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}