import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveMapScreen extends StatefulWidget {
  final String receiverPhone;
  final String? otp;
  const LiveMapScreen({super.key, required this.receiverPhone, this.otp});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  GoogleMapController? _controller;
  final Map<MarkerId, Marker> _markers = {};
  Timer? _pollTimer;

  static const _placeholderApiKeyNotice =
      'Add your Google Maps API key in platform config; map may not render in simulator.';

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startPolling() {
    // Try immediately then every 5 seconds
    _fetchLocations();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchLocations());
  }

  Future<void> _fetchLocations() async {
    try {
      // DB access via Supabase RPC is optional and may not be available in every
      // environment. For build validation we skip DB reads here. When you run
      // the SQL migration `sql/001_add_live_location_and_sessions.sql` on
      // Supabase, replace this block with an RPC call to
      // `rpc_get_live_locations_by_phone` or a select from `driver_locations`.
      final List locations = [];
      _updateMarkers(locations);
    } catch (e) {
      // ignore errors; show nothing
    }
  }

  void _updateMarkers(List locations) {
    final newMarkers = <MarkerId, Marker>{};
    for (var loc in locations) {
      final driverId = (loc['driver_id'] ?? loc['driver'])?.toString() ?? 'unknown';
      final lat = (loc['latitude'] ?? loc['lat']) as num?;
      final lng = (loc['longitude'] ?? loc['lng']) as num?;
      final recordedAt = loc['recorded_at']?.toString() ?? '';
      if (lat == null || lng == null) continue;
      final id = MarkerId(driverId);
      newMarkers[id] = Marker(
        markerId: id,
        position: LatLng(lat.toDouble(), lng.toDouble()),
        infoWindow: InfoWindow(title: 'Driver $driverId', snippet: recordedAt),
      );
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Map')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_placeholderApiKeyNotice, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 4),
              markers: Set<Marker>.of(_markers.values),
              onMapCreated: (c) => _controller = c,
            ),
          ),
        ],
      ),
    );
  }
}
