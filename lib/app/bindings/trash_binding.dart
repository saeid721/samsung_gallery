import 'package:get/get.dart';
import '../../features/trash_view/controllers/trash_controller.dart';

class TrashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TrashController>(() => TrashController());
  }
}
