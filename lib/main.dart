import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';
import 'app/bindings/init_binding.dart';
import 'app/env.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/theme.dart';
import 'core/config/app_config.dart';
import 'core/services/background_task_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case BackgroundTaskService.syncTaskName:
        await BackgroundTaskService.runSyncTask(inputData);
        break;
      case BackgroundTaskService.indexTaskName:
        await BackgroundTaskService.runIndexTask(inputData);
        break;
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show loading screen while initializing
  runApp(const InitializerApp());
}

class InitializerApp extends StatefulWidget {
  const InitializerApp({super.key});

  @override
  State<InitializerApp> createState() => _InitializerAppState();
}

class _InitializerAppState extends State<InitializerApp> {
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Lock to portrait orientation
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // 2. Load environment config
      await Env.load();

      // 3. Initialize WorkManager for background tasks
      try {
        await Workmanager().initialize(callbackDispatcher);
        await BackgroundTaskService.schedulePeriodicSync();
      } catch (e) {
        print('⚠️ WorkManager initialization failed: $e');
        // Non-critical error, continue
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Initialization Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(_errorMessage, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _initializeApp(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading ${AppConfig.appName}...',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const GalleryApp();
  }
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      initialBinding: InitialBinding(),
      locale: const Locale('en', 'US'),

      // Add error handling for routing
      unknownRoute: GetPage(
        name: '/404',
        page: () => const NotFoundPage(),
        transition: Transition.fadeIn,
      ),
    );
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Get.offAllNamed(AppPages.gallery),
              child: const Text('Go to Gallery'),
            ),
          ],
        ),
      ),
    );
  }
}