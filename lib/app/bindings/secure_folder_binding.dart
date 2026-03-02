import 'package:get/get.dart';
import '../../features/secure_folder_view/controllers/secure_folder_controller.dart';

class SecureFolderBinding extends Bindings {
  @override
  void dependencies() {
    // fenix: false — we want a fresh locked controller every time
    // the secure_folder_view folder route is pushed. This ensures the vault
    // is never left unlocked if the user navigates away and back.
    Get.lazyPut<SecureFolderController>(
          () => SecureFolderController(),
    );
  }
}