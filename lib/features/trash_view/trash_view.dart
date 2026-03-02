import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
class TrashView extends StatelessWidget {
  const TrashView({super.key});

  @override
  Widget build(BuildContext context) {
    // Stub: load trashed items from MediaIndexService._trashIndex
    final trashedItems = <String>[]; // List of assetIds

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (trashedItems.isNotEmpty)
            TextButton(
              onPressed: () => _confirmEmptyTrash(context),
              child: const Text('Empty',
                  style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Items are permanently deleted after 30 days.',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),

          // Trash grid
          Expanded(
            child: trashedItems.isEmpty
                ? const _EmptyTrash()
                : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: trashedItems.length,
              itemBuilder: (_, index) => _TrashCell(
                assetId: trashedItems[index],
                onRestore: () =>
                    _restoreItem(trashedItems[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _restoreItem(String assetId) {
    // MediaRepository.restoreFromTrash([assetId])
    Get.snackbar('Restored', 'Photo restored to gallery',
        snackPosition: SnackPosition.BOTTOM);
  }

  void _confirmEmptyTrash(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
            'All items will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              // MediaRepository.deleteFromTrash(all trashed ids)
            },
            child: const Text('Delete All',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _TrashCell extends StatelessWidget {
  final String assetId;
  final VoidCallback onRestore;
  const _TrashCell({required this.assetId, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder(
          future: _loadThumb(),
          builder: (_, snap) => snap.hasData
              ? Image.memory(snap.data!, fit: BoxFit.cover,
              color: Colors.black26,
              colorBlendMode: BlendMode.darken)
              : Container(color: Colors.grey.shade300),
        ),
        // Restore button overlay
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRestore,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.restore, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<dynamic> _loadThumb() async {
    final asset = await AssetEntity.fromId(assetId);
    return asset?.thumbnailDataWithSize(const ThumbnailSize(256, 256));
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.delete_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Trash is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Deleted photos appear here\nfor 30 days before removal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}