import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../data/models/media_model.dart';

// ── Controller ───────────────────────────────────────────────
class SecureFolderController extends GetxController {
  final SecureFolderService _service = Get.find<SecureFolderService>();

  final RxBool isUnlocked = false.obs;
  final RxBool isAuthenticating = false.obs;
  final RxList<MediaItem> secureItems = <MediaItem>[].obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Always start locked
    isUnlocked.value = false;
  }

  /// Unlock using biometrics or PIN
  Future<void> authenticate() async {
    isAuthenticating.value = true;
    errorMessage.value = '';

    try {
      final authenticated = await _service.authenticate();
      if (authenticated) {
        isUnlocked.value = true;
        await _loadSecureItems();
      } else {
        errorMessage.value = 'Authentication failed. Try again.';
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isAuthenticating.value = false;
    }
  }

  void lock() {
    isUnlocked.value = false;
    secureItems.clear();
    // Clear any cached decrypted data from memory
    _service.clearDecryptedCache();
  }

  Future<void> moveToSecureFolder(List<String> assetIds) async {
    if (!isUnlocked.value) {
      await authenticate();
      if (!isUnlocked.value) return;
    }
    await _service.importMedia(assetIds);
    await _loadSecureItems();
  }

  Future<void> exportFromSecureFolder(List<String> secureIds) async {
    await _service.exportMedia(secureIds);
    await _loadSecureItems();
  }

  Future<void> _loadSecureItems() async {
    final items = await _service.listSecureMedia();
    secureItems.assignAll(items);
  }
}

// ── Service ───────────────────────────────────────────────────
class SecureFolderService {
  static const _keyName = 'secure_folder_aes_key';
  static const _ivName = 'secure_folder_aes_iv';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Use hardware-backed Keystore when available
      encryptedSharedPreferences: true,
    ),
  );

  enc.Encrypter? _encrypter;
  enc.IV? _iv;

  // Decrypted file cache (cleared on lock)
  final Map<String, Uint8List> _decryptedCache = {};

  // ----------------------------------------------------------
  // AUTHENTICATION
  // ----------------------------------------------------------
  Future<bool> authenticate() async {
    final canCheckBiometrics = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();

    final canAuth = canCheckBiometrics || isDeviceSupported;

    if (!canAuth) {
      return _authenticateWithPin();
    }

    final authenticated = await _localAuth.authenticate(
      localizedReason: 'Authenticate to access Secure Folder',
    );

    if (authenticated) {
      await _initEncryption();
    }

    return authenticated;
  }

  Future<bool> _authenticateWithPin() async {
    // Navigate to custom PIN entry screen
    // Returns true if PIN matches stored PIN hash
    // IMPLEMENT: Get.to(() => PinEntryView())
    return false; // Stub
  }

  // ----------------------------------------------------------
  // ENCRYPTION SETUP
  // Generate or retrieve AES-256 key from secure_folder_view storage
  // ----------------------------------------------------------
  Future<void> _initEncryption() async {
    String? keyB64 = await _secureStorage.read(key: _keyName);
    String? ivB64 = await _secureStorage.read(key: _ivName);

    if (keyB64 == null || ivB64 == null) {
      // First time: generate new key and IV
      final key = enc.Key.fromSecureRandom(32); // 256 bits
      final iv = enc.IV.fromSecureRandom(16);   // 128-bit IV
      keyB64 = key.base64;
      ivB64 = iv.base64;

      // Save to Android Keystore-backed storage
      await _secureStorage.write(key: _keyName, value: keyB64);
      await _secureStorage.write(key: _ivName, value: ivB64);
    }

    final key = enc.Key.fromBase64(keyB64);
    _iv = enc.IV.fromBase64(ivB64);
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
  }

  // ----------------------------------------------------------
  // ENCRYPT / DECRYPT FILE BYTES
  // ----------------------------------------------------------
  Uint8List encryptBytes(Uint8List plaintext) {
    if (_encrypter == null || _iv == null) {
      throw StateError('Encryption not initialized. Call authenticate() first.');
    }
    final encrypted = _encrypter!.encryptBytes(plaintext, iv: _iv!);
    return encrypted.bytes;
  }

  Uint8List decryptBytes(Uint8List ciphertext) {
    if (_encrypter == null || _iv == null) {
      throw StateError('Decryption not initialized.');
    }
    final encrypted = enc.Encrypted(ciphertext);
    final decrypted = _encrypter!.decryptBytes(encrypted, iv: _iv!);
    return Uint8List.fromList(decrypted);
  }

  // ----------------------------------------------------------
  // IMPORT MEDIA INTO SECURE FOLDER
  // Copies file → encrypts → saves to private app directory
  // Original file is moved to trash (not deleted yet)
  // ----------------------------------------------------------
  Future<void> importMedia(List<String> assetIds) async {
    final secureDir = await _getSecureDirectory();

    for (final assetId in assetIds) {
      // 1. Get original file path
      // (In real code: use photo_manager to get originFile)
      // final file = await asset.originFile;

      // 2. Read bytes
      // final plaintext = await file.readAsBytes();

      // 3. Encrypt
      // final ciphertext = encryptBytes(plaintext);

      // 4. Save encrypted file with .enc extension
      // final destPath = p.join(secureDir.path, '$assetId.enc');
      // await File(destPath).writeAsBytes(ciphertext);

      // 5. Delete original (or trash it)
      // await PhotoManager.editor.deleteWithIds([assetId]);

      // 6. Save metadata (encrypted JSON sidecar)
      // await _saveMetadata(assetId, secureDir);
    }
  }

  // ----------------------------------------------------------
  // EXPORT (decrypt + save back to gallery)
  // ----------------------------------------------------------
  Future<void> exportMedia(List<String> secureIds) async {
    final secureDir = await _getSecureDirectory();

    for (final secureId in secureIds) {
      // 1. Read encrypted file
      // final encPath = p.join(secureDir.path, '$secureId.enc');
      // final ciphertext = await File(encPath).readAsBytes();

      // 2. Decrypt
      // final plaintext = decryptBytes(ciphertext);

      // 3. Save to Downloads or Camera Roll
      // await ImageGallerySaver.saveImage(plaintext);

      // 4. Delete encrypted file
      // await File(encPath).delete();
    }
  }

  // ----------------------------------------------------------
  // LIST SECURE MEDIA (read metadata, return MediaItem list)
  // ----------------------------------------------------------
  Future<List<MediaItem>> listSecureMedia() async {
    // Read all .meta files from secure_folder_view directory
    // Decrypt each metadata file to get MediaItem info
    // Return list (thumbnails generated on-demand)
    return []; // Stub
  }

  // ----------------------------------------------------------
  // Get or create the secure_folder_view folder directory
  // This is in app's private data directory — other apps can't read it
  // ----------------------------------------------------------
  Future<Directory> _getSecureDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final secureDir = Directory(p.join(appDir.path, '.secure_vault'));
    if (!await secureDir.exists()) {
      await secureDir.create(recursive: true);
      // Create .nomedia to prevent media scanner from indexing it
      await File(p.join(secureDir.path, '.nomedia')).create();
    }
    return secureDir;
  }

  void clearDecryptedCache() {
    _decryptedCache.clear();
    _encrypter = null;
    _iv = null;
  }
}