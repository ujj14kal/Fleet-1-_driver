import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverService {
  static final _client = Supabase.instance.client;

  // Fetch assigned shipments for a driver (one-time)
  static Future<List<Map<String, dynamic>>> fetchAssignedShipments(String driverId) async {
    try {
      final data = await _client.from('shipments').select().eq('driver_id', driverId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  // Stream assigned shipments for a driver (realtime)
  static Stream<List<Map<String, dynamic>>> streamAssignedShipments(String driverId) {
    if (driverId.isEmpty) return const Stream.empty();
    return _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  // Stream driver notifications for a driver (realtime)
  static Stream<List<Map<String, dynamic>>> streamDriverNotifications(String driverId) {
    if (driverId.isEmpty) return const Stream.empty();
    return _client
        .from('driver_notifications')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  // Save or update device token for push notifications
  static Future<void> saveDeviceToken(String driverId, String deviceToken) async {
    try {
      await _client.from('drivers').update({'device_token': deviceToken}).eq('id', driverId);
    } catch (_) {
      // ignore
    }
  }

  static Future<void> completeOnboarding({
    required String fullName,
    required String phone,
    required int age,
    required List<File> licensePhotos,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    List<String> photoUrls = [];
    
    // Upload photos if any
    for (int i = 0; i < licensePhotos.length; i++) {
      final file = licensePhotos[i];
      final ext = file.path.split('.').last;
      final fileName = '${user.id}/license_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      
      await _client.storage.from('driver_documents').upload(fileName, file);
      final url = _client.storage.from('driver_documents').getPublicUrl(fileName);
      photoUrls.add(url);
    }

    // Insert driver record
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

  // Stream for new shipment assignments
  static Stream<List<Map<String, dynamic>>> listenToAssignments() {
    final user = _client.auth.currentUser;
    if (user == null) return const Stream.empty();

    // In a real scenario, you'd listen to shipment_assignments where driver_id = user.id
    // and join with shipments table to get details. 
    // Since Supabase Realtime doesn't support joins natively in the stream, 
    // we listen to assignments and then fetch the shipment details.
    
    return _client
        .from('shipment_assignments')
        .stream(primaryKey: ['id'])
        .eq('driver_id', user.id)
        .asyncMap((assignments) async {
          if (assignments.isEmpty) return [];
          
          final shipmentIds = assignments.map((a) => a['shipment_id']).toList();
          final shipments = await _client
              .from('shipments')
              .select('*')
              .inFilter('id', shipmentIds);
              
          // Combine assignment data with shipment data
          return assignments.map((assignment) {
            final shipment = shipments.firstWhere(
              (s) => s['id'] == assignment['shipment_id'], 
              orElse: () => {},
            );
            return {
              ...assignment,
              'shipment': shipment,
            };
          }).toList();
        });
  }
}
