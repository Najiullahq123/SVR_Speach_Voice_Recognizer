import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firestore_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Active', 'Inactive', 'Pending'];
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);
      final users = await _firestoreService.getRegularUsersList(); // Only load users with 'user' role
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncAllDeviceCounts() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Syncing device counts for all users...'),
          backgroundColor: Colors.blue,
        ),
      );

      await _firestoreService.syncAllUserDeviceCounts();
      
      // Reload users to show updated counts
      await _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device counts synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error syncing device counts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing device counts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        bool matchesSearch = (user['displayName']?.toString().toLowerCase() ?? '')
            .contains(_searchController.text.toLowerCase()) ||
            (user['email']?.toString().toLowerCase() ?? '')
                .contains(_searchController.text.toLowerCase());
        
        bool matchesFilter = _selectedFilter == 'All' ||
            user['status'] == _selectedFilter;
        
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _showUserDetail(Map<String, dynamic> user) {
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
                'User Details - ${user['name']}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Name', user['displayName'] ?? 'Unknown User'),
              _buildDetailRow('Email', user['email'] ?? 'No email'),
              _buildDetailRow('Role', user['role'] ?? 'user'),
              _buildDetailRow('Status', user['status'] ?? 'Pending'),
              _buildDetailRow('Last Login', _firestoreService.formatTimestamp(user['lastLoginAt'])),
              _buildDetailRow('Device Count', (user['deviceCount'] ?? 0).toString()),
              _buildDetailRow('Registered Devices', (user['assignedDeviceIds']?.length ?? 0).toString()),
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
                      _showUserActions(user);
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
            width: 100,
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

  void _showUserActions(Map<String, dynamic> user) {
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
                'Actions for ${user['displayName'] ?? 'User'}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text(
                  'Approve',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _approveUser(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text(
                  'Block',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteUser(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.devices, color: Colors.blue),
                title: const Text(
                  'View Assigned Devices',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _viewAssignedDevices(user);
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

  Future<void> _approveUser(Map<String, dynamic> user) async {
    try {
      await _firestoreService.approveUser(user['id']);
      await _loadUsers(); // Reload users to get updated data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user['displayName'] ?? 'User'} has been approved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving user: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _blockUser(Map<String, dynamic> user) async {
    try {
      await _firestoreService.blockUser(user['id']);
      await _loadUsers(); // Reload users to get updated data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user['displayName'] ?? 'User'} has been blocked'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking user: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    try {
      await _firestoreService.deleteUser(user['id']);
      await _loadUsers(); // Reload users to get updated data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user['displayName'] ?? 'User'} has been deleted'), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _viewAssignedDevices(Map<String, dynamic> user) {
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
                'Devices Assigned to ${user['displayName'] ?? 'User'}',
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
                  future: _firestoreService.getDevicesList(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Color(0xFFE7FF76))));
                    }

                    final devices = snapshot.data ?? [];
                    final assignedDevices = devices.where((device) =>
                      device['assignedUserId'] == user['id']
                    ).toList();

                    if (assignedDevices.isEmpty) {
                      return const Center(child: Text('No devices assigned', style: TextStyle(color: Color(0xFFE7FF76))));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: assignedDevices.length,
                      itemBuilder: (context, index) {
                        final device = assignedDevices[index];
                        return ListTile(
                          leading: const Icon(Icons.devices, color: Color(0xFFE7FF76)),
                          title: Text(
                            device['name'] ?? 'Unknown Device',
                            style: const TextStyle(color: Color(0xFFE7FF76)),
                          ),
                          subtitle: Text(
                            device['location'] ?? 'Unknown Location',
                            style: TextStyle(color: Color(0xFFE7FF76).withOpacity(0.7)),
                          ),
                          trailing: Icon(
                            Icons.online_prediction,
                            color: device['status'] == 'Online' ? Colors.green : Colors.red
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
          'User Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: _syncAllDeviceCounts,
            tooltip: 'Sync Device Counts',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUsers,
            tooltip: 'Refresh Users',
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
                    onChanged: (value) => _filterUsers(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
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
                            _filterUsers();
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // User List
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
                    : _filteredUsers.isEmpty
                        ? const Center(
                            child: Text(
                              'No users found',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(4),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                color: Colors.white.withOpacity(0.05),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(user['status'] ?? 'Pending').withOpacity(0.2),
                                    child: Icon(
                                      Icons.person,
                                      color: _getStatusColor(user['status'] ?? 'Pending'),
                                    ),
                                  ),
                                  title: Text(
                                    user['displayName'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['email'] ?? 'No email',
                                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(user['status'] ?? 'Pending').withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              user['status'] ?? 'Pending',
                                              style: TextStyle(
                                                color: _getStatusColor(user['status'] ?? 'Pending'),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            user['role'] ?? 'user',
                                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_vert, color: Colors.white),
                                    onPressed: () => _showUserDetail(user),
                                  ),
                                  onTap: () => _showUserDetail(user),
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
      case 'Active':
        return Colors.green;
      case 'Inactive':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
