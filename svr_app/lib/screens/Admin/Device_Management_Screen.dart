import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firestore_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Online', 'Offline', 'Faulty'];
  
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _filteredDevices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      setState(() => _isLoading = true);
      final devices = await _firestoreService.getDevicesList();
      setState(() {
        _devices = devices;
        _filteredDevices = devices;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading devices: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading devices: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterDevices() {
    setState(() {
      _filteredDevices = _devices.where((device) {
        bool matchesSearch = device['id'].toString().toLowerCase()
            .contains(_searchController.text.toLowerCase()) ||
            device['name'].toString().toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            device['location'].toString().toLowerCase()
                .contains(_searchController.text.toLowerCase());
        
        bool matchesFilter = _selectedFilter == 'All' ||
            device['status'] == _selectedFilter;
        
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _showDeviceDetail(Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Details - ${device['name']}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Device ID', device['id'] ?? 'Unknown'),
              _buildDetailRow('Name', device['name'] ?? 'Unknown Device'),
              _buildDetailRow('Location', device['location'] ?? 'Unknown Location'),
              _buildDetailRow('Status', device['status'] ?? 'Offline'),
              FutureBuilder<Map<String, dynamic>?>(
                future: _firestoreService.getUserDocument(device['assignedUserId'] ?? ''),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildDetailRow('Assigned User', 'Loading...');
                  }
                  final user = snapshot.data;
                  return _buildDetailRow('Assigned User', user?['displayName'] ?? 'Unassigned');
                },
              ),
              _buildDetailRow('Last Activity', _firestoreService.formatTimestamp(device['lastActivityAt'])),
              _buildDetailRow('Battery Level', '${device['batteryLevel'] ?? 0}%'),
              _buildDetailRow('Signal Strength', '${device['signalStrength'] ?? 0}%'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Color(0xFFE7FF76)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeviceActions(device);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE7FF76),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Actions'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE7FF76),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFFE7FF76)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceActions(Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actions for ${device['name']}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                title: const Text(
                  'Reassign Device',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reassignDevice(device);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: const Text(
                  'Disable Device',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _disableDevice(device);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.purple),
                title: const Text(
                  'Replace Device',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _replaceDevice(device);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: const Text(
                  'View Device Logs',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _viewDeviceLogs(device);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.green),
                title: const Text(
                  'View Assigned User',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _viewAssignedUser(device);
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFE7FF76)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reassignDevice(Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reassign ${device['name'] ?? 'Device'}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select new user to assign this device to:',
                style: TextStyle(color: Color(0xFFE7FF76)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _firestoreService.getUsersList(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFE7FF76))));
                    }

                    final users = snapshot.data ?? [];
                    final activeUsers = users.where((user) => user['status'] == 'Active').toList();

                    if (activeUsers.isEmpty) {
                      return const Center(child: Text('No active users available', style: TextStyle(color: Color(0xFFE7FF76))));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: activeUsers.length,
                      itemBuilder: (context, index) {
                        final user = activeUsers[index];
                        return ListTile(
                          title: Text(
                            user['displayName'] ?? 'Unknown User',
                            style: const TextStyle(color: Color(0xFFE7FF76)),
                          ),
                          subtitle: Text(
                            user['email'] ?? 'No email',
                            style: TextStyle(color: Color(0xFFE7FF76).withOpacity(0.7)),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            try {
                              await _firestoreService.reassignDevice(device['id'], user['id']);
                              await _loadDevices(); // Reload devices to get updated data
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${device['name'] ?? 'Device'} reassigned to ${user['displayName'] ?? 'User'}'), backgroundColor: Colors.green),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error reassigning device: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFE7FF76)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _disableDevice(Map<String, dynamic> device) async {
    try {
      await _firestoreService.disableDevice(device['id']);
      await _loadDevices(); // Reload devices to get updated data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${device['name'] ?? 'Device'} has been disabled'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error disabling device: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _replaceDevice(Map<String, dynamic> device) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Replace ${device['name'] ?? 'Device'}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This will mark the current device as faulty and create a replacement request.',
                style: TextStyle(color: Color(0xFFE7FF76)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to proceed?',
                style: TextStyle(color: Color(0xFFE7FF76)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFE7FF76)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await _firestoreService.markDeviceFaulty(device['id']);
                        await _loadDevices(); // Reload devices to get updated data
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Replacement request created for ${device['name'] ?? 'Device'}'), backgroundColor: Colors.orange),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error marking device as faulty: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE7FF76),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewDeviceLogs(Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Logs - ${device['name'] ?? 'Device'}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.maxFinite,
                height: 300,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _firestoreService.getDeviceLogs(device['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFE7FF76))));
                    }

                    final logs = snapshot.data ?? [];

                    if (logs.isEmpty) {
                      return const Center(child: Text('No logs available', style: TextStyle(color: Color(0xFFE7FF76))));
                    }

                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return ListTile(
                          leading: const Icon(Icons.info, size: 16, color: Color(0xFFE7FF76)),
                          title: Text(
                            log['message'] ?? 'Unknown log entry',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFE7FF76)),
                          ),
                          subtitle: Text(
                            _firestoreService.formatTimestamp(log['createdAt']),
                            style: TextStyle(fontSize: 10, color: Color(0xFFE7FF76).withOpacity(0.7)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Color(0xFFE7FF76)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewAssignedUser(Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Assigned to ${device['name'] ?? 'Device'}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>?>(
                future: _firestoreService.getUserDocument(device['assignedUserId'] ?? ''),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFE7FF76))));
                  }

                  final user = snapshot.data;

                  if (user == null) {
                    return const Center(child: Text('No user assigned to this device', style: TextStyle(color: Color(0xFFE7FF76))));
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Name', user['displayName'] ?? 'Unknown User'),
                      _buildDetailRow('Email', user['email'] ?? 'No email'),
                      _buildDetailRow('Role', user['role'] ?? 'user'),
                      _buildDetailRow('Status', user['status'] ?? 'Unknown'),
                      _buildDetailRow('Last Login', _firestoreService.formatTimestamp(user['lastLoginAt'])),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Color(0xFFE7FF76)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF126E35),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        title: const Text(
          'Device Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDevices,
            tooltip: 'Refresh Devices',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => _filterDevices(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search devices...',
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
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
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2FA85E),
                        style: const TextStyle(color: Colors.white),
                        items: _filterOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                            _filterDevices();
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Device List
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _filteredDevices.isEmpty
                        ? const Center(
                            child: Text(
                              'No devices found',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(4),
                            itemCount: _filteredDevices.length,
                            itemBuilder: (context, index) {
                              final device = _filteredDevices[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                color: Colors.white.withOpacity(0.05),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(device['status'] ?? 'Offline').withOpacity(0.2),
                                    child: Icon(
                                      Icons.devices,
                                      color: _getStatusColor(device['status'] ?? 'Offline'),
                                    ),
                                  ),
                                  title: Text(
                                    device['name'] ?? 'Unknown Device',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device['location'] ?? 'Unknown Location',
                                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(device['status'] ?? 'Offline').withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              device['status'] ?? 'Offline',
                                              style: TextStyle(
                                                color: _getStatusColor(device['status'] ?? 'Offline'),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.battery_full,
                                            color: _getBatteryColor(device['batteryLevel'] ?? 0),
                                            size: 16,
                                          ),
                                          Text(
                                            '${device['batteryLevel'] ?? 0}%',
                                            style: TextStyle(
                                              color: _getBatteryColor(device['batteryLevel'] ?? 0),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      FutureBuilder<Map<String, dynamic>?>(
                                        future: _firestoreService.getUserDocument(device['assignedUserId'] ?? ''),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const Text('Loading user...', style: TextStyle(color: Colors.white70));
                                          }
                                          
                                          final user = snapshot.data;
                                          return Text(
                                            'User: ${user?['displayName'] ?? 'Unassigned'}',
                                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_vert, color: Colors.white),
                                    onPressed: () => _showDeviceDetail(device),
                                  ),
                                  onTap: () => _showDeviceDetail(device),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Online':
        return Colors.green;
      case 'Offline':
        return Colors.red;
      case 'Faulty':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getBatteryColor(int batteryLevel) {
    if (batteryLevel > 50) {
      return Colors.green;
    } else if (batteryLevel > 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
