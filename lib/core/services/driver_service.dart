import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverService {
  static final _client = Supabase.instance.client;

  /// One-time fetch of all shipments assigned to this driver.
  static Future<List<Map<String, dynamic>>> fetchAssignedShipments(
    String driverId, {
    String? driverPhone,
  }) async {
    try {
      final data = await _client
          .from('shipments')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List)
          .where((shipment) => _matchesDriver(shipment, driverId, driverPhone))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Realtime stream of shipments assigned by driver_id, with phone fallback.
  static Stream<List<Map<String, dynamic>>> streamAssignedShipments(
    String driverId, {
    String? driverPhone,
  }) {
    if (driverId.isEmpty) return const Stream.empty();
    return _client
        .from('shipments')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (rows) => List<Map<String, dynamic>>.from(rows)
              .where(
                (shipment) => _matchesDriver(shipment, driverId, driverPhone),
              )
              .toList(),
        );
  }

  /// Save/update device token for push notifications
  static Future<void> saveDeviceToken(
    String driverId,
    String deviceToken,
  ) async {
    try {
      await _client
          .from('drivers')
          .update({'device_token': deviceToken})
          .eq('id', driverId);
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

    final photoUrls = await _uploadLicensePhotos(user.id, licensePhotos);

    await _client.from('drivers').upsert({
      'id': user.id,
      'full_name': fullName,
      'phone': phone,
      'age': age,
      'license_photos': photoUrls,
      'is_license_uploaded': photoUrls.isNotEmpty,
    });
  }

  static Future<void> uploadLicensePhotos(List<File> licensePhotos) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    if (licensePhotos.isEmpty) return;

    final existing = await getDriverProfile();
    final currentPhotos = List<String>.from(
      (existing?['license_photos'] as List?) ?? const [],
    );
    final newPhotos = await _uploadLicensePhotos(user.id, licensePhotos);

    await _client.from('drivers').upsert({
      'id': user.id,
      'license_photos': [...currentPhotos, ...newPhotos],
      'is_license_uploaded': true,
    });
  }

  static Future<Map<String, dynamic>?> getDriverProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return await _client
        .from('drivers')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  static bool _matchesDriver(
    Map<String, dynamic> shipment,
    String driverId,
    String? driverPhone,
  ) {
    final shipmentDriverId = shipment['driver_id']?.toString() ?? '';
    if (shipmentDriverId == driverId) return true;

    final phone = _digitsOnly(driverPhone ?? '');
    final shipmentPhone = _digitsOnly(
      shipment['driver_phone']?.toString() ?? '',
    );
    return phone.isNotEmpty && shipmentPhone == phone;
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static Future<List<String>> _uploadLicensePhotos(
    String userId,
    List<File> licensePhotos,
  ) async {
    final List<String> photoUrls = [];
    for (int i = 0; i < licensePhotos.length; i++) {
      final file = licensePhotos[i];
      final ext = file.path.split('.').last.toLowerCase();
      final fileName =
          '$userId/license_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      await _client.storage.from('driver_documents').upload(fileName, file);
      final url = _client.storage
          .from('driver_documents')
          .getPublicUrl(fileName);
      photoUrls.add(url);
    }
    return photoUrls;
  }
}
