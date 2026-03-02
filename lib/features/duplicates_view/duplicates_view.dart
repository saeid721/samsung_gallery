import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../app/theme/theme.dart';

class DuplicatesView extends StatelessWidget {
  const DuplicatesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicate Cleaner')),
      body: FutureBuilder(
        // Stream from MediaIndexService.streamDuplicateGroups()
        future: Future.value(<List<String>>[]), // stub
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _ScanningIndicator();
          }

          final groups = snap.data as List<List<String>>? ?? [];

          if (groups.isEmpty) {
            return const _NoDuplicates();
          }

          return Column(
            children: [
              // Summary banner
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      '${groups.length} duplicate groups found',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Clean All'),
                    ),
                  ],
                ),
              ),
              // Duplicate groups
              Expanded(
                child: ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, index) =>
                      _DuplicateGroup(assetIds: groups[index], groupIndex: index),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DuplicateGroup extends StatefulWidget {
  final List<String> assetIds;
  final int groupIndex;
  const _DuplicateGroup(
      {required this.assetIds, required this.groupIndex});

  @override
  State<_DuplicateGroup> createState() => _DuplicateGroupState();
}

class _DuplicateGroupState extends State<_DuplicateGroup> {
  int? _keepIndex;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group ${widget.groupIndex + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Thumbnails side-by-side
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.assetIds.length,
                itemBuilder: (_, index) {
                  final isKept = _keepIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _keepIndex = index),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isKept ? AppColors.primary : Colors.grey.shade300,
                          width: isKept ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FutureBuilder(
                              future: _loadThumb(widget.assetIds[index]),
                              builder: (_, snap) => snap.hasData
                                  ? Image.memory(snap.data!, fit: BoxFit.cover)
                                  : Container(color: Colors.grey.shade200),
                            ),
                            if (isKept)
                              const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.check_circle,
                                      color: AppColors.primary, size: 20),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_keepIndex == null)
                  const Text('Tap to keep one',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                const Spacer(),
                TextButton(
                  onPressed: _keepIndex == null ? null : _deleteOthers,
                  child: Text(
                    'Delete ${widget.assetIds.length - 1} duplicates',
                    style: TextStyle(
                      color: _keepIndex != null ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteOthers() {
    final toDelete = List.generate(widget.assetIds.length, (i) => i)
        .where((i) => i != _keepIndex)
        .map((i) => widget.assetIds[i])
        .toList();
    // MediaRepository.trashItems(toDelete)
    Get.snackbar('Deleted',
        '${toDelete.length} duplicate(s) moved to trash',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<dynamic> _loadThumb(String id) async {
    final asset = await AssetEntity.fromId(id);
    return asset?.thumbnailDataWithSize(const ThumbnailSize(200, 200));
  }
}

class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Scanning for duplicates…',
              style: TextStyle(color: Colors.grey)),
          SizedBox(height: 4),
          Text('This may take a moment for large libraries.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NoDuplicates extends StatelessWidget {
  const _NoDuplicates();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text('No duplicates found!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Your gallery is clean.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}