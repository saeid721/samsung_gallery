import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/face_cluster.dart';

class PeopleView extends StatelessWidget {
  const PeopleView({super.key});

  @override
  Widget build(BuildContext context) {
    // Clusters loaded from SecureStorageService
    // Stub empty list until face scan has been run
    final clusters = <FaceCluster>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            tooltip: 'Scan for faces',
            onPressed: () => Get.snackbar(
              'Face Scan',
              'Scanning gallery for faces… This may take a few minutes.',
              snackPosition: SnackPosition.BOTTOM,
            ),
          ),
        ],
      ),
      body: clusters.isEmpty
          ? const _EmptyPeople()
          : GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: clusters.length,
        itemBuilder: (_, index) =>
            _PersonCard(cluster: clusters[index], index: index),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final FaceCluster cluster;
  final int index;
  const _PersonCard({required this.cluster, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to filtered gallery showing this person's photos
        Get.toNamed('/gallery',
            arguments: {'clusterId': cluster.clusterId});
      },
      onLongPress: () => _showRenameDialog(context),
      child: Column(
        children: [
          // Circular face avatar
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.person, size: 44, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            cluster.displayName(index + 1),
            style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${cluster.photoCount} photos',
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final tc = TextEditingController(text: cluster.personName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Name this person'),
        content: TextField(
          controller: tc,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Mom, John…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              // clusterController.rename(cluster.clusterId, tc.text)
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPeople extends StatelessWidget {
  const _EmptyPeople();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.face, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No people found yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text(
            'Tap the scan button to find\nand group faces in your gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}