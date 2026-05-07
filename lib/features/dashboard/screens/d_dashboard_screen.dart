import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/driver_service.dart';
import '../../../core/services/auth_service.dart';
import '../../map/screens/live_map_screen.dart';
import '../../../core/services/location_service.dart';

class DDashboardScreen extends StatefulWidget {
  const DDashboardScreen({super.key});

  @override
  State<DDashboardScreen> createState() => _DDashboardScreenState();
}

class _DDashboardScreenState extends State<DDashboardScreen> {
  bool _isLicenseUploaded = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final profile = await DriverService.getDriverProfile();
    if (mounted) {
      setState(() {
        _isLicenseUploaded = profile?['is_license_uploaded'] ?? false;
        _isLoading = false;
      });
    }
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
            icon: const Icon(Icons.location_on),
            onPressed: () {
              // Quick hint: location sharing is managed per-assignment below.
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Use the buttons on assignments to start/stop delivery and share location.'),
                duration: Duration(seconds: 2),
              ));
            },
          ),
          IconButton(
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
                    const Icon(Icons.warning_amber_rounded, color: AppColors.primaryAmber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Action Recommended',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to license upload page
                      },
                      child: const Text('Upload'),
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
              stream: DriverService.listenToAssignments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ));
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
                    final shipment = ride['shipment'] ?? {};
                    final shipmentId = shipment['id']?.toString() ?? shipment['shipment_id']?.toString() ?? '';
                    final trackingNumber = shipment['tracking_number'] ?? 'Unknown Tracking #';
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
                                Text(
                                  shipment['tracking_number'] ?? 'Unknown Tracking #',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryAmber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(color: AppColors.primaryAmber, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.circle, size: 12, color: AppColors.supportGreen),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Pickup: ${shipment['pickup_location'] ?? 'Pending'}')),
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
                                const Icon(Icons.location_on, size: 12, color: AppColors.secondaryRed),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Drop: ${shipment['drop_location'] ?? 'Pending'}')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      // Decline logic (keeps existing behaviour)
                                    },
                                    child: const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Accept logic (existing)
                                    },
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
                                    onPressed: shipmentId.isEmpty
                                        ? null
                                        : () async {
                                            // Start delivery session: ask for receiver phone and optional OTP
                                            final phoneCtrl = TextEditingController();
                                            final otpCtrl = TextEditingController();
                                            final result = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Start Delivery'),
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
                                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      final driver = Supabase.instance.client.auth.currentUser;
                                                      if (driver == null) {
                                                        Navigator.of(ctx).pop(false);
                                                        return;
                                                      }
                                                      await LocationService.startDeliverySession(
                                                        shipmentId: shipmentId,
                                                        driverId: driver.id,
                                                        receiverPhone: phoneCtrl.text.trim(),
                                                        otp: otpCtrl.text.trim().isEmpty ? null : otpCtrl.text.trim(),
                                                        otpRequired: otpCtrl.text.trim().isNotEmpty,
                                                      );
                                                      Navigator.of(ctx).pop(true);
                                                    },
                                                    child: const Text('Start'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (result == true) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery started')));
                                            }
                                          },
                                    child: const Text('Start Delivery'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: shipmentId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await LocationService.completeDeliveryByShipment(shipmentId: shipmentId);
                                            if (ok) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery marked complete')));
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not complete delivery (check DB)')));
                                            }
                                          },
                                    child: const Text('Complete Delivery'),
                                  ),
                                ),
                              ],
                            ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () async {
                                          // Open Live Map viewer for this shipment; ask for receiver phone/otp
                                          final phoneCtrl = TextEditingController();
                                          final otpCtrl = TextEditingController();
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Open Live Map'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Receiver phone'), keyboardType: TextInputType.phone),
                                                  TextField(controller: otpCtrl, decoration: const InputDecoration(labelText: 'OTP (optional)')),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.of(ctx).pop(true),
                                                  child: const Text('Open'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveMapScreen(receiverPhone: phoneCtrl.text.trim(), otp: otpCtrl.text.trim().isEmpty ? null : otpCtrl.text.trim())));
                                          }
                                        },
                                        child: const Text('View Live Map'),
                                      ),
                                    ),
                                  ],
                                ),
                          ],
                        ),
                      ),
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
}
