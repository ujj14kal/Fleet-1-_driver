import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverService {
  static final _client = Supabase.instance.client;

  /// One-time fetch of all shipments assigned to this driver (by driver_id column)
  static Future<List<Map<String, dynamic>>> fetchAssignedShipments(String driverId) async {
    try {
      final data = await _client
          .from('shipments')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  /// Realtime stream of shipments where driver_id = driverId
  static Stream<List<Map<String, dynamic>>> streamAssignedShipments(String driverId) {
    if (driverId.isEmpty) return const Stream.empty();
    return _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  /// Realtime stream of driver_notifications for this driver
  static Stream<List<Map<String, dynamic>>> streamDriverNotifications(String driverId) {
    if (driverId.isEmpty) return const Stream.empty();
    return _client
        .from('driver_notifications')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  /// Save/update device token for push notifications
  static Future<void> saveDeviceToken(String driverId, String deviceToken) async {
    try {
      await _client.from('drivers').update({'device_token': deviceToken}).eq('id', driverId);
    } catch (_) {}
  }

  static Future<void> completeOnboarding({
    required String fullName,
    required String phone,
    required int age,
    required List<File> licensePhotos,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final List<String> photoUrls = [];
    for (int i = 0; i < licensePhotos.length; i++) {
      final file = licensePhotos[i];
      final ext = file.path.split('.').last;
      final fileName = '${user.id}/license_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      await _client.storage.from('driver_documents').upload(fileName, file);
      final url = _client.storage.from('driver_documents').getPublicUrl(fileName);
      photoUrls.add(url);
    }

    await _client.from('drivers').upsert({
      'id': user.id,
      'full_name': fullName,
      'phone': phone,
      'age': age,
      'license_photos': photoUrls,
      'is_license_uploaded': photoUrls.isNotEmpty,
    });
  }

  static Future<Map<String, dynamic>?> getDriverProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return await _client.from('drivers').select().eq('id', user.id).maybeSingle();
  }
}