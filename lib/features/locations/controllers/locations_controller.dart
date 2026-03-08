
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/exif_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

class LocationPlace {
  final String        id;
  final String        name;          // City or region name
  final String        country;
  final LatLng        center;
  final List<MediaItem> items;
  final MediaItem     coverItem;

  LocationPlace({
    required this.id,
    required this.name,
    required this.country,
    required this.center,
    required this.items,
    required this.coverItem,
  });

  int get count => items.length;

  String get displayLocation =>
      country.isEmpty ? name : '$name, $country';
}

enum LocationViewMode { grid, map }

class LocationsController extends GetxController {
  final MediaRepository _repo    = Get.find<MediaRepository>();
  final ExifService     _exif    = Get.find<ExifService>();

  // ── State ─────────────────────────────────────────────────────
  final RxList<LocationPlace>  places         = <LocationPlace>[].obs;
  final RxBool                 isLoading      = true.obs;
  final Rx<LocationPlace?>     activePlace    = Rx(null);
  final Rx<LocationViewMode>   viewMode       = LocationViewMode.grid.obs;
  final RxString               searchQuery    = ''.obs;
  final RxList<LocationPlace>  filteredPlaces = <LocationPlace>[].obs;

  // Total geotagged count
  final RxInt geotaggedCount = 0.obs;
  final RxInt totalPlaces    = 0.obs;

  static const double _clusterKm = 10.0; // merge pins within 10km

  @override
  void onInit() {
    super.onInit();
    _load();
    debounce(searchQuery, (_) => _filter(),
        time: const Duration(milliseconds: 280));
  }

  // ── Load & cluster ────────────────────────────────────────────
  Future<void> _load() async {
    isLoading.value = true;
    try {
      final timeline = await _repo.getTimelineStream().first;
      final geoItems = timeline
          .expand((g) => g.items)
          .where((i) => i.hasLocation)
          .toList();

      geotaggedCount.value = geoItems.length;

      // Cluster by proximity
      final clusters = _cluster(geoItems);
      places.assignAll(clusters);
      totalPlaces.value = clusters.length;
      _filter();
    } finally {
      isLoading.value = false;
    }
  }

  List<LocationPlace> _cluster(List<MediaItem> items) {
    if (items.isEmpty) return [];

    final dist     = const Distance();
    final used     = <int>{};
    final clusters = <LocationPlace>[];

    for (int i = 0; i < items.length; i++) {
      if (used.contains(i)) continue;
      final center = LatLng(items[i].latitude!, items[i].longitude!);
      final group  = <MediaItem>[items[i]];
      used.add(i);

      for (int j = i + 1; j < items.length; j++) {
        if (used.contains(j)) continue;
        final other = LatLng(items[j].latitude!, items[j].longitude!);
        final km = dist.as(LengthUnit.Kilometer, center, other);
        if (km <= _clusterKm) {
          group.add(items[j]);
          used.add(j);
        }
      }

      // Sort by date for cover
      group.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Build centroid
      final lat = group.map((e) => e.latitude!).reduce((a,b)=>a+b) / group.length;
      final lng = group.map((e) => e.longitude!).reduce((a,b)=>a+b) / group.length;

      clusters.add(LocationPlace(
        id:        'loc_${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}',
        name:      _geocodeName(lat, lng),   // stub — real: geocoding package
        country:   '',
        center:    LatLng(lat, lng),
        items:     group,
        coverItem: group.first,
      ));
    }

    clusters.sort((a, b) => b.count.compareTo(a.count));
    return clusters;
  }

  // Stub — replace with real reverse geocoding
  String _geocodeName(double lat, double lng) {
    if (lat > 48 && lat < 52 && lng > -1 && lng < 3)  return 'Paris';
    if (lat > 35 && lat < 36 && lng > 139 && lng < 140) return 'Tokyo';
    if (lat > 40 && lat < 41 && lng > -74 && lng < -73) return 'New York';
    if (lat > 51 && lat < 52 && lng > -1 && lng < 1)  return 'London';
    return '${lat.toStringAsFixed(1)}°, ${lng.toStringAsFixed(1)}°';
  }

  // ── Filter ────────────────────────────────────────────────────
  void _filter() {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) {
      filteredPlaces.assignAll(places);
    } else {
      filteredPlaces.assignAll(places.where((p) =>
      p.name.toLowerCase().contains(q) ||
          p.country.toLowerCase().contains(q)));
    }
  }

  void onSearchChanged(String q) => searchQuery.value = q;

  // ── Open / close place ────────────────────────────────────────
  void openPlace(LocationPlace place) => activePlace.value = place;
  void closePlace() => activePlace.value = null;

  void toggleViewMode() {
    viewMode.value = viewMode.value == LocationViewMode.grid
        ? LocationViewMode.map
        : LocationViewMode.grid;
  }

  Future<void> refresh() => _load();
}