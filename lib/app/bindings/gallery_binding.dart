
import 'package:get/get.dart';

import '../../../features/gallery/controllers/gallery_controller.dart';
import '../../../features/albums/controllers/albums_controller.dart';

class GalleryBinding extends Bindings {
  @override
  void dependencies() {
    // GalleryController drives the main timeline screen.
    // fenix: true — recreate if disposed while navigating away.
    Get.lazyPut<GalleryController>(
          () => GalleryController(),
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