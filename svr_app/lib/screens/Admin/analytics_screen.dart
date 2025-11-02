import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/report_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ReportService _reportService = ReportService();
  String _selectedPeriod = 'Last 7 Days';
  final List<String> _periodOptions = ['Last 7 Days', 'Last 30 Days', 'Last 3 Months'];

  // Search functionality
  final TextEditingController _userSearchController = TextEditingController();
  List<Map<String, dynamic>> _filteredDeviceUsage = [];

  bool _isLoading = true;
  Map<String, dynamic> _metrics = {
    'totalAlerts': 0,
    'resolvedAlerts': 0,
    'activeDevices': 0,
    'avgResponseTime': 0.0,
  };
  List<Map<String, dynamic>> _deviceUsage = [];
  List<Map<String, dynamic>> _alertFrequency = [];
  List<Map<String, dynamic>> _activeHours = [];
  List<Map<String, dynamic>> _topUsers = [];

  @override
  void initState() {
    super.initState();
    _userSearchController.addListener(_filterUsers);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      // Load key metrics
      final metrics = await _loadKeyMetrics();
      final deviceUsage = await _loadDeviceUsage();
      final alertFreq = await _loadAlertFrequency();
      final activeHours = await _loadActiveHours();
      final topUsers = await _loadTopUsers();

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _deviceUsage = deviceUsage;
          _filteredDeviceUsage = List.from(deviceUsage); // Initialize filtered list
          _alertFrequency = alertFreq;
          _activeHours = activeHours;
          _topUsers = topUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading analytics data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadKeyMetrics() async {
    final now = DateTime.now();
    final periodStart = _getPeriodStart(now);

    final alerts = await _firestoreService.getAlertsByDateRange(periodStart, now);
    final devices = await _firestoreService.getActiveDeviceCount();

    int totalAlerts = alerts.length;
    int resolvedAlerts = alerts.where((a) {
      final data = a.data() as Map<String, dynamic>;
      return data['status'] == 'Resolved';
    }).length;

    // Calculate average response time
    final resolvedAlertsList = alerts.where((a) {
      final data = a.data() as Map<String, dynamic>;
      return data['status'] == 'Resolved' &&
             data['resolvedAt'] != null &&
             data['createdAt'] != null;
    }).toList();

    double avgResponseTime = 0;
    if (resolvedAlertsList.isNotEmpty) {
      final totalResponseTime = resolvedAlertsList.fold(0.0, (sum, alert) {
        final data = alert.data() as Map<String, dynamic>;
        final created = (data['createdAt'] as Timestamp).toDate();
        final resolved = (data['resolvedAt'] as Timestamp).toDate();
        return sum + resolved.difference(created).inMinutes;
      });
      avgResponseTime = totalResponseTime / resolvedAlertsList.length;
    }

    return {
      'totalAlerts': totalAlerts,
      'resolvedAlerts': resolvedAlerts,
      'activeDevices': devices,
      'avgResponseTime': avgResponseTime,
    };
  }

  Future<List<Map<String, dynamic>>> _loadDeviceUsage() async {
    final users = await _firestoreService.getUsersList();
    final devices = await _firestoreService.getDevicesList();

    return users.map((user) {
      final userDevices = devices.where((d) => d['assignedUserId'] == user['id']).toList();
      final activeDevices = userDevices.where((d) => d['status'] == 'Online').length;
      final percentage = userDevices.isEmpty ? 0 : (activeDevices / userDevices.length * 100).round();

      return {
        'user': user['displayName'] ?? 'Unknown User',
        'percentage': percentage,
        'userId': user['id'],
      };
    }).toList()
      ..sort((a, b) => b['percentage'].compareTo(a['percentage']))
      ..take(3); // Show only top 3 users
  }

  Future<List<Map<String, dynamic>>> _loadAlertFrequency() async {
    final now = DateTime.now();
    final periodStart = _getPeriodStart(now);

    final alerts = await _firestoreService.getAlertsByDateRange(periodStart, now);

    // Count alerts by type
    final Map<String, int> alertCounts = {};
    for (final alert in alerts) {
      final data = alert.data() as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type != null) {
        alertCounts[type] = (alertCounts[type] ?? 0) + 1;
      }
    }

    // Convert to list format
    return alertCounts.entries.map((e) => {
      'type': e.key,
      'count': e.value,
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadActiveHours() async {
    final now = DateTime.now();
    final periodStart = _getPeriodStart(now);

    final alerts = await _firestoreService.getAlertsByDateRange(periodStart, now);

    // Count activity by hour
    final Map<int, int> hourlyActivity = {};
    for (final alert in alerts) {
      final data = alert.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final hour = timestamp.toDate().hour;
        hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + 1;
      }
    }

    // Convert to list format and sort by hour
    return List.generate(24, (hour) => {
      'hour': hour,
      'count': hourlyActivity[hour] ?? 0,
    });
  }

  Future<List<Map<String, dynamic>>> _loadTopUsers() async {
    final users = await _firestoreService.getUsersList();
    final now = DateTime.now();
    final periodStart = _getPeriodStart(now);
    final alerts = await _firestoreService.getAlertsByDateRange(periodStart, now);

    // Count alerts by user
    final Map<String, int> userAlertCounts = {};
    for (final alert in alerts) {
      final data = alert.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?;
      if (userId != null) {
        userAlertCounts[userId] = (userAlertCounts[userId] ?? 0) + 1;
      }
    }

    // Map user IDs to user data and sort by alert count
    final topUsers = users.where((user) => userAlertCounts[user['id']] != null)
      .map((user) => {
        'id': user['id'],
        'name': user['displayName'] ?? 'Unknown User',
        'alertCount': userAlertCounts[user['id']] ?? 0,
      }).toList()
      ..sort((a, b) => b['alertCount'].compareTo(a['alertCount']));

    return topUsers.take(5).toList();
  }

  void _filterUsers() {
    final query = _userSearchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredDeviceUsage = List.from(_deviceUsage);
      });
    } else {
      setState(() {
        _filteredDeviceUsage = _deviceUsage.where((user) {
          final userName = user['user'].toString().toLowerCase();
          return userName.contains(query);
        }).toList();
      });
    }
  }

  DateTime _getPeriodStart(DateTime now) {
    switch (_selectedPeriod) {
      case 'Last 7 Days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 Days':
        return now.subtract(const Duration(days: 30));
      case 'Last 3 Months':
        return now.subtract(const Duration(days: 90));
      default:
        return now.subtract(const Duration(days: 7));
    }
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
          'Analytics & Reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            onPressed: _showExportDialog,
            tooltip: 'Export Report',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2FA85E),
                    style: const TextStyle(color: Colors.white),
                    items: _periodOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPeriod = value!;
                      });
                      _loadAnalyticsData();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Key Metrics
              _buildKeyMetrics(),
              const SizedBox(height: 24),
              
              // Device Usage Chart
              _buildDeviceUsageChart(),
              const SizedBox(height: 24),
              
              // Alert Frequency Chart
              _buildAlertFrequencyChart(),
              const SizedBox(height: 24),
              
              // Active Hours Chart
              _buildActiveHoursChart(),
              const SizedBox(height: 24),
              
              // Top Users
              _buildTopUsers(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Metrics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard('Total Alerts', _metrics['totalAlerts'].toString(), Icons.warning, Colors.orange),
            _buildMetricCard('Active Devices', _metrics['activeDevices'].toString(), Icons.devices, Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
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
  }

  Widget _buildDeviceUsageChart() {
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
            'Device Usage by User',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Search Field
          TextField(
            controller: _userSearchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_deviceUsage.isEmpty)
            Center(
              child: Text(
                'No device usage data available',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            )
          else if (_filteredDeviceUsage.isEmpty)
            Center(
              child: Text(
                'No users found matching your search',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            )
          else
            ..._filteredDeviceUsage.map((data) {
              final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
              final index = _deviceUsage.indexOf(data); // Use original index for consistent colors
              return Column(
                children: [
                  _buildUsageBar(
                    data['user'],
                    data['percentage'],
                    colors[index % colors.length],
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildUsageBar(String user, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              user,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '$percentage%',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertFrequencyChart() {
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
            'Alert Frequency',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_alertFrequency.isEmpty)
            Center(
              child: Text(
                'No alert frequency data available',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _alertFrequency.map((data) {
                final colors = {
                  'SOS': Colors.red,
                  'Help': Colors.orange,
                  'Technical': Colors.yellow,
                };
                return _buildAlertTypeCard(
                  data['type'],
                  data['count'],
                  colors[data['type']] ?? Colors.grey,
                );
              }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTypeCard(String type, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          type,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveHoursChart() {
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
            'Active Hours',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_activeHours.isEmpty)
            Center(
              child: Text(
                'No activity data available',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _activeHours.take(6).map((hourData) {
                  final hour = hourData['hour'] as int;
                  final count = hourData['count'] as int;
                  final maxCount = _activeHours.map((h) => h['count'] as int).reduce((a, b) => a > b ? a : b);
                  final height = maxCount > 0 ? (count / maxCount * 100).round() : 0;

                  String hourLabel;
                  if (hour == 0) hourLabel = '12AM';
                  else if (hour < 12) hourLabel = '${hour}AM';
                  else if (hour == 12) hourLabel = '12PM';
                  else hourLabel = '${hour - 12}PM';

                  return _buildHourBar(hourLabel, height, Colors.blue);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHourBar(String hour, int height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: height.toDouble(),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hour,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTopUsers() {
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
            'Top Users by Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_topUsers.isEmpty)
            Center(
              child: Text(
                'No user activity data available',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            )
          else
            ..._topUsers.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              return _buildUserRow(
                user['name'] as String,
                user['alertCount'] as int,
                index + 1,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildUserRow(String name, int activities, int rank) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3 ? Colors.amber : Colors.grey,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$activities activities',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
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
                const Text(
                  'Export Report',
                  style: TextStyle(
                    color: Color(0xFFE7FF76),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose the format for your analytics report:',
                  style: TextStyle(color: Color(0xFFE7FF76)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFFE7FF76).withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _exportReport('pdf');
                      },
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _exportReport('excel');
                      },
                      icon: const Icon(Icons.table_chart, color: Colors.white),
                      label: const Text('Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exportReport(String format) {
    _reportService.generateAndShareReport(
      context: context,
      reportType: format,
      period: _selectedPeriod,
      metrics: _metrics,
      deviceUsage: _deviceUsage,
      alertFrequency: _alertFrequency,
      activeHours: _activeHours,
      topUsers: _topUsers,
    );
  }
}
