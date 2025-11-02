import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_device_screen.dart';
import 'device_info_screen.dart';
import 'drawer.dart';
import 'user_profile_screen.dart';
import 'user_notifications_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final List<Map<String, String>>? initialRooms;
  const DashboardScreen({Key? key, this.initialRooms}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final String? userId = AuthService().getUserUID();
  int _selectedIndex = 0; // For bottom navigation

  // Bottom navigation pages
  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Get the current screen based on selected index
  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const UserNotificationsScreen();
      case 2:
        return _buildDevicesContent();
      case 3:
        return const UserProfileScreen();
      default:
        return _buildDashboardContent();
    }
  }

  // Build devices content (same as current dashboard content)
  Widget _buildDevicesContent() {
    return _buildDashboardContent();
  }

  // Single timestamp formatting method
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Firestore stream for real-time device updates with server-side ordering
  Stream<QuerySnapshot> get devicesStream {
    final uid = _authService.getUserUID();
    print('Dashboard: Fetching devices for user ID: $uid'); // Debug log

    if (uid == null) {
      print('Dashboard: No user ID found, returning empty stream');
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('devices')
        .where('assignedUserId', isEqualTo: uid)
        .orderBy('created_at', descending: true) // Server-side ordering with composite index
        .snapshots();
  }

  // Manual refresh function for real-time updates
  Future<void> _refreshDevices() async {
    if (mounted) {
      setState(() {
        // This will trigger a rebuild and refresh the stream
      });

      // Show feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devices refreshed'),
          backgroundColor: Color(0xFFE7FF76),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // Delete device function with confirmation
  Future<void> _deleteDevice(String deviceId, String roomName) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Device'),
          content: Text('Are you sure you want to delete the device in "$roomName"?\n\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        final userId = _authService.getUserUID();

        // Delete device from devices collection
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .delete();

        // Decrement user's device count using FirestoreService
        if (userId != null) {
          await _firestoreService.decrementUserDeviceCount(userId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device "$roomName" deleted successfully'),
              backgroundColor: const Color(0xFFE7FF76),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Delete error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete device: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Logout error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build dashboard content
  Widget _buildDashboardContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF126E35),
            Color(0xFF0BBD35),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Debug info and Role Upgrade Section
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  const Text(
                    '🔍 Debug Info',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Email: ${_authService.getUserEmail() ?? "Unknown"}',
                    style: const TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                  Text(
                    'Should be Super Admin: ${_authService.shouldBeSuperAdmin}',
                    style: const TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                  Text(
                    'UID: ${_authService.getUserUID() ?? "Unknown"}',
                    style: const TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refreshDevices,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE7FF76),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Refresh Devices'),
                  ),
                ],
              ),
            ),
            // Role Upgrade Section for existing super admin users
            if (_authService.shouldBeSuperAdmin)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🔑 Super Admin Access Available',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your email suggests you should have super admin privileges. Click below to upgrade your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await _authService.setUserRole(
                            _authService.getUserUID() ?? '',
                            'super_admin',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Role upgraded! Please restart the app.'),
                              backgroundColor: Color(0xFFE7FF76),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to upgrade role: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE7FF76),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Upgrade to Super Admin'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: devicesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading devices: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_other,
                            color: Colors.black,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add your first device using the + button',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  }

                  final devices = snapshot.data!.docs;

                  return RefreshIndicator(
                    onRefresh: _refreshDevices,
                    color: Colors.white,
                    backgroundColor: const Color(0xFF126E35),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final deviceDoc = devices[index];
                        final deviceData = deviceDoc.data() as Map<String, dynamic>;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () async {
                              await showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (_) => DeviceInfoScreen(device: deviceData),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          deviceData['room']?.toString() ?? 'No Room Name',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _deleteDevice(
                                          deviceDoc.id,
                                          deviceData['room']?.toString() ?? 'Unknown Room',
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        tooltip: 'Delete Device',
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    deviceData['location']?.toString() ?? 'No Location',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Add timestamp display
                                  if (deviceData['created_at'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'Created: ${_formatDate(deviceData['created_at'])}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Patient: ${deviceData['patient']?.toString() ?? 'Unknown'}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Device ID: ${deviceData['deviceId']?.toString() ?? 'Unknown'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(onLogout: _handleLogout),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF126E35),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo1.png', width: 36, height: 36),
            const SizedBox(width: 10),
            const Text(
              'Smart Voice Recognizer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshDevices,
            tooltip: 'Refresh Devices',
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserNotificationsScreen()),
              );
            },
            tooltip: 'Notifications',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0BBD35),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE7FF76),
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RegisterDeviceScreen()),
        ),
      ),
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF126E35),
        selectedItemColor: const Color(0xFFE7FF76),
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Devices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
