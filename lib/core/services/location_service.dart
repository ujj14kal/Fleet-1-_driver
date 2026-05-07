import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  static final _client = Supabase.instance.client;

  /// Inserts a driver location point into `driver_locations`.
  /// This is additive and wrapped in try/catch by callers.
  static Future<void> sendLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) async {
    try {
      await _client.from('driver_locations').insert({
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading,
        'speed': speed,
      });
    } catch (e) {
      // swallow errors to avoid breaking existing logic; callers may log
    }
  }

  /// Starts a delivery session for a shipment. Returns inserted row (if available).
  static Future<Map<String, dynamic>?> startDeliverySession({
    required String shipmentId,
    required String driverId,
    required String receiverPhone,
    String? otp,
    bool otpRequired = true,
  }) async {
    try {
      final res = await _client.from('delivery_sessions').insert({
        'shipment_id': shipmentId,
        'driver_id': driverId,
        'receiver_phone': receiverPhone,
        'otp': otp,
        'otp_required': otpRequired,
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'is_active': true,
      }).select().maybeSingle();
      if (res is Map<String, dynamic>) return res;
    } catch (e) {
      // ignore; table might not exist yet or policies may block
    }
    return null;
  }

  /// Marks delivery session(s) for a shipment as completed.
  static Future<bool> completeDeliveryByShipment({required String shipmentId}) async {
    try {
      await _client.from('delivery_sessions').update({
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'is_active': false,
      }).eq('shipment_id', shipmentId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
