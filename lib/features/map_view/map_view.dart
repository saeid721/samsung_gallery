
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:photo_manager/photo_manager.dart';

import '../controllers/map_controller.dart';
import '../models/media_item.dart';

class MapView extends GetView<MapController> {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isLoading.value) {
          return _LoadingState();
        }
        if (controller.totalGeotagged.value == 0) {
          return _EmptyState();
        }
        return _MapBody(controller: controller);
      }),
    );
  }
}

class _MapBody extends StatefulWidget {
  final MapController controller;
  const _MapBody({required this.controller});

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  late final MapController_flutter _mapCtrl;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController_flutter();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return Stack(
      children: [
        // ── OpenStreetMap ──────────────────────────────────
        Obx(() => FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: ctrl.mapCenter.value,
            initialZoom: ctrl.zoomLevel.value,
            onTap: (_, pos) { ctrl.onMapTap(pos); },
            onMapEvent: (event) {
              if (event is MapEventMoveEnd) {
                ctrl.setZoom(_mapCtrl.camera.zoom);
              }
            },
          ),
          children: [
            // Tile layer (OSM)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.yourapp.gallery',
              tileProvider: CancellableNetworkTileProvider(),
            ),

            // Pin markers
            MarkerLayer(
              markers: ctrl.pins.map((pin) {
                return Marker(
                  point: pin.position,
                  width: pin.isCluster ? 52 : 44,
                  height: pin.isCluster ? 52 : 44,
                  child: GestureDetector(
                    onTap: () => ctrl.selectPin(pin),
                    child: _PinMarker(
                        pin: pin,
                        isSelected: ctrl.selectedPin.value?.groupId == pin.groupId),
                  ),
                );
              }).toList(),
            ),
          ],
        )),

        // ── Top bar ────────────────────────────────────────
        _TopBar(controller: ctrl),

        // ── Selected pin preview ───────────────────────────
        Obx(() {
          final pin = ctrl.selectedPin.value;
          if (pin == null) return const SizedBox.shrink();
          return Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16, right: 16,
            child: _PinPreviewCard(pin: pin, controller: ctrl),
          );
        }),

        // ── Zoom controls ─────────────────────────────────
        Positioned(
          right: 12,
          top: MediaQuery.of(context).padding.top + 72,
          child: _ZoomControls(mapCtrl: _mapCtrl, ctrl: ctrl),
        ),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final MapController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(4, top + 4, 16, 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Get.back(),
            ),
            const Text('Photo Map',
                style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24)),
              child: Text(
                '${controller.totalGeotagged.value} photos',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Pin marker widget ─────────────────────────────────────────
class _PinMarker extends StatelessWidget {
  final MapPin pin;
  final bool isSelected;
  const _PinMarker({required this.pin, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? Colors.blue.shade400 : const Color(0xFF1259C3),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.6 : 0.4),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: pin.isCluster
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${pin.count}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        )
            : const Icon(Icons.photo_camera_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}

// ── Selected pin preview card ─────────────────────────────────
class _PinPreviewCard extends StatelessWidget {
  final MapPin pin;
  final MapController controller;
  const _PinPreviewCard({required this.pin, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: Offset.zero,
      curve: Curves.easeOutCubic,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 6))
          ],
        ),
        child: Row(
          children: [
            // Thumbnail(s)
            GestureDetector(
              onTap: () => controller.openPinInViewer(pin),
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: SizedBox(
                  width: 100,
                  height: double.infinity,
                  child: pin.items.length == 1
                      ? _Thumb(assetId: pin.items.first.id)
                      : _MultiThumb(items: pin.items.take(4).toList()),
                ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pin.isCluster
                          ? '${pin.count} photos here'
                          : '1 photo',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _latLngLabel(pin.position),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                    Row(
                      children: [
                        _PillBtn(
                          label: 'View',
                          icon: Icons.photo_library_outlined,
                          onTap: () => controller.openPinInViewer(pin),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: controller.clearSelection,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white54, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _latLngLabel(LatLng pos) =>
      '${pos.latitude.toStringAsFixed(3)}°, '
          '${pos.longitude.toStringAsFixed(3)}°';
}

class _PillBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PillBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1259C3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

// ── Zoom controls ─────────────────────────────────────────────
class _ZoomControls extends StatelessWidget {
  final MapController_flutter mapCtrl;
  final MapController ctrl;
  const _ZoomControls({required this.mapCtrl, required this.ctrl});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ZoomBtn(
        icon: Icons.add,
        onTap: () {
          final z = (mapCtrl.camera.zoom + 1).clamp(1.0, 18.0);
          mapCtrl.move(mapCtrl.camera.center, z);
          ctrl.setZoom(z);
        },
      ),
      const SizedBox(height: 4),
      _ZoomBtn(
        icon: Icons.remove,
        onTap: () {
          final z = (mapCtrl.camera.zoom - 1).clamp(1.0, 18.0);
          mapCtrl.move(mapCtrl.camera.center, z);
          ctrl.setZoom(z);
        },
      ),
    ],
  );
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

// ── Thumbnail helpers ─────────────────────────────────────────
class _Thumb extends StatelessWidget {
  final String assetId;
  const _Thumb({required this.assetId});

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _load(),
    builder: (_, snap) => snap.hasData
        ? Image.memory(snap.data!, fit: BoxFit.cover)
        : Container(color: Colors.white12),
  );

  Future<Uint8List?> _load() async {
    final a = await AssetEntity.fromId(assetId);
    return a?.thumbnailDataWithSize(const ThumbnailSize(200, 200));
  }
}

class _MultiThumb extends StatelessWidget {
  final List<MediaItem> items;
  const _MultiThumb({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 1, crossAxisSpacing: 1),
      itemCount: items.length.clamp(0, 4),
      itemBuilder: (_, i) => _Thumb(assetId: items[i].id),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Loading photo locations…',
              style: TextStyle(color: Colors.white38)),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Photo Map'),
    ),
    body: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 64, color: Colors.white24),
          SizedBox(height: 20),
          Text('No location data found',
              style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Enable location access in camera settings to see your photos on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    ),
  );
}

// flutter_map MapController alias to avoid naming conflict with GetX MapController
typedef MapController_flutter = FlutterMapController;