import 'package:get/get.dart';
import '../../shared/widgets/navigation_menu/bottom_nav_controller.dart';

// Services
import '../../core/services/ai_pipeline_service.dart';
import '../../core/services/background_task_service.dart';
import '../../core/services/exif_service.dart';
import '../../core/services/media_index_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/thumbnail_cache_service.dart';

// Repositories
import '../../data/repositories/album_repository.dart';
import '../../data/repositories/face_recognition_service.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/secure_media_repository.dart';
import '../../data/repositories/sync_repository.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // ── Core Controllers ────────────────────────────────────
    Get.lazyPut(() => BottomNavController(), fenix: true);
    Get.lazyPut(() => BottomNavController(), fenix: true);
    Get.lazyPut(() => BottomNavController(), fenix: true);
    Get.lazyPut(() => BottomNavController(), fenix: true);
    Get.lazyPut(() => BottomNavController(), fenix: true);


    // ── Core Services (always-alive singletons) ─────────────
    Get.lazyPut(() => SecureStorageService(), fenix: true);
    Get.lazyPut(() => ThumbnailCacheService(), fenix: true);
    Get.lazyPut(() => ExifService(), fenix: true);
    Get.lazyPut<MediaIndexService>(() => MediaIndexService(thumbnailCache: Get.find<ThumbnailCacheService>()), fenix: true);

    // ── Repositories ────────────────────────────────────────
    Get.lazyPut<MediaRepository>(() => MediaRepositoryImpl(indexService: Get.find<MediaIndexService>(), exifService: Get.find<ExifService>()), fenix: true);
    Get.lazyPut<AlbumRepository>(() => AlbumRepositoryImpl(mediaRepo: Get.find<MediaRepository>(), indexService: Get.find<MediaIndexService>()), fenix: true);
    Get.lazyPut<SyncRepository>(() => SyncRepositoryImpl(secureStorage: Get.find<SecureStorageService>()), fenix: true);
    Get.lazyPut<SecureMediaRepository>(() => SecureMediaRepositoryImpl(secureStorage: Get.find<SecureStorageService>()), fenix: true);

    // ── AI Services ─────────────────────────────────────────
    // Get.lazyPut<FaceRecognitionService>(
    //       () => FaceRecognitionService(),
    //   fenix: true,
    // );
    //
    // Get.lazyPut<AiPipelineService>(
    //       () => AiPipelineService(
    //     faceService: Get.find<FaceRecognitionService>(),
    //   ),
    //   fenix: true,
    // );

    // ── Background Task Service ──────────────────────────────
    // Get.lazyPut<BackgroundTaskService>(
    //       () => BackgroundTaskService(),
    //   fenix: true,
    // );
  }
}