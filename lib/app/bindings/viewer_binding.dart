import 'package:get/get.dart';
import '../../features/media_viewer_view/controllers/media_viewer_controller.dart';

class ViewerBinding extends Bindings {
  @override
  void dependencies() {
    // Not fenix — we want a fresh controller each time the viewer opens,
    // so the correct MediaItem from arguments is always loaded.
    Get.lazyPut<MediaViewerController>(
          () => MediaViewerController(),
    );
  }
}