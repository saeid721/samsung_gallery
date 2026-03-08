
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/theme/theme.dart';
import '../../data/models/media_model.dart';
import 'controllers/locations_controller.dart';

class LocationsView extends GetView<LocationsController> {
  const LocationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => controller.activePlace.value != null
        ? _PlaceDetailScreen(c: controller)
        : _LocationsListScreen(c: controller));
  }
}

// ══════════════════════════════════════════════════════════════
// LOCATIONS LIST
// ══════════════════════════════════════════════════════════════
class _LocationsListScreen extends StatelessWidget {
  final LocationsController c;
  const _LocationsListScreen({required this.c});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(children: [
        // Header
        Container(
          color: const Color(0xFF0F0F0F),
          padding: EdgeInsets.fromLTRB(4, top + 8, 16, 0),
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Get.back(),
              ),
              const Expanded(
                child: Text('Locations',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
              // Map/Grid toggle
              Obx(() => IconButton(
                icon: Icon(
                  c.viewMode.value == LocationViewMode.grid
                      ? Icons.map_outlined
                      : Icons.grid_view_rounded,
                  color: Colors.white70,
                ),
                onPressed: c.toggleViewMode,
              )),
            ]),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
              child: _SearchBar(c: c),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Obx(() => Row(children: [
                _Stat(Icons.location_on_outlined,
                    '${c.totalPlaces.value} places'),
                const SizedBox(width: 16),
                _Stat(Icons.photo_outlined,
                    '${c.geotaggedCount.value} photos'),
              ])),
            ),
          ]),
        ),

        // Body
        Expanded(
          child: Obx(() {
            if (c.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              );
            }
            if (c.filteredPlaces.isEmpty) {
              return const _EmptyState();
            }
            return RefreshIndicator(
              onRefresh: c.refresh,
              color: AppColors.primary,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: c.filteredPlaces.length,
                itemBuilder: (_, i) => _PlaceCard(
                    place: c.filteredPlaces[i], c: c),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final LocationsController c;
  const _SearchBar({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    margin: const EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextField(
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: c.onSearchChanged,
      decoration: const InputDecoration(
        hintText: 'Search places…',
        hintStyle:
        TextStyle(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded,
            color: Colors.white38, size: 18),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white38, size: 14),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 12)),
    ],
  );
}

// ── Place card ────────────────────────────────────────────────
class _PlaceCard extends StatelessWidget {
  final LocationPlace place;
  final LocationsController c;
  const _PlaceCard({required this.place, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => c.openPlace(place),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1A1A1A),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            // Cover photo
            FutureBuilder<Uint8List?>(
              future: _thumb(place.coverItem.id),
              builder: (_, snap) => snap.hasData
                  ? Image.memory(snap.data!, fit: BoxFit.cover)
                  : Container(
                  color: Colors.white.withOpacity(0.05)),
            ),

            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),

            // Location info
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.white70, size: 13),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text('${place.count} photos',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11)),
                ],
              ),
            ),

            // Multi-photo corner strip
            if (place.count > 1)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${place.count}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Future<Uint8List?> _thumb(String id) async {
    final a = await AssetEntity.fromId(id);
    return a?.thumbnailDataWithSize(const ThumbnailSize(400, 400));
  }
}

// ══════════════════════════════════════════════════════════════
// PLACE DETAIL SCREEN
// ══════════════════════════════════════════════════════════════
class _PlaceDetailScreen extends StatelessWidget {
  final LocationsController c;
  const _PlaceDetailScreen({required this.c});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return WillPopScope(
      onWillPop: () async {
        c.closePlace();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Obx(() {
          final place = c.activePlace.value;
          if (place == null) return const SizedBox.shrink();

          return CustomScrollView(
            slivers: [
              // ── Collapsing header map-style banner ────
              SliverAppBar(
                expandedHeight: 220,
                backgroundColor: const Color(0xFF0F0F0F),
                leading: IconButton(
                  icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: c.closePlace,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Mosaic of first 4 photos
                      _MosaicCover(items: place.items.take(4).toList()),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black87,
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16, bottom: 16,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.primary,
                                  size: 16),
                              const SizedBox(width: 4),
                              Text(place.displayLocation,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight:
                                      FontWeight.w700)),
                            ]),
                            Text('${place.count} photos',
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Photos grid ───────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => GestureDetector(
                      onTap: () => Get.toNamed('/viewer',
                          arguments: {
                            'mediaItem': place.items[i],
                            'items': place.items,
                            'index': i,
                          }),
                      child: _ThumbCell(id: place.items[i].id),
                    ),
                    childCount: place.items.length,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _MosaicCover extends StatelessWidget {
  final List<MediaItem> items;
  const _MosaicCover({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return _ThumbCell(id: items.first.id);
    }
    return Row(children: [
      Expanded(child: _ThumbCell(id: items.first.id)),
      const SizedBox(width: 2),
      Expanded(
        child: Column(children: [
          for (int i = 1; i < items.length && i < 4; i++) ...[
            if (i > 1) const SizedBox(height: 2),
            Expanded(child: _ThumbCell(id: items[i].id)),
          ],
        ]),
      ),
    ]);
  }
}

class _ThumbCell extends StatelessWidget {
  final String id;
  const _ThumbCell({required this.id});

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: () async {
      final a = await AssetEntity.fromId(id);
      return a?.thumbnailDataWithSize(
          const ThumbnailSize(300, 300));
    }(),
    builder: (_, snap) => snap.hasData
        ? Image.memory(snap.data!, fit: BoxFit.cover)
        : Container(
        color: Colors.white.withOpacity(0.05)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.location_off_outlined,
            size: 64, color: Colors.white24),
        SizedBox(height: 16),
        Text('No location data',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            'Enable location in your camera app to see photos grouped by place.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white38, height: 1.6),
          ),
        ),
      ],
    ),
  );
}