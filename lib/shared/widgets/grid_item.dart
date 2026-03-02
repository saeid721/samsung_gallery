// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../../data/models/media_model.dart';
// import '../../app/theme/theme.dart';
//
// class GridItem extends StatelessWidget {
//   final MediaItem media;
//   final Future<Uint8List?> Function()? thumbnailLoader;
//
//   const GridItem({required this.media, this.thumbnailLoader, super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<Uint8List?>(
//       future: thumbnailLoader?.call(),
//       builder: (context, snapshot) {
//         Widget child;
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           child = Container(color: Theme.of(context).cardColor);
//         } else if (snapshot.hasError || snapshot.data == null) {
//           child = Container(
//             color: Theme.of(context).cardColor,
//             child: const Icon(Icons.broken_image, color: Colors.redAccent),
//           );
//         } else {
//           child = Image.memory(snapshot.data!, fit: BoxFit.cover);
//         }
//
//         return Stack(
//           children: [
//             Positioned.fill(child: child),
//             if (media.isVideo)
//               const Positioned(top: 4, right: 4, child: Icon(Icons.videocam, color: Colors.white70, size: 20)),
//             if (media.isSecure)
//               const Positioned(top: 4, left: 4, child: Icon(Icons.lock, color: Colors.yellowAccent, size: 20)),
//             if (media.tags.isNotEmpty)
//               Positioned(
//                 bottom: 0,
//                 left: 0,
//                 right: 0,
//                 child: Container(
//                   color: Colors.black45,
//                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                   child: SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: Row(
//                       children: media.tags.map((tag) => Container(
//                         margin: const EdgeInsets.only(right: 4),
//                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: AppColors.accent.withOpacity(0.7),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
//                       )).toList(),
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         );
//       },
//     );
//   }
// }
//
//
//
// class GalleryGrid extends StatelessWidget {
//   final ScrollController _scrollController = ScrollController();
//
//   @override
//   Widget build(BuildContext context) {
//     return Obx(() => GridView.builder(
//       controller: _scrollController,
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 3,
//         mainAxisSpacing: 2,
//         crossAxisSpacing: 2,
//       ),
//       itemCount: controller.mediaList.length,
//       itemBuilder: (context, index) {
//         final media = _scrollController.mediaList[index];
//         return KeepAliveGridItem(media: media);
//       },
//     ));
//   }
// }
//
// class KeepAliveGridItem extends StatefulWidget {
//   final MediaItem media;
//   const KeepAliveGridItem({required this.media, super.key});
//
//   @override
//   State<KeepAliveGridItem> createState() => _KeepAliveGridItemState();
// }
//
// class _KeepAliveGridItemState extends State<KeepAliveGridItem> with AutomaticKeepAliveClientMixin {
//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     return GridItem(media: widget.media);
//   }
//
//   @override
//   bool get wantKeepAlive => true;
// }