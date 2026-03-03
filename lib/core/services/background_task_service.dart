import 'package:workmanager/workmanager.dart';

class BackgroundTaskService {
  static const syncTaskName = 'com.gallery.sync';
  static const indexTaskName = 'com.gallery.index';
  static const syncPeriodHours = 1; // Run sync every hour

  // ----------------------------------------------------------
  // Schedule periodic sync (called at app startup)
  // ----------------------------------------------------------
  static Future<void> schedulePeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      'periodic_sync',                    // Unique task name
      syncTaskName,                       // Task identifier
      frequency: const Duration(hours: syncPeriodHours),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected, // Only when online
        requiresBatteryNotLow: true,        // Skip if battery < 15%
        requiresCharging: false,            // Don't require charger
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  // ----------------------------------------------------------
  // Schedule one-time index rebuild (after large changes)
  // ----------------------------------------------------------
  static Future<void> scheduleIndexRebuild() async {
    await Workmanager().registerOneOffTask(
      'rebuild_index_${DateTime.now().millisecondsSinceEpoch}',
      indexTaskName,
      constraints: Constraints(
        requiresBatteryNotLow: true,
      ),
    );
  }

  // ----------------------------------------------------------
  // SYNC TASK HANDLER (called from callbackDispatcher in env.dart)
  // This runs in a background isolate — no Flutter widgets available
  // ----------------------------------------------------------
  static Future<bool> runSyncTask(Map<String, dynamic>? inputData) async {
    try {
      // In background isolate, we can't use Get.find()
      // Must initialize services manually
      // See: flutter.dev/docs/cookbook/architecture/background-tasks

      /*
      PSEUDO-CODE for background sync:

      // 1. Initialize secure_folder_view storage (read sync credentials)
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'google_token');
      if (token == null) return false; // Not signed in

      // 2. Run Google Photos sync
      final syncService = GooglePhotosSyncService(...);
      await syncService.runSync(wifiOnly: true);

      // 3. Auto-purge expired trash items
      final indexService = MediaIndexService(...);
      final expired = indexService.getExpiredTrashItems();
      if (expired.isNotEmpty) {
        await PhotoManager.editor.deleteWithIds(expired);
        await indexService.clearTrashRecords(expired);
      }

      // 4. Update last sync timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync', DateTime.now().toIso8601String());
      */

      return true;
    } catch (e) {
      print('Background sync failed: $e');
      return false;
    }
  }

  // ----------------------------------------------------------
  // INDEX TASK HANDLER
  // ----------------------------------------------------------
  static Future<bool> runIndexTask(Map<String, dynamic>? inputData) async {
    try {
      /*
      PSEUDO-CODE:

      // Re-index all media (runs when MediaStore changes detected)
      final indexService = MediaIndexService(...);
      await indexService.initialize();
      await indexService.loadAllAssets(); // Rebuilds cache
      */
      return true;
    } catch (e) {
      print('Background index failed: $e');
      return false;
    }
  }

  // Cancel all scheduled tasks (called on sign-out or disable)
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}