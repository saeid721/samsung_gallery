// ============================================================
// core/services/secure_storage_service.dart
// ============================================================
// Thin wrapper around flutter_secure_storage.
// Backed by Android Keystore (hardware-backed on supported devices).
//
// Used by:
//   • SecureFolderService  — AES key storage
//   • SyncRepository       — Google OAuth token storage
//   • MediaIndexService    — Trash/favorites persistence
//
// All keys are namespaced with a prefix to avoid collisions.
// ============================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _prefix = 'gallery.';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Use EncryptedSharedPreferences backed by Android Keystore.
      // Hardware-backed on devices with a secure element (most 2018+ phones).
      encryptedSharedPreferences: true,
    ),
  );

  // ── READ ────────────────────────────────────────────────────
  Future<String?> read(String key) =>
      _storage.read(key: '$_prefix$key');

  // ── WRITE ───────────────────────────────────────────────────
  Future<void> write(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);

  // ── DELETE ──────────────────────────────────────────────────
  Future<void> delete(String key) =>
      _storage.delete(key: '$_prefix$key');

  // ── CHECK EXISTS ────────────────────────────────────────────
  Future<bool> containsKey(String key) =>
      _storage.containsKey(key: '$_prefix$key');

  // ── READ ALL (for debugging / backup) ───────────────────────
  Future<Map<String, String>> readAll() async {
    final all = await _storage.readAll();
    // Strip prefix before returning
    return Map.fromEntries(
      all.entries
          .where((e) => e.key.startsWith(_prefix))
          .map((e) => MapEntry(e.key.substring(_prefix.length), e.value)),
    );
  }

  // ── DELETE ALL (called on factory reset / sign-out) ─────────
  Future<void> deleteAll() => _storage.deleteAll();
}