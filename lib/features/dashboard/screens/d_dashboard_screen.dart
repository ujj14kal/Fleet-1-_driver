import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/driver_service.dart';
import '../../../core/services/location_service.dart';

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

  Future<void> _startDelivery(Map<String, dynamic> shipment) async {
    final user = Supabase.instance.client.auth.currentUser;
    final shipmentId = _shipmentId(shipment);
    if (user == null || shipmentId.isEmpty) return;

    await LocationService.startDeliverySession(
      shipmentId: shipmentId,
      driverId: user.id,
      receiverPhone: shipment['receiver_phone']?.toString().trim() ?? '',
      otpRequired: false,
    );

    final opened = await _openGoogleMapsRoute(shipment);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Ride started in Google Maps'
              : 'Ride started, but no route could be opened from this shipment location data.',
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final profile = _driverProfile ?? {};
    final canEdit = DriverService.canEditProfile(profile);
    if (!canEdit) {
      final wait = DriverService.profileEditWait(profile);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile can be edited again in ${wait.inHours}h ${wait.inMinutes.remainder(60)}m.',
          ),
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: _driverName);
    final phoneCtrl = TextEditingController(
      text: profile['phone']?.toString() ?? '',
    );
    final ageCtrl = TextEditingController(
      text: profile['age']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter phone'
                    : null,
              ),
              TextFormField(
                controller: ageCtrl,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final age = int.tryParse(value ?? '');
                  if (age == null || age < 18) return 'Enter valid age';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (shouldSave == true) {
      try {
        await DriverService.updateProfile(
          fullName: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          age: int.parse(ageCtrl.text.trim()),
        );
        await _checkProfile();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update profile: $e')));
      }
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
    ageCtrl.dispose();
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
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _editProfile();
              },
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit Profile'),
            ),
            const SizedBox(height: 8),
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

  Future<bool> _openGoogleMapsRoute(Map<String, dynamic> shipment) async {
    final origin = _mapsPoint(
      shipment,
      const [
        ['pickup_latitude', 'pickup_longitude'],
        ['pickup_lat', 'pickup_lng'],
        ['pickup_lat', 'pickup_long'],
        ['origin_latitude', 'origin_longitude'],
      ],
      ['pickup_location', 'pickup_address', 'pickup_city'],
    );
    final destination = _mapsPoint(
      shipment,
      const [
        ['receiver_latitude', 'receiver_longitude'],
        ['receiver_lat', 'receiver_lng'],
        ['drop_latitude', 'drop_longitude'],
        ['drop_lat', 'drop_lng'],
        ['destination_latitude', 'destination_longitude'],
      ],
      ['drop_location', 'receiver_address', 'receiver_city'],
    );

    if (origin == null || destination == null) return false;

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': origin,
      'destination': destination,
      'travelmode': 'driving',
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
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

  static String? _mapsPoint(
    Map<String, dynamic> shipment,
    List<List<String>> coordinateKeys,
    List<String> textKeys,
  ) {
    for (final pair in coordinateKeys) {
      final lat = num.tryParse(shipment[pair[0]]?.toString() ?? '');
      final lng = num.tryParse(shipment[pair[1]]?.toString() ?? '');
      if (lat != null && lng != null) return '$lat,$lng';
    }

    final parts = textKeys
        .map((key) => shipment[key]?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty && value.toLowerCase() != 'null')
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
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

  const _AssignmentCard({required this.shipment, required this.onStart});

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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: shipmentId.isEmpty ? null : onStart,
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Start Ride'),
              ),
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
