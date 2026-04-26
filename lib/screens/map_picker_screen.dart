import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../l10n/app_localizations.dart';

typedef MapPickerResult = ({LatLng location, String? suggestedName});

class _PlaceSuggestion {
  final LatLng latLng;
  final String label;
  const _PlaceSuggestion(this.latLng, this.label);
}

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _defaultLocation = LatLng(41.0082, 29.0234);

  GoogleMapController? _mapController;
  LatLng _selectedLocation = _defaultLocation;
  String? _selectedName;
  bool _locating = false;
  bool _searching = false;
  final _searchController = TextEditingController();
  List<_PlaceSuggestion> _suggestions = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    }
    _reverseGeocode(_selectedLocation);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.name, p.subLocality, p.locality]
            .where((s) => s != null && s.isNotEmpty).toSet().toList();
        if (mounted) setState(() => _selectedName = parts.join(', '));
      }
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () => _searchPlace(q));
  }

  Future<void> _searchPlace([String? override]) async {
    final query = (override ?? _searchController.text).trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(query)}'
        '&format=json&addressdetails=1&limit=8&accept-language=tr,en',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': 'HadiApp/1.0 (hadi.app)'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final list = jsonDecode(resp.body) as List;
      final results = list.map((e) {
        final m = e as Map<String, dynamic>;
        final lat = double.tryParse(m['lat']?.toString() ?? '') ?? 0;
        final lon = double.tryParse(m['lon']?.toString() ?? '') ?? 0;
        final label = (m['display_name'] as String?) ?? query;
        return _PlaceSuggestion(LatLng(lat, lon), label);
      }).toList();
      if (mounted) {
        setState(() => _suggestions = results);
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).placeNotFound)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).searchError}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickSuggestion(_PlaceSuggestion s) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedLocation = s.latLng;
      _selectedName = s.label;
      _suggestions = [];
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(s.latLng, 15));
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).locationPermissionDeniedForever)),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() => _selectedLocation = latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _reverseGeocode(latLng);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).locationFetchFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      _suggestions = [];
    });
    _reverseGeocode(latLng);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pickLocationTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop<MapPickerResult>(
              (location: _selectedLocation, suggestedName: _selectedName),
            ),
            child: Text(l.pickLocationSelect, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 13),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            markers: {
              Marker(markerId: const MarkerId('selected'), position: _selectedLocation),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchPlace(),
                    decoration: InputDecoration(
                      hintText: l.searchPlaceHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _searchPlace,
                            ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _suggestions = []);
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      setState(() {});
                      _onSearchChanged(v);
                    },
                  ),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, size: 20),
                            title: Text(s.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${s.latLng.latitude.toStringAsFixed(4)}, ${s.latLng.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () => _pickSuggestion(s),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              onPressed: _locating ? null : _goToCurrentLocation,
              child: _locating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
