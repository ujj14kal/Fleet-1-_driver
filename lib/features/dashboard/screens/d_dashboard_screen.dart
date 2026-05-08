import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/driver_service.dart';
import '../../../core/services/location_service.dart';
import '../../map/screens/live_map_screen.dart';

class DDashboardScreen extends StatefulWidget {
  const DDashboardScreen({super.key});

  @override
  State<DDashboardScreen> createState() => _DDashboardScreenState();
}

class _DDashboardScreenState extends State<DDashboardScreen> {
  final _picker = ImagePicker();

  bool _isLicenseUploaded = true;
  bool _isLoading = true;
  bool _isUploadingLicense = false;
  String? _driverId;
  String? _driverPhone;
  Map<String, dynamic>? _driverProfile;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final profile = await DriverService.getDriverProfile();
    if (mounted) {
      setState(() {
        _driverProfile = profile;
        _isLicenseUploaded = profile?['is_license_uploaded'] ?? false;
        _driverId = profile?['id'] as String?;
        _driverPhone = profile?['phone'] as String?;
        _isLoading = false;
      });
    }
  }

  Future<void> _captureLicensePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review license photo'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(picked.path), fit: BoxFit.cover),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Retake'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (shouldUpload != true || !mounted) return;
    setState(() => _isUploadingLicense = true);
    try {
      await DriverService.uploadLicensePhotos([File(picked.path)]);
      await _checkProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('License photo uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not upload license: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingLicense = false);
    }
  }

  Future<String?> _askForReceiverPhone({String? initialPhone}) async {
    final phoneCtrl = TextEditingController(text: initialPhone ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receiver phone'),
        content: TextField(
          controller: phoneCtrl,
          decoration: const InputDecoration(labelText: 'Receiver phone'),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(phoneCtrl.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    phoneCtrl.dispose();
    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  Future<void> _startDelivery(Map<String, dynamic> shipment) async {
    final user = Supabase.instance.client.auth.currentUser;
    final shipmentId = _shipmentId(shipment);
    if (user == null || shipmentId.isEmpty) return;

    final savedPhone = shipment['receiver_phone']?.toString().trim() ?? '';
    final receiverPhone = savedPhone.isNotEmpty
        ? savedPhone
        : await _askForReceiverPhone();
    if (receiverPhone == null || receiverPhone.isEmpty) return;

    final session = await LocationService.startDeliverySession(
      shipmentId: shipmentId,
      driverId: user.id,
      receiverPhone: receiverPhone,
      otpRequired: false,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          session == null
              ? 'Delivery start saved where permitted. Check database policies if it does not sync.'
              : 'Delivery started',
        ),
      ),
    );
  }

  Future<void> _endDelivery(Map<String, dynamic> shipment) async {
    final user = Supabase.instance.client.auth.currentUser;
    final shipmentId = _shipmentId(shipment);
    if (user == null || shipmentId.isEmpty) return;

    final savedPhone = shipment['receiver_phone']?.toString().trim() ?? '';
    final receiverPhone = savedPhone.isNotEmpty
        ? savedPhone
        : await _askForReceiverPhone();
    if (receiverPhone == null || receiverPhone.isEmpty) return;

    try {
      await LocationService.requestCompletionOtp(
        shipmentId: shipmentId,
        driverId: user.id,
        receiverPhone: receiverPhone,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create delivery OTP: $e')),
      );
      return;
    }

    if (!mounted) return;
    final otpCtrl = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receiver OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OTP sent to ${_maskedPhone(receiverPhone)}.'),
            const SizedBox(height: 12),
            TextField(
              controller: otpCtrl,
              decoration: const InputDecoration(labelText: 'Enter OTP'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(otpCtrl.text.trim()),
            child: const Text('End Ride'),
          ),
        ],
      ),
    );
    otpCtrl.dispose();

    if (otp == null || otp.isEmpty) return;
    final ok = await LocationService.completeDeliveryWithOtp(
      shipmentId: shipmentId,
      driverId: user.id,
      otp: otp,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Delivery marked delivered'
              : 'Invalid OTP. Delivery was not completed.',
        ),
      ),
    );
  }

  void _showProfile() {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = _driverProfile ?? {};
    final photos = List<String>.from(
      (profile['license_photos'] as List?) ?? const [],
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            Text(
              'Driver Profile',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 16),
            _ProfileRow(label: 'Name', value: _driverName),
            _ProfileRow(label: 'Email', value: user?.email ?? '-'),
            _ProfileRow(label: 'Phone', value: profile['phone']?.toString()),
            _ProfileRow(label: 'Age', value: profile['age']?.toString()),
            _ProfileRow(
              label: 'License',
              value: _isLicenseUploaded ? 'Uploaded' : 'Pending',
            ),
            if (photos.isNotEmpty)
              _ProfileRow(label: 'License photos', value: '${photos.length}'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isUploadingLicense
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      _captureLicensePhoto();
                    },
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Add License Photo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_fleet1.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            const Text('Driver Dashboard'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_rounded),
            onPressed: _showProfile,
          ),
          IconButton(
            tooltip: 'Location help',
            icon: const Icon(Icons.location_on),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Use the buttons on assignments to start/stop delivery and share location.',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GreetingCard(name: _driverName, greeting: _timeGreeting),
            const SizedBox(height: 16),
            if (!_isLicenseUploaded)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  border: Border.all(color: AppColors.amberBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.primaryAmber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Action Recommended',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryNavy,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please upload your driving license photos for account verification.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isUploadingLicense
                          ? null
                          : _captureLicensePhoto,
                      icon: _isUploadingLicense
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_rounded),
                      label: const Text('Upload'),
                    ),
                  ],
                ),
              ),
            Text(
              'New Assignments',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _driverId == null
                  ? const Stream.empty()
                  : DriverService.streamAssignedShipments(
                      _driverId!,
                      driverPhone: _driverPhone,
                    ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Text('Error fetching assignments: ${snapshot.error}');
                }

                final assignedRides = snapshot.data ?? [];
                if (assignedRides.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No assigned rides at the moment.'),
                    ),
                  );
                }

                return Column(
                  children: assignedRides.map((ride) {
                    final shipment = Map<String, dynamic>.from(
                      (ride['shipment'] as Map?) ?? ride,
                    );
                    return _AssignmentCard(
                      shipment: shipment,
                      onStart: () => _startDelivery(shipment),
                      onEnd: () => _endDelivery(shipment),
                      onOpenMap: () => _openLiveMap(shipment),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLiveMap(Map<String, dynamic> shipment) async {
    final phoneCtrl = TextEditingController(
      text: shipment['receiver_phone']?.toString() ?? '',
    );
    final otpCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Live Map'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Receiver phone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: otpCtrl,
              decoration: const InputDecoration(labelText: 'OTP (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    final phone = phoneCtrl.text.trim();
    final otp = otpCtrl.text.trim();
    phoneCtrl.dispose();
    otpCtrl.dispose();
    if (ok == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveMapScreen(
            receiverPhone: phone,
            otp: otp.isEmpty ? null : otp,
          ),
        ),
      );
    }
  }

  String get _driverName {
    final name = _driverProfile?['full_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return email.contains('@') ? email.split('@').first : 'Driver';
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _shipmentId(Map<String, dynamic> shipment) =>
      shipment['id']?.toString() ?? shipment['shipment_id']?.toString() ?? '';

  static String _maskedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return phone;
    return '${digits.substring(0, 2)}******${digits.substring(digits.length - 2)}';
  }
}

class _GreetingCard extends StatelessWidget {
  final String name;
  final String greeting;

  const _GreetingCard({required this.name, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting,',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> shipment;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onOpenMap;

  const _AssignmentCard({
    required this.shipment,
    required this.onStart,
    required this.onEnd,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final shipmentId =
        shipment['id']?.toString() ?? shipment['shipment_id']?.toString() ?? '';
    final trackingNumber =
        shipment['tracking_number']?.toString() ??
        shipment['shipment_code']?.toString() ??
        (shipmentId.isEmpty
            ? 'Unknown shipment'
            : shipmentId
                  .substring(0, shipmentId.length < 8 ? shipmentId.length : 8)
                  .toUpperCase());
    final pickup =
        shipment['pickup_location']?.toString() ??
        shipment['pickup_address']?.toString() ??
        shipment['pickup_city']?.toString() ??
        'Pending';
    final drop =
        shipment['drop_location']?.toString() ??
        shipment['receiver_address']?.toString() ??
        shipment['receiver_city']?.toString() ??
        'Pending';
    final status = shipment['status']?.toString() ?? 'assigned';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trackingNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryAmber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.circle,
                  size: 12,
                  color: AppColors.supportGreen,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Pickup: $pickup')),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(left: 5),
              height: 20,
              width: 2,
              color: AppColors.border,
            ),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 12,
                  color: AppColors.secondaryRed,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Drop: $drop')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Accept Ride'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: shipmentId.isEmpty ? null : onStart,
                    child: const Text('Start Delivery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: shipmentId.isEmpty ? null : onEnd,
                    child: const Text('End Ride'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onOpenMap,
                    child: const Text('View Live Map'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String? value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final displayValue = value?.trim().isNotEmpty == true ? value!.trim() : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(displayValue)),
        ],
      ),
    );
  }
}
