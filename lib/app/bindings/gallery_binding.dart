import 'package:get/get.dart';

import '../../../features/gallery/controllers/gallery_controller.dart';
import '../../../features/gallery/controllers/gallery_grid_controller.dart';
import '../../../features/gallery/controllers/date_filter_controller.dart';
import '../../../features/albums/controllers/albums_controller.dart';
import '../../features/gallery/controllers/video_thumbnail_manager.dart';

class GalleryBinding extends Bindings {
  @override
  void dependencies() {
    // GalleryController drives the main timeline screen.
    // fenix: true — recreate if disposed while navigating away.
    Get.lazyPut<GalleryController>(
          () => GalleryController(),
      fenix: true,
    );

    // GalleryGridController manages grid columns and pinch-to-zoom
    Get.lazyPut<GalleryGridController>(
          () => GalleryGridController(),
      fenix: true,
    );

    // DateFilterController manages date-based filtering
    Get.lazyPut<DateFilterController>(
          () => DateFilterController(),
      fenix: true,
    );

    // VideoThumbnailManager handles efficient video playback
    Get.lazyPut<VideoThumbnailManager>(
          () => VideoThumbnailManager(),
      fenix: true,
    );

    // AlbumsController is registered here too because the
    // bottom nav bar lets users switch between Gallery and Albums
    // without a full route push — both controllers stay alive.
    Get.lazyPut<AlbumsController>(
          () => AlbumsController(),
      fenix: true,
    );
  }
}