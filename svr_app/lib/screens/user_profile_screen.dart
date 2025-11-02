import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'user_notifications_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  
  late TabController _tabController;
  Map<String, dynamic>? userProfile;
  Map<String, int> userStats = {};
  List<Map<String, dynamic>> userDevices = [];
  List<Map<String, dynamic>> userAlerts = [];
  bool _isLoading = true;
  bool _isEditing = false;
  
  // Profile editing controllers
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);
      
      final uid = _authService.getUserUID();
      if (uid == null) return;

      // Load all data in parallel for better performance
      final results = await Future.wait([
        _firestoreService.getUserDocument(uid),
        _loadUserStats(uid),
        _loadUserDevices(uid),
        _loadUserAlerts(uid),
      ]);

      if (mounted) {
        setState(() {
          userProfile = results[0] as Map<String, dynamic>? ?? {};
          userStats = results[1] as Map<String, int>;
          userDevices = results[2] as List<Map<String, dynamic>>;
          userAlerts = results[3] as List<Map<String, dynamic>>;
          _isLoading = false;
          
          // Initialize controllers
          _displayNameController.text = userProfile?['displayName'] ?? '';
          _phoneController.text = userProfile?['phone'] ?? '';
          _bioController.text = userProfile?['bio'] ?? '';
          _locationController.text = userProfile?['location'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, int>> _loadUserStats(String uid) async {
    try {
      // Load user role and devices/alerts in parallel
      final userRole = _authService.getUserRole(uid);
      final devicesQuery = FirebaseFirestore.instance
          .collection('devices')
          .where('assignedUserId', isEqualTo: uid)
          .get();
      final alertsQuery = FirebaseFirestore.instance
          .collection('alerts')
          .where('userId', isEqualTo: uid)
          .get();

      final results = await Future.wait([userRole, devicesQuery, alertsQuery]);
      final role = results[0] as String?;
      final devices = results[1] as QuerySnapshot;
      final alerts = results[2] as QuerySnapshot;
      
      final activeDevices = devices.docs.where((doc) => 
          doc.data() is Map && 
          (doc.data() as Map)['status'] != 'Offline' && 
          (doc.data() as Map)['status'] != 'Faulty'
      ).length;

      final activeAlerts = alerts.docs.where((doc) => 
          doc.data() is Map && (doc.data() as Map)['status'] == 'Active'
      ).length;

      // For super admin, get system-wide stats in parallel
      if (role == 'super_admin') {
        final systemQueries = await Future.wait([
          FirebaseFirestore.instance.collection('users')
              .where('role', isEqualTo: 'user')
              .get(),
          FirebaseFirestore.instance.collection('devices').get(),
          FirebaseFirestore.instance.collection('alerts').get(),
        ]);
        
        return {
          'Total Devices': devices.docs.length,
          'Active Devices': activeDevices,
          'Total Alerts': alerts.docs.length,
          'System Users': systemQueries[0].docs.length,
          'System Devices': systemQueries[1].docs.length,
          'System Alerts': systemQueries[2].docs.length,
        };
      } else {
        return {
          'My Devices': devices.docs.length,
          'Active Devices': activeDevices,
          'Help Requests': alerts.docs.length,
          'Open Requests': activeAlerts,
        };
      }
    } catch (e) {
      print('Error loading user stats: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _loadUserDevices(String uid) async {
    try {
      final devices = await FirebaseFirestore.instance
          .collection('devices')
          .where('assignedUserId', isEqualTo: uid)
          .orderBy('created_at', descending: true)
          .limit(5)
          .get();
      
      return devices.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error loading user devices: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadUserAlerts(String uid) async {
    try {
      final alerts = await FirebaseFirestore.instance
          .collection('alerts')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      return alerts.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error loading user alerts: $e');
      return [];
    }
  }

  Future<void> _saveProfile() async {
    try {
      final uid = _authService.getUserUID();
      if (uid == null) return;

      // Prepare update data with all necessary fields
      final updateData = {
        'displayName': _displayNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // For new user documents, ensure email and role are set
      final currentUserDoc = await _firestoreService.getUserDocument(uid);
      if (currentUserDoc == null) {
        // Document doesn't exist, create it with required fields
        updateData.addAll({
          'email': _authService.getUserEmail() ?? '',
          'role': 'user', // Default role for new users
          'status': 'Active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestoreService.updateUserDocument(uid, updateData);

      setState(() => _isEditing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Color(0xFFE7FF76),
        ),
      );
      
      _loadUserProfile(); // Refresh data
    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF126E35),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    final isAdmin = userProfile?['role'] == 'super_admin';

    return Scaffold(
      backgroundColor: const Color(0xFF126E35),
      appBar: AppBar(
        backgroundColor: const Color(0xFF126E35),
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFFE7FF76)),
              onPressed: _saveProfile,
              tooltip: 'Save Changes',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() => _isEditing = false),
              tooltip: 'Cancel',
            ),
          ],
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Profile Card (Top Section)
            _buildProfileCard(isAdmin),
            
            // Key Stats/Metrics
            _buildStatsSection(),
            
            // Tab Content
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFE7FF76),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(icon: Icon(Icons.devices), text: 'Devices'),
                      Tab(icon: Icon(Icons.warning), text: 'Activity'),
                      Tab(icon: Icon(Icons.settings), text: 'Settings'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDevicesTab(),
                        _buildActivityTab(),
                        _buildSettingsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(bool isAdmin) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Profile Photo/Avatar
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE7FF76),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipOval(
                  child: userProfile?['photoURL'] != null
                      ? Image.network(
                          userProfile!['photoURL'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultAvatar(),
                        )
                      : _buildDefaultAvatar(),
                ),
              ),
              if (isAdmin)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7FF76),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // User Name/Display Name
          if (_isEditing)
            TextFormField(
              controller: _displayNameController,
              style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFFE7FF76),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                hintText: 'Display Name',
                hintStyle: TextStyle(color: Colors.black54),
              ),
              textAlign: TextAlign.center,
            )
          else
            Text(
              userProfile?['displayName'] ?? _authService.getUserEmail() ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAdmin ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAdmin ? 'Super Administrator' : 'User',
              style: TextStyle(
                color: isAdmin ? Colors.red.shade300 : Colors.blue.shade300,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // User Bio/About Section
          if (_isEditing)
            TextFormField(
              controller: _bioController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFFE7FF76),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                hintText: 'Tell us about yourself...',
                hintStyle: TextStyle(color: Colors.black54),
              ),
              maxLines: 2,
            )
          else
            Text(
              userProfile?['bio'] ?? 'Smart Voice Recognizer user managing devices and requests.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          
          const SizedBox(height: 8),
          
          // Contact Information
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email, color: Colors.white.withOpacity(0.7), size: 16),
              const SizedBox(width: 4),
              Text(
                userProfile?['email'] ?? _authService.getUserEmail() ?? 'No email',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE7FF76),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        size: 50,
        color: Colors.black,
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: userStats.entries.take(4).map((entry) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      color: Color(0xFFE7FF76),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.key,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 9,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDevicesTab() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: userDevices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_other,
                    color: Colors.white.withOpacity(0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No devices found',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first device to get started',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: userDevices.length,
              itemBuilder: (context, index) {
                final device = userDevices[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getDeviceStatusColor(device['status']),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.device_hub,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device['room'] ?? 'Unknown Room',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              device['location'] ?? 'No location',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDeviceStatusColor(device['status']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          device['status'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildActivityTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: userAlerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timeline,
                    color: Colors.white.withOpacity(0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent activity',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: userAlerts.length,
              itemBuilder: (context, index) {
                final alert = userAlerts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getAlertStatusColor(alert['status']),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert['message'] ?? 'Alert notification',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _firestoreService.formatTimestamp(alert['createdAt']),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getAlertStatusColor(alert['status']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          alert['status'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSettingsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Personal Information Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Edit Profile Button (when not in edit mode)
                if (!_isEditing)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE7FF76),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text(
                        'Edit Personal Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Phone Number
                if (_isEditing)
                  TextFormField(
                    controller: _phoneController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFE7FF76),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(color: Colors.black54),
                      prefixIcon: Icon(Icons.phone, color: Colors.black54),
                    ),
                  )
                else
                  _buildInfoRow(
                    Icons.phone,
                    'Phone',
                    userProfile?['phone'] ?? 'Not provided',
                  ),
                
                const SizedBox(height: 12),
                
                // Location
                if (_isEditing)
                  TextFormField(
                    controller: _locationController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFFE7FF76),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      labelText: 'Location',
                      labelStyle: TextStyle(color: Colors.black54),
                      prefixIcon: Icon(Icons.location_on, color: Colors.black54),
                    ),
                  )
                else
                  _buildInfoRow(
                    Icons.location_on,
                    'Location',
                    userProfile?['location'] ?? 'Not provided',
                  ),
                
                // Save and Cancel buttons (when in edit mode)
                if (_isEditing) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE7FF76),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _isEditing = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // App Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildSettingsTile(
                  Icons.notifications,
                  'Notifications',
                  'Manage alert preferences',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserNotificationsScreen(),
                      ),
                    );
                  },
                ),
                
                _buildSettingsTile(
                  Icons.security,
                  'Security',
                  'Password and privacy settings',
                  () {},
                ),
                
                _buildSettingsTile(
                  Icons.help,
                  'Help & Support',
                  'Get help and contact support',
                  () {},
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.white.withOpacity(0.7),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Color _getDeviceStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'online':
      case 'active':
        return Colors.green;
      case 'offline':
        return Colors.red;
      case 'faulty':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getAlertStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
