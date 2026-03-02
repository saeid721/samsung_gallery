import 'package:get/get.dart';

import '../../../core/services/background_task_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../data/repositories/sync_repository.dart';

class SyncController extends GetxController {
  final SyncRepository          _syncRepo    = Get.find<SyncRepository>();
  final GooglePhotosSyncService _syncService = Get.find<GooglePhotosSyncService>();
  final SecureStorageService    _storage     = Get.find<SecureStorageService>();

  // ── Observable state ─────────────────────────────────────────
  final Rx<SyncSettings> settings        = const SyncSettings().obs;
  final RxBool           isSignedIn      = false.obs;
  final RxBool           isLoading       = true.obs;
  final RxBool           isSyncing       = false.obs;
  final RxString         syncStatusText  = ''.obs;
  final RxInt            uploadQueueSize = 0.obs;
  final RxDouble         syncProgress    = 0.0.obs; // 0.0–1.0

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _loadState();

    // Mirror live sync progress from service into controller
    ever(_syncService.syncState, (state) {
      isSyncing.value   = state.isRunning;
      syncProgress.value = state.totalToUpload > 0
          ? state.uploaded / state.totalToUpload
          : 0.0;

      if (state.lastError != null) {
        syncStatusText.value = 'Sync error: ${state.lastError}';
      } else if (state.isRunning) {
        syncStatusText.value =
        'Uploading ${state.uploaded} / ${state.totalToUpload}…';
      } else if (state.lastSyncAt != null) {
        syncStatusText.value =
        'Last synced ${_timeAgo(state.lastSyncAt!)}';
      }
    });
  }

  // ── LOAD ──────────────────────────────────────────────────────

  Future<void> _loadState() async {
    isLoading.value = true;
    try {
      settings.value   = await _syncRepo.getSettings();
      isSignedIn.value = await _syncService.isSignedIn;

      final queue = await _syncRepo.getUploadQueue();
      uploadQueueSize.value = queue.length;

      if (settings.value.lastSyncAt != null) {
        syncStatusText.value =
        'Last synced ${_timeAgo(settings.value.lastSyncAt!)}';
      } else {
        syncStatusText.value = 'Never synced';
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ── SIGN IN / OUT ─────────────────────────────────────────────

  Future<void> signIn() async {
    final success = await _syncService.signIn();
    if (success) {
      isSignedIn.value = true;
      final email = await _storage.read('google_email');
      settings.value = settings.value.copyWith(connectedEmail: email);
      await _syncRepo.saveSettings(settings.value);
      Get.snackbar('Connected', 'Signed in to Google Photos',
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('Sign in failed', 'Please try again',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> signOut() async {
    await _syncService.signOut();
    await _syncRepo.clearAllSyncData();
    isSignedIn.value = false;
    settings.value   = const SyncSettings();
    syncStatusText.value = 'Not connected';
    uploadQueueSize.value = 0;
  }

  // ── SETTINGS TOGGLES ──────────────────────────────────────────

  Future<void> setAutoSync(bool enabled) async {
    settings.value = settings.value.copyWith(autoSyncEnabled: enabled);
    await _syncRepo.saveSettings(settings.value);

    if (enabled) {
      // Register periodic WorkManager task
      await BackgroundTaskService.schedulePeriodicSync();
    } else {
      // Cancel scheduled sync tasks
      await BackgroundTaskService.cancelAll();
    }
  }

  Future<void> setWifiOnly(bool wifiOnly) async {
    settings.value = settings.value.copyWith(wifiOnly: wifiOnly);
    await _syncRepo.saveSettings(settings.value);
    // Re-register WorkManager task with updated constraints
    if (settings.value.autoSyncEnabled) {
      await BackgroundTaskService.schedulePeriodicSync();
    }
  }

  Future<void> setSyncVideos(bool syncVideos) async {
    settings.value = settings.value.copyWith(syncVideos: syncVideos);
    await _syncRepo.saveSettings(settings.value);
  }

  // ── MANUAL SYNC ───────────────────────────────────────────────

  Future<void> syncNow() async {
    if (!isSignedIn.value || isSyncing.value) return;

    isSyncing.value      = true;
    syncStatusText.value = 'Starting sync…';
    syncProgress.value   = 0.0;

    try {
      await _syncService.runSync(wifiOnly: settings.value.wifiOnly);

      // Refresh settings to get updated lastSyncAt
      settings.value = await _syncRepo.getSettings();
      final queue = await _syncRepo.getUploadQueue();
      uploadQueueSize.value = queue.length;
    } finally {
      isSyncing.value = false;
    }
  }

  // ── Computed getters ──────────────────────────────────────────

  bool get canSync => isSignedIn.value && !isSyncing.value;

  String get uploadQueueLabel => uploadQueueSize.value == 0
      ? 'Up to date'
      : '${uploadQueueSize.value} item(s) waiting to upload';

  // ── Private helpers ───────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}