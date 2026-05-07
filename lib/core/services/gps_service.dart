import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_service.dart';

class GPSService {
  StreamSubscription<Position>? _posSub;

  Future<bool> _ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Start streaming device GPS positions and send to `driver_locations` via `LocationService`.
  /// Non-blocking and swallows errors to avoid breaking existing flows.
  Future<void> startSending(String driverId) async {
    try {
      final ok = await _ensurePermission();
      if (!ok) return;

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen((pos) async {
        try {
          await LocationService.sendLocation(
            driverId: driverId,
            latitude: pos.latitude,
            longitude: pos.longitude,
            heading: pos.heading,
            speed: pos.speed,
          );
        } catch (_) {}
      });
    } catch (_) {}
  }

  Future<void> stopSending() async {
    await _posSub?.cancel();
    _posSub = null;
  }
}
