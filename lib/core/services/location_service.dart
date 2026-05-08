import 'dart:math';

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
    String receiverPhone = '',
    String? otp,
    bool otpRequired = true,
  }) async {
    try {
      final res = await _client
          .from('delivery_sessions')
          .insert({
            'shipment_id': shipmentId,
            'driver_id': driverId,
            'receiver_phone': receiverPhone,
            'otp': otp,
            'otp_required': otpRequired,
            'started_at': DateTime.now().toUtc().toIso8601String(),
            'is_active': true,
          })
          .select()
          .maybeSingle();
      await _client
          .from('shipments')
          .update({
            'status': 'in_transit_to_receiver',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', shipmentId);
      if (res is Map<String, dynamic>) return res;
    } catch (e) {
      // ignore; table might not exist yet or policies may block
    }
    return null;
  }

  static Future<String> requestCompletionOtp({
    required String shipmentId,
    required String driverId,
    required String receiverPhone,
  }) async {
    final otp = (100000 + Random.secure().nextInt(900000)).toString();
    final now = DateTime.now().toUtc().toIso8601String();

    final existing = await _client
        .from('delivery_sessions')
        .select('id')
        .eq('shipment_id', shipmentId)
        .eq('driver_id', driverId)
        .eq('is_active', true)
        .maybeSingle();

    if (existing == null) {
      await _client.from('delivery_sessions').insert({
        'shipment_id': shipmentId,
        'driver_id': driverId,
        'receiver_phone': receiverPhone,
        'otp': otp,
        'otp_required': true,
        'started_at': now,
        'is_active': true,
      });
    } else {
      await _client
          .from('delivery_sessions')
          .update({
            'receiver_phone': receiverPhone,
            'otp': otp,
            'otp_required': true,
          })
          .eq('id', existing['id']);
    }

    try {
      await _client.functions.invoke(
        'send-delivery-otp',
        body: {
          'shipment_id': shipmentId,
          'receiver_phone': receiverPhone,
          'otp': otp,
        },
      );
    } catch (_) {
      // SMS delivery is handled by the project edge function when configured.
    }

    return otp;
  }

  static Future<bool> completeDeliveryWithOtp({
    required String shipmentId,
    required String driverId,
    required String otp,
  }) async {
    try {
      final session = await _client
          .from('delivery_sessions')
          .select('id, otp')
          .eq('shipment_id', shipmentId)
          .eq('driver_id', driverId)
          .eq('is_active', true)
          .maybeSingle();

      if (session == null || session['otp']?.toString() != otp.trim()) {
        return false;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('delivery_sessions')
          .update({'completed_at': now, 'is_active': false})
          .eq('id', session['id']);

      await _client.from('shipment_status_updates').insert({
        'shipment_id': shipmentId,
        'updated_by': driverId,
        'status': 'delivered',
        'note': 'Marked delivered by driver after receiver OTP verification',
      });

      await _client
          .from('shipments')
          .update({'status': 'delivered', 'updated_at': now})
          .eq('id', shipmentId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Marks delivery session(s) for a shipment as completed.
  static Future<bool> completeDeliveryByShipment({
    required String shipmentId,
  }) async {
    try {
      await _client
          .from('delivery_sessions')
          .update({
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'is_active': false,
          })
          .eq('shipment_id', shipmentId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
