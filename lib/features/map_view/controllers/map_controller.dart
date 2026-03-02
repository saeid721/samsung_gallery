import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/exif_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

// ── Map pin model ─────────────────────────────────────────────
class MapPin {
  final LatLng position;
  final List<MediaItem> items; // All items at/near this position

  const MapPin({required this.position, required this.items});

  bool get isCluster => items.length > 1;
  int get count => items.length;

  /// Generate a unique ID for the pin based on position
  String get groupId => '${position.latitude}-${position.longitude}';

  /// Representative item for cluster thumbnail (newest item)
  MediaItem get representative => items.reduce(
        (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
  );
}

class MapController extends GetxController {
  final MediaRepository _mediaRepo = Get.find<MediaRepository>();
  final ExifService _exifService = Get.find<ExifService>();

  // ── Observable state ─────────────────────────────────────────
  final RxList<MapPin> pins = <MapPin>[].obs;
  final RxBool isLoading = true.obs;
  final Rx<MapPin?> selectedPin = Rx(null);
  final Rx<LatLng> mapCenter = Rx(const LatLng(20.0, 0.0));
  final RxDouble zoomLevel = 2.0.obs;
  final RxInt totalGeotagged = 0.obs;

  // ── Clustering threshold: pins within this distance (km) are merged
  double _clusterRadiusKm = 0.5;

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _loadGeotaggedMedia();
  }

  // ── Load all geotagged photos ─────────────────────────────────

  Future<void> _loadGeotaggedMedia() async {
    isLoading.value = true;
    try {
      // Stream timeline to pick up all geotagged items
      final timeline = await _mediaRepo.getTimelineStream().first;
      final allItems = timeline.expand((g) => g.items).toList();

      // Filter to items that have GPS coordinates
      final geotagged = allItems.where((item) => item.hasLocation).toList();
      totalGeotagged.value = geotagged.length;

      if (geotagged.isEmpty) {
        isLoading.value = false;
        return;
      }

      // Cluster nearby pins
      final clustered = _clusterPins(geotagged);
      pins.assignAll(clustered);

      // Center map on the most recent photo's location
      final newest = geotagged.reduce(
            (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
      );
      mapCenter.value = LatLng(newest.latitude!, newest.longitude!);
      zoomLevel.value = 6.0;
    } catch (e) {
      debugPrint('Error loading geotagged media: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _loadGeotaggedMedia();

  // ── PIN SELECTION ─────────────────────────────────────────────

  void selectPin(MapPin pin) {
    selectedPin.value = pin;
    // Smooth pan to selected pin
    mapCenter.value = pin.position;
    if (pin.isCluster && zoomLevel.value < 10) {
      zoomLevel.value = zoomLevel.value + 2; // Zoom in on cluster tap
    }
  }

  void clearSelection() {
    selectedPin.value = null;
  }

  void onMapTap(LatLng position) {
    // Tapping empty map area clears pin selection
    if (selectedPin.value != null) clearSelection();
  }

  // ── NAVIGATE to selected pin's photos ─────────────────────────

  void openPinInViewer(MapPin pin) {
    Get.toNamed(
      '/viewer',
      arguments: {
        'mediaItem': pin.representative,
        'items': pin.items,
        'index': 0,
      },
    );
  }

  // ── ZOOM ─────────────────────────────────────────────────────

  void setZoom(double zoom) {
    zoomLevel.value = zoom;
    // Re-cluster at new zoom level
    _reclusterAtZoom(zoom);
  }

  // ── Private: clustering algorithm ────────────────────────────
  //
  // Simple distance-based clustering:
  //   1. Sort items by latitude
  //   2. For each ungrouped item, find all items within _clusterRadiusKm
  //   3. Group them into a MapPin centred on their average position

  List<MapPin> _clusterPins(List<MediaItem> items) {
    if (items.isEmpty) return [];

    final distance = const Distance();
    final processed = <int>{};
    final result = <MapPin>[];

    for (int i = 0; i < items.length; i++) {
      if (processed.contains(i)) continue;

      final a = items[i];
      final posA = LatLng(a.latitude!, a.longitude!);
      final group = <MediaItem>[a];
      processed.add(i);

      for (int j = i + 1; j < items.length; j++) {
        if (processed.contains(j)) continue;

        final b = items[j];
        final posB = LatLng(b.latitude!, b.longitude!);
        final distKm = distance.as(LengthUnit.Kilometer, posA, posB);

        if (distKm <= _clusterRadiusKm) {
          group.add(b);
          processed.add(j);
        }
      }

      // Compute centroid of the group
      final avgLat = group.fold(0.0, (s, item) => s + item.latitude!) / group.length;
      final avgLng = group.fold(0.0, (s, item) => s + item.longitude!) / group.length;

      result.add(MapPin(
        position: LatLng(avgLat, avgLng),
        items: group,
      ));
    }

    return result;
  }

  void _reclusterAtZoom(double zoom) {
    // Adjust cluster radius based on zoom level
    if (zoom < 5) {
      _clusterRadiusKm = 50.0; // Far zoom: large clusters
    } else if (zoom < 10) {
      _clusterRadiusKm = 5.0; // Medium zoom: medium clusters
    } else {
      _clusterRadiusKm = 0.5; // Close zoom: individual pins
    }

    // Reload pins with new threshold
    _loadGeotaggedMedia();
  }
}