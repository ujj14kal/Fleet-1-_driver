import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/driver_service.dart';
import '../../../core/services/auth_service.dart';

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
        title: const Text('Driver Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
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
                                      // Decline logic
                                    },
                                    child: const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Accept logic
                                    },
                                    child: const Text('Accept Ride'),
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
