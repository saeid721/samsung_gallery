
import 'package:get/get.dart';

import '../../../features/editor/controllers/editor_controller.dart';

class EditorBinding extends Bindings {
  @override
  void dependencies() {
    // Fresh instance each time — editor state should never persist
    // between separate editing sessions.
    Get.lazyPut<EditorController>(
          () => EditorController(),
    );
  }
}