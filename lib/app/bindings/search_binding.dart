import 'package:get/get.dart';

import '../../../features/search/controllers/search_controller.dart';

class SearchBinding extends Bindings {
  @override
  void dependencies() {
    // Fresh instance each open so search query and results are
    // always cleared when the user re-enters the search screen.
    Get.lazyPut<GallerySearchController>(
          () => GallerySearchController(),
    );
  }
}