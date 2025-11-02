import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';
import '../user_profile_screen.dart';
import 'User_Management_Screen.dart';
import 'Device_Management_Screen.dart';
import 'alerts_screen.dart';
import 'analytics_screen.dart';
import 'notifications_panel.dart';
import 'Settings_Screen.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'dart:async';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final GlobalKey<FormState> _createUserFormKey = GlobalKey<FormState>();
  final TextEditingController _newUserFirstName = TextEditingController();
  final TextEditingController _newUserLastName = TextEditingController();
  final TextEditingController _newUserEmail = TextEditingController();
  final TextEditingController _newUserPassword = TextEditingController();
  final TextEditingController _newUserConfirmPassword = TextEditingController();
  final TextEditingController _newUserPhone = TextEditingController();
  String _newUserRole = 'user';
  bool _isCreatingUser = false;
  bool _newUserPasswordObscured = true;
  bool _newUserConfirmPasswordObscured = true;

  // Password strength variables
  double _newUserPasswordStrength = 0.0;
  String _newUserPasswordStrengthText = '';
  Color _newUserPasswordStrengthColor = Colors.red;

  // Bottom navigation variables
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Get the current screen based on selected index
  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const UserManagementScreen();
      case 2:
        return const DeviceManagementScreen();
      case 3:
        return const AnalyticsScreen();
      case 4:
        return const SettingsScreen();
      default:
        return _buildDashboardContent();
    }
  }

  // Build dashboard content as a separate widget
  Widget _buildDashboardContent() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${_authService.getUserDisplayName() ?? 'Super Admin'}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email: ${_authService.getUserEmail() ?? 'superadmin@svr.com'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last login: ${DateTime.now().toString().substring(0, 16)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats Grid
            _isLoadingStats
              ? _buildLoadingStats()
              : _buildStatsGrid(),
            const SizedBox(height: 16),

            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Create User (Super Admin)
            _buildCreateUserCard(),

            // Recent Activity
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Map<String, int> stats = {
    'Total Users': 0,
    'Total Devices': 0,
    'Active Alerts': 0,
    'Faulty Devices': 0,
  };

  List<Map<String, dynamic>> recentActivities = [];
  bool _isLoadingStats = true;
  bool _isLoadingActivity = true;

  // Stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _devicesSubscription;
  StreamSubscription<QuerySnapshot>? _alertsSubscription;

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

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _devicesSubscription?.cancel();
    _alertsSubscription?.cancel();
    _newUserFirstName.dispose();
    _newUserLastName.dispose();
    _newUserEmail.dispose();
    _newUserPassword.dispose();
    _newUserConfirmPassword.dispose();
    _newUserPhone.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
    _loadRecentActivity();
    _setupRealTimeListeners();
  }

  void _setupRealTimeListeners() {
    // Listen to users changes (only users with 'user' role)
    _usersSubscription = FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'user')
        .snapshots().listen((snapshot) {
      _updateStats();
    });

    // Listen to devices changes
    _devicesSubscription = FirebaseFirestore.instance.collection('devices').snapshots().listen((snapshot) {
      _updateStats();
      _loadRecentActivity(); // Refresh activity when devices change
    });

    // Listen to alerts changes
    _alertsSubscription = FirebaseFirestore.instance.collection('alerts').snapshots().listen((snapshot) {
      _updateStats();
      _loadRecentActivity(); // Refresh activity when alerts change
    });
  }

  Future<void> _updateStats() async {
    try {
      final dashboardStats = await _firestoreService.getDashboardStats();
      if (mounted) {
        setState(() {
          stats = dashboardStats;
        });
      }
    } catch (e) {
      print('Error updating stats: $e');
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      setState(() => _isLoadingStats = true);
      final dashboardStats = await _firestoreService.getDashboardStats();
      if (mounted) {
        setState(() {
          stats = dashboardStats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      setState(() => _isLoadingActivity = true);
      
      // Get recent alerts
      final alerts = await _firestoreService.getActiveAlertsList();
      final recentAlerts = alerts.take(3).map((alert) => {
        'type': 'Alert',
        'message': alert['message'] ?? 'New alert received',
        'time': _firestoreService.formatTimestamp(alert['createdAt']),
        'color': Colors.orange,
        'priority': alert['priority'] ?? 'medium',
      }).toList();

      // Get recent devices (last updated)
      final devices = await _firestoreService.getDevicesList();
      final recentDevices = devices.where((device) => 
        device['status'] == 'Offline' || device['status'] == 'Faulty'
      ).take(2).map((device) => {
        'type': 'Device',
        'message': 'Device ${device['room'] ?? device['deviceId']} is ${device['status']?.toLowerCase() ?? 'offline'}',
        'time': _firestoreService.formatTimestamp(device['lastActivityAt'] ?? device['createdAt']),
        'color': device['status'] == 'Faulty' ? Colors.red : Colors.orange,
      }).toList();

      // Get recent users
      final users = await _firestoreService.getUsersList();
      final recentUsers = users.where((user) => 
        user['createdAt'] != null
      ).take(2).map((user) => {
        'type': 'User',
        'message': 'New user registered: ${user['displayName'] ?? user['email'] ?? 'Unknown'}',
        'time': _firestoreService.formatTimestamp(user['createdAt']),
        'color': Colors.blue,
      }).toList();

      // Combine and sort by time (simplified sorting)
      final combinedActivities = [
        ...recentAlerts,
        ...recentDevices,
        ...recentUsers,
      ];

      if (mounted) {
        setState(() {
          recentActivities = combinedActivities.take(6).toList();
          _isLoadingActivity = false;
        });
      }
    } catch (e) {
      print('Error loading recent activity: $e');
      if (mounted) {
        setState(() => _isLoadingActivity = false);
      }
    }
  }

  // Quick action navigation helper
  void _navigateToScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // Build a stat card widget
  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a quick action button
  Widget _buildQuickAction(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show full Scaffold with app bar only for dashboard (index 0)
    if (_selectedIndex == 0) {
      return Scaffold(
        backgroundColor: const Color(0xFF126E35),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo1.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 12),
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _loadDashboardStats();
                _loadRecentActivity();
              },
              tooltip: 'Refresh Data',
            ),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPanel()),
                );
              },
              tooltip: 'Notifications',
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: _getCurrentScreen(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    } else {
      // For other screens, show only the content with bottom navigation
      return Scaffold(
        backgroundColor: const Color(0xFF126E35),
        body: _getCurrentScreen(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }
  }

  // Extract bottom navigation bar to a separate method
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
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
          icon: Icon(Icons.people),
          label: 'Users',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.devices),
          label: 'Devices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  Widget _buildLoadingStats() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        String key = stats.keys.elementAt(index);
        int value = stats.values.elementAt(index);
        IconData icon = _getIconForStat(key);
        Color color = _getColorForStat(key);
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      value.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  key,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final List<Map<String, dynamic>> actions = [
      {
        'title': 'User Management',
        'subtitle': 'Manage users and permissions',
        'icon': Icons.people,
        'color': Colors.blue,
        'route': const UserManagementScreen(),
      },
      {
        'title': 'Device Management',
        'subtitle': 'Monitor and control devices',
        'icon': Icons.devices,
        'color': Colors.green,
        'route': const DeviceManagementScreen(),
      },
      {
        'title': 'Alerts & Help',
        'subtitle': 'View active alerts and requests',
        'icon': Icons.warning,
        'color': Colors.orange,
        'route': const AlertsScreen(),
      },
      {
        'title': 'Analytics',
        'subtitle': 'View reports and insights',
        'icon': Icons.analytics,
        'color': Colors.purple,
        'route': const AnalyticsScreen(),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => action['route']),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: action['color'].withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          action['icon'],
                          color: action['color'],
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        action['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action['subtitle'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCreateUserCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New User Account',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Form(
            key: _createUserFormKey,
            child: Column(
              children: [
                // Name Fields
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _newUserFirstName,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white, width: 1),
                          ),
                          prefixIcon: Icon(Icons.person, color: Colors.white.withOpacity(0.7)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.trim().length < 2) {
                            return 'Min 2 chars';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _newUserLastName,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white, width: 1),
                          ),
                          prefixIcon: Icon(Icons.person_outline, color: Colors.white.withOpacity(0.7)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.trim().length < 2) {
                            return 'Min 2 chars';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _newUserEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white, width: 1),
                    ),
                    prefixIcon: Icon(Icons.email, color: Colors.white.withOpacity(0.7)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                      return 'Enter valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Field (Optional)
                TextFormField(
                  controller: _newUserPhone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Phone (Optional)',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white, width: 1),
                    ),
                    prefixIcon: Icon(Icons.phone, color: Colors.white.withOpacity(0.7)),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field with Strength Indicator
                TextFormField(
                  controller: _newUserPassword,
                  obscureText: _newUserPasswordObscured,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white, width: 1),
                    ),
                    prefixIcon: Icon(Icons.lock, color: Colors.white.withOpacity(0.7)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _newUserPasswordObscured ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      onPressed: () {
                        setState(() {
                          _newUserPasswordObscured = !_newUserPasswordObscured;
                        });
                      },
                    ),
                  ),
                  onChanged: _checkNewUserPasswordStrength,
                  validator: _validateNewUserPassword,
                ),

                // Password Strength Indicator
                if (_newUserPassword.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _newUserPasswordStrength,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(_newUserPasswordStrengthColor),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _newUserPasswordStrengthText,
                        style: TextStyle(
                          color: _newUserPasswordStrengthColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _newUserConfirmPassword,
                  obscureText: _newUserConfirmPasswordObscured,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white, width: 1),
                    ),
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.7)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _newUserConfirmPasswordObscured ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      onPressed: () {
                        setState(() {
                          _newUserConfirmPasswordObscured = !_newUserConfirmPasswordObscured;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != _newUserPassword.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Role Selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'User Role:',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _newUserRole,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF126E35),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('Regular User', style: TextStyle(color: Colors.white)),
                            ),
                            DropdownMenuItem(
                              value: 'super_admin',
                              child: Text('Super Admin', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _newUserRole = value ?? 'user';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Create User Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCreatingUser ? null : _handleCreateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: const StadiumBorder(),
                      elevation: 8,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE7FF76), Color(0xFFB6D94C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: _isCreatingUser
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'CREATE USER ACCOUNT',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isLoadingActivity)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: _isLoadingActivity
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : recentActivities.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.timeline,
                              color: Colors.white.withOpacity(0.5),
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No recent activity',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentActivities.length,
                      itemBuilder: (context, index) {
                        final activity = recentActivities[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: activity['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getActivityIcon(activity['type']),
                              color: activity['color'],
                              size: 20,
                            ),
                          ),
                          title: Text(
                            activity['message'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            activity['time'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: activity['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              activity['type'],
                              style: TextStyle(
                                color: activity['color'],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header with background image and user info
            Container(
              height: 200,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/dbg.jpg'),
                  fit: BoxFit.cover,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // User Avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // User Name
                      Text(
                        _authService.getUserDisplayName() ?? 'Super Admin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // User Email
                      Text(
                        _authService.getUserEmail() ?? 'superadmin@svr.com',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // User Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Admin Menu Items
            _buildDrawerItem(
              icon: Icons.dashboard,
              title: 'Dashboard',
              onTap: () => Navigator.pop(context),
            ),

            _buildDrawerItem(
              icon: Icons.people,
              title: 'User Management',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                );
              },
            ),

            _buildDrawerItem(
              icon: Icons.devices,
              title: 'Device Management',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceManagementScreen()),
                );
              },
            ),

            _buildDrawerItem(
              icon: Icons.warning,
              title: 'Alerts & Help Requests',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                );
              },
            ),

            _buildDrawerItem(
              icon: Icons.analytics,
              title: 'Analytics & Reports',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                );
              },
            ),

            _buildDrawerItem(
              icon: Icons.notifications,
              title: 'Notifications',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPanel()),
                );
              },
            ),

            _buildDrawerItem(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),

            const Divider(color: Colors.white30, height: 40),

            // Logout
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD32F2F).withOpacity(0.2),
                    border: Border.all(
                      color: const Color(0xFFD32F2F),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Color(0xFFD32F2F),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFD32F2F),
                  size: 16,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _getIconForStat(String stat) {
    switch (stat) {
      case 'Total Users':
        return Icons.people;
      case 'Total Devices':
        return Icons.devices;
      case 'Active Alerts':
        return Icons.warning;
      case 'Faulty Devices':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Color _getColorForStat(String stat) {
    switch (stat) {
      case 'Total Users':
        return Colors.blue;
      case 'Total Devices':
        return Colors.green;
      case 'Active Alerts':
        return Colors.orange;
      case 'Faulty Devices':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _checkNewUserPasswordStrength(String password) {
    double strength = 0.0;
    String strengthText = '';
    Color strengthColor = Colors.red;

    if (password.isEmpty) {
      strength = 0.0;
      strengthText = '';
    } else if (password.length < 6) {
      strength = 0.2;
      strengthText = 'Too Short';
      strengthColor = Colors.red;
    } else {
      // Check various criteria
      bool hasLowercase = password.contains(RegExp(r'[a-z]'));
      bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
      bool hasDigits = password.contains(RegExp(r'[0-9]'));
      bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      bool hasMinLength = password.length >= 8;

      int criteriaCount = 0;
      if (hasLowercase) criteriaCount++;
      if (hasUppercase) criteriaCount++;
      if (hasDigits) criteriaCount++;
      if (hasSpecialCharacters) criteriaCount++;
      if (hasMinLength) criteriaCount++;

      switch (criteriaCount) {
        case 1:
        case 2:
          strength = 0.4;
          strengthText = 'Weak';
          strengthColor = Colors.red;
          break;
        case 3:
          strength = 0.6;
          strengthText = 'Fair';
          strengthColor = Colors.orange;
          break;
        case 4:
          strength = 0.8;
          strengthText = 'Good';
          strengthColor = Colors.blue;
          break;
        case 5:
          strength = 1.0;
          strengthText = 'Strong';
          strengthColor = Colors.green;
          break;
        default:
          strength = 0.2;
          strengthText = 'Weak';
          strengthColor = Colors.red;
      }
    }

    if (mounted) {
      setState(() {
        _newUserPasswordStrength = strength;
        _newUserPasswordStrengthText = strengthText;
        _newUserPasswordStrengthColor = strengthColor;
      });
    }
  }

  String? _validateNewUserPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    List<String> errors = [];

    if (value.length < 8) {
      errors.add('At least 8 characters');
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      errors.add('One lowercase letter');
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      errors.add('One uppercase letter');
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      errors.add('One number');
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('One special character');
    }

    if (errors.isNotEmpty) {
      return 'Password must contain:\n• ${errors.join('\n• ')}';
    }

    return null;
  }

  Future<void> _handleCreateUser() async {
    if (!_createUserFormKey.currentState!.validate()) return;

    if (mounted) {
      setState(() => _isCreatingUser = true);
    }

    try {
      final String firstName = _newUserFirstName.text.trim();
      final String lastName = _newUserLastName.text.trim();
      final String email = _newUserEmail.text.trim();
      final String password = _newUserPassword.text;
      final String phone = _newUserPhone.text.trim();

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating user account...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      // Create user with Firebase Auth
      final UserCredential? userCredential = await _authService.createUserWithEmailAndPassword(email, password);

      if (!mounted) return;

      if (userCredential != null && userCredential.user != null) {
        // Update user profile with display name
        await userCredential.user!.updateDisplayName('$firstName $lastName');

        // Create user document in Firestore
        try {
          await _firestoreService.createUserDocument(
            userCredential.user!.uid,
            {
              'firstName': firstName,
              'lastName': lastName,
              'email': email,
              'displayName': '$firstName $lastName',
              'role': _newUserRole,
              'isActive': true,
              'profileImageUrl': '',
              'phoneNumber': phone,
              'address': '',
              'dateOfBirth': '',
              'deviceCount': 0,
              'lastLoginAt': FieldValue.serverTimestamp(),
            },
          );

          // Success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "$firstName $lastName" created successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Clear form
          _newUserFirstName.clear();
          _newUserLastName.clear();
          _newUserEmail.clear();
          _newUserPassword.clear();
          _newUserConfirmPassword.clear();
          _newUserPhone.clear();
          setState(() {
            _newUserRole = 'user';
            _newUserPasswordStrength = 0.0;
            _newUserPasswordStrengthText = '';
          });

        } catch (firestoreError) {
          print('Error saving user data to Firestore: $firestoreError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User created but profile setup failed: $firestoreError'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create user account. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Failed to create user';
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'Please provide a valid email address.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        default:
          errorMessage = 'Failed to create user: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingUser = false);
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Alert':
        return Icons.warning;
      case 'Device':
        return Icons.devices;
      case 'User':
        return Icons.person;
      case 'System':
        return Icons.settings;
      default:
        return Icons.info;
    }
  }
}
