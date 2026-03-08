// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../../features/gallery/controllers/gallery_controller.dart';
// import '../../../app/theme/theme.dart';
//
// class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
//   const SelectionAppBar({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.find<GalleryController>();
//
//     return Obx(() {
//       final selectedCount = controller.selectedIds.length;
//       final allCount = controller.timelineGroups
//           .expand((g) => g.items)
//           .length;
//
//       return SliverAppBar(
//         pinned: true,
//         floating: false,
//         backgroundColor: AppColors.primary,
//         elevation: 2,
//         leading: IconButton(
//           icon: const Icon(Icons.close, color: Colors.grey),
//           onPressed: controller.exitSelectionMode,
//           tooltip: 'Close selection',
//         ),
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               '$selectedCount selected',
//               style: const TextStyle(
//                 color: Colors.grey,
//                 fontSize: 14,
//                 fontWeight: FontWeight.w400,
//               ),
//             ),
//             if (selectedCount > 0)
//               Text(
//                 'Tap to deselect',
//                 style: TextStyle(
//                   color: Colors.grey,
//                   fontSize: 11,
//                 ),
//               ),
//           ],
//         ),
//         actions: [
//           // Select All / Deselect All
//           TextButton(
//             onPressed: () {
//               if (selectedCount < allCount) {
//                 controller.selectAll();
//               } else {
//                 controller.exitSelectionMode();
//               }
//             },
//             child: Text(
//               selectedCount < allCount ? 'ALL' : 'DESELECT',
//               style: const TextStyle(
//                 color: Colors.grey,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 13,
//               ),
//             ),
//           ),
//
//           // More options menu
//           PopupMenuButton<String>(
//             icon: const Icon(Icons.more_vert, color: Colors.white),
//             color: AppColors.surface,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//             onSelected: (value) => _handleAction(value, controller),
//             itemBuilder: (context) => [
//               _buildPopupItem(
//                 icon: Icons.favorite_border,
//                 label: 'Add to Favorites',
//                 value: 'favorite',
//                 enabled: selectedCount > 0,
//               ),
//               _buildPopupItem(
//                 icon: Icons.folder_outlined,
//                 label: 'Move to Album',
//                 value: 'move',
//                 enabled: selectedCount > 0,
//               ),
//               const PopupMenuDivider(),
//               _buildPopupItem(
//                 icon: Icons.delete_outline,
//                 label: 'Move to Trash',
//                 value: 'trash',
//                 enabled: selectedCount > 0,
//                 isDestructive: true,
//               ),
//             ],
//           ),
//         ],
//       );
//     });
//   }
//
//   PopupMenuItem<String> _buildPopupItem({
//     required IconData icon,
//     required String label,
//     required String value,
//     bool enabled = true,
//     bool isDestructive = false,
//   }) {
//     return PopupMenuItem(
//       value: value,
//       enabled: enabled,
//       child: Row(
//         children: [
//           Icon(
//             icon,
//             color: isDestructive ? Colors.red : Colors.grey.shade700,
//             size: 20,
//           ),
//           const SizedBox(width: 12),
//           Text(
//             label,
//             style: TextStyle(
//               color: isDestructive ? Colors.red : Colors.black87,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _handleAction(String value, GalleryController controller) {
//     switch (value) {
//       case 'favorite':
//         controller.toggleFavoriteSelected();
//         break;
//       case 'move':
//         _showMoveToAlbumDialog(controller);
//         break;
//       case 'trash':
//         _showTrashConfirmation(controller);
//         break;
//     }
//   }
//
//   void _showMoveToAlbumDialog(GalleryController controller) {
//     Get.defaultDialog(
//       title: 'Move to Album',
//       content: const Text('Select destination album'),
//       confirm: ElevatedButton(
//         onPressed: () {
//           // TODO: Implement album picker
//           Get.back();
//         },
//         child: const Text('Move'),
//       ),
//       cancel: TextButton(
//         onPressed: () => Get.back(),
//         child: const Text('Cancel'),
//       ),
//     );
//   }
//
//   void _showTrashConfirmation(GalleryController controller) {
//     Get.defaultDialog(
//       title: 'Move to Trash?',
//       middleText: 'Items will be deleted after 30 days',
//       textConfirm: 'Move',
//       textCancel: 'Cancel',
//       confirmTextColor: Colors.white,
//       buttonColor: Colors.red,
//       onConfirm: controller.trashSelected,
//       onCancel: () => Get.back(),
//     );
//   }
//
//   @override
//   Size get preferredSize => const Size.fromHeight(kToolbarHeight);
// }