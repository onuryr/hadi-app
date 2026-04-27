import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' hide Cluster, ClusterManager;

class _ActivityPlace with ClusterItem {
  final String id;
  final String title;
  final String? snippet;
  final LatLng latLng;
  final VoidCallback onTap;

  _ActivityPlace({
    required this.id,
    required this.title,
    required this.snippet,
    required this.latLng,
    required this.onTap,
  });

  @override
  LatLng get location => latLng;
}

class ClusteredActivitiesMap extends StatefulWidget {
  final List<Map<String, dynamic>> activities;
  final LatLng initialCenter;
  final void Function(Map<String, dynamic> activity) onMarkerTap;
  final String Function(num? km) formatDistance;

  const ClusteredActivitiesMap({
    super.key,
    required this.activities,
    required this.initialCenter,
    required this.onMarkerTap,
    required this.formatDistance,
  });

  @override
  State<ClusteredActivitiesMap> createState() => _ClusteredActivitiesMapState();
}

class _ClusteredActivitiesMapState extends State<ClusteredActivitiesMap> {
  late ClusterManager _manager;
  Set<Marker> _markers = {};
  GoogleMapController? _controller;
  final Completer<void> _ready = Completer<void>();

  List<_ActivityPlace> _buildPlaces() {
    return widget.activities
        .where((a) => a['lat'] != null && a['lng'] != null)
        .map((a) => _ActivityPlace(
              id: a['id'].toString(),
              title: (a['title'] ?? '') as String,
              snippet:
                  '${a['category_name'] ?? ''} • ${widget.formatDistance(a['distance_km'] as num?)}'
                      .trim(),
              latLng: LatLng(
                  (a['lat'] as num).toDouble(), (a['lng'] as num).toDouble()),
              onTap: () => widget.onMarkerTap(a),
            ))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _manager = _initManager(_buildPlaces());
  }

  @override
  void didUpdateWidget(covariant ClusteredActivitiesMap old) {
    super.didUpdateWidget(old);
    if (old.activities != widget.activities) {
      _manager.setItems(_buildPlaces());
    }
  }

  ClusterManager _initManager(List<_ActivityPlace> places) {
    return ClusterManager<_ActivityPlace>(
      places,
      (markers) {
        if (!mounted) return;
        setState(() => _markers = markers);
      },
      markerBuilder: _markerBuilder,
      stopClusteringZoom: 15,
    );
  }

  Future<Marker> Function(Cluster<_ActivityPlace>) get _markerBuilder =>
      (cluster) async {
        if (cluster.isMultiple) {
          final icon = await _clusterBitmap(cluster.count);
          return Marker(
            markerId: MarkerId('cluster_${cluster.location.latitude}_${cluster.location.longitude}_${cluster.count}'),
            position: cluster.location,
            icon: icon,
            onTap: () async {
              final ctrl = _controller;
              if (ctrl == null) return;
              await ctrl.animateCamera(
                CameraUpdate.newLatLngZoom(cluster.location,
                    await ctrl.getZoomLevel() + 2),
              );
            },
          );
        }
        final p = cluster.items.first;
        return Marker(
          markerId: MarkerId(p.id),
          position: p.latLng,
          infoWindow: InfoWindow(title: p.title, snippet: p.snippet),
          onTap: p.onTap,
        );
      };

  Future<BitmapDescriptor> _clusterBitmap(int count) async {
    final size = count < 10
        ? 80.0
        : count < 100
            ? 100.0
            : 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFF673AB7);
    final ringPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 4, paint);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 4, ringPaint);
    final tp = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size - tp.width) / 2, (size - tp.height) / 2),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.bytes(Uint8List.fromList(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition:
          CameraPosition(target: widget.initialCenter, zoom: 12),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onMapCreated: (controller) {
        _controller = controller;
        _manager.setMapId(controller.mapId);
        if (!_ready.isCompleted) _ready.complete();
      },
      onCameraMove: _manager.onCameraMove,
      onCameraIdle: _manager.updateMap,
    );
  }
}
