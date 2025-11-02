import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import 'dart:async';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _activeAlerts = [];
  List<Map<String, dynamic>> _alertHistory = [];
  bool _isLoading = true;

  // Stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _activeAlertsSubscription;
  StreamSubscription<QuerySnapshot>? _resolvedAlertsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupAlertListeners();
  }

  @override
  void dispose() {
    _activeAlertsSubscription?.cancel();
    _resolvedAlertsSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupAlertListeners() {
    // Listen to active alerts
    _activeAlertsSubscription = _firestoreService
        .getActiveAlertsStream()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _activeAlerts = snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();
              _isLoading = false;
            });
          }
        });

    // Listen to resolved alerts
    _resolvedAlertsSubscription = _firestoreService
        .getResolvedAlertsStream()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _alertHistory = snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();
            });
          }
        });
  }

  void _showAlertDetail(Map<String, dynamic> alert) {
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
                'Alert Details - ${alert['id']}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Alert ID', alert['id']),
              _buildDetailRow('Type', alert['type']),
              _buildDetailRow('Message', alert['message']),
              _buildDetailRow('Device', alert['device']),
              _buildDetailRow('User', alert['user']),
              _buildDetailRow('Timestamp', alert['timestamp']),
              _buildDetailRow('Priority', alert['priority']),
              _buildDetailRow('Status', alert['status']),
              if (alert['resolution'] != null)
                _buildDetailRow('Resolution', alert['resolution']),
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
                  if (alert['status'] == 'Active') ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resolveAlert(alert);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE7FF76),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Resolve'),
                    ),
                  ],
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

  void _resolveAlert(Map<String, dynamic> alert) async {
    String resolution = '';
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
                'Resolve Alert - ${alert['id']}',
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'How was this alert resolved?',
                style: TextStyle(color: Color(0xFFE7FF76)),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                style: const TextStyle(color: Color(0xFFE7FF76)),
                decoration: InputDecoration(
                  hintText: 'Enter resolution details...',
                  hintStyle: TextStyle(
                    color: Color(0xFFE7FF76).withOpacity(0.7),
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0xFFE7FF76).withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE7FF76)),
                  ),
                ),
                onChanged: (value) {
                  resolution = value;
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
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (resolution.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter resolution details'),
                          ),
                        );
                        return;
                      }

                      try {
                        Navigator.pop(context);
                        await _firestoreService.resolveAlert(
                          alert['id'],
                          resolution,
                          _authService.getUserEmail() ?? 'Admin',
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Alert ${alert['id']} has been resolved',
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error resolving alert: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE7FF76),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Resolve'),
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
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        title: const Text(
          'Alerts & Help',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Active Alerts'),
            Tab(text: 'Alert History'),
          ],
        ),
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
            // Search Section
            Container(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search alerts...',
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
            ),
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildActiveAlertsTab(), _buildAlertHistoryTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlertsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _activeAlerts.isEmpty
          ? Center(
              child: Text(
                'No active alerts',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(4),
              itemCount: _activeAlerts.length,
              itemBuilder: (context, index) {
                final alert = _activeAlerts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.white.withOpacity(0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPriorityColor(
                        alert['priority'],
                      ).withOpacity(0.2),
                      child: Icon(
                        _getAlertIcon(alert['type']),
                        color: _getPriorityColor(alert['priority']),
                      ),
                    ),
                    title: Text(
                      alert['message'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device: ${alert['device']} | User: ${alert['user']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(
                                  alert['priority'],
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                alert['priority'],
                                style: TextStyle(
                                  color: _getPriorityColor(alert['priority']),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              alert['timestamp'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () => _showAlertDetail(alert),
                    ),
                    onTap: () => _showAlertDetail(alert),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAlertHistoryTab() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(4),
        itemCount: _alertHistory.length,
        itemBuilder: (context, index) {
          final alert = _alertHistory[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: Colors.white.withOpacity(0.05),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.withOpacity(0.2),
                child: const Icon(Icons.history, color: Colors.grey),
              ),
              title: Text(
                alert['message'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device: ${alert['device']} | User: ${alert['user']}',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                  Text(
                    'Resolution: ${alert['resolution']}',
                    style: TextStyle(color: Colors.green.withOpacity(0.8)),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Resolved',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        alert['timestamp'],
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => _showAlertDetail(alert),
              ),
              onTap: () => _showAlertDetail(alert),
            ),
          );
        },
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'SOS':
        return Icons.emergency;
      case 'Help':
        return Icons.help;
      default:
        return Icons.warning;
    }
  }
}
