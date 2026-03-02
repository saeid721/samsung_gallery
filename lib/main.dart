
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';
import 'app/bindings/init_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/theme.dart';
import 'core/config/app_config.dart';
import 'core/services/background_task_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case BackgroundTaskService.syncTaskName:
      // Trigger Google Photos sync in background
        await BackgroundTaskService.runSyncTask(inputData);
        break;
      case BackgroundTaskService.indexTaskName:
      // Re-index media library changes
        await BackgroundTaskService.runIndexTask(inputData);
        break;
    }
    return Future.value(true); // true = task completed successfully
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 2. Load environment config (dev vs prod via --dart-define)
  await Env.load();

  // 3. Initialize WorkManager for background tasks
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: Env.isDev,
  );

  // 4. Schedule periodic background sync (every 1 hour)
  await BackgroundTaskService.schedulePeriodicSync();

  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,

      // ── Theme ─────────────────────────────────────────────
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // ── Routing ───────────────────────────────────────────
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,

      // ── Dependency Injection ──────────────────────────────
      // InitialBinding lazily registers all GetX services/repos
      initialBinding: InitialBinding(),

      // ── Localization (extend later for i18n) ──────────────
      locale: const Locale('en', 'US'),
    );
  }
}