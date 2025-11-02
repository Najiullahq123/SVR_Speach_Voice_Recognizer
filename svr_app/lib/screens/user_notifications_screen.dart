import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class UserNotificationsScreen extends StatefulWidget {
  const UserNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<UserNotificationsScreen> createState() => _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  List<Map<String, dynamic>> _allNotifications = [];
  List<Map<String, dynamic>> _unreadNotifications = [];
  List<Map<String, dynamic>> _readNotifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    final DateTime dateTime;
    if (timestamp is DateTime) {
      dateTime = timestamp;
    } else if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      return 'Invalid date';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() => _isLoading = true);

      final uid = _authService.getUserUID();
      if (uid == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      // Get all notifications that this user should see
      final QuerySnapshot notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('recipientType', whereIn: ['all', 'user', 'active_users', 'specific_users'])
          .orderBy('timestamp', descending: true)
          .get();

      // Get user's notification read status
      final QuerySnapshot statusSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notification_status')
          .get();

      // Create a map of notification ID to read status
      final Map<String, bool> readStatusMap = {};
      for (var doc in statusSnapshot.docs) {
        readStatusMap[doc.id] = (doc.data() as Map<String, dynamic>)['isRead'] ?? false;
      }

      // Filter and merge notifications with user-specific read status
      final notifications = notificationsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['recipientType'] == 'all' || data['recipientType'] == 'user') {
          return true;
        }
        if (data['recipientType'] == 'active_users') {
          // For active users, show to all users (you could add user status check here)
          return true;
        }
        if (data['recipientType'] == 'specific_users') {
          final recipients = (data['recipientId'] as String?)?.split(',') ?? [];
          return recipients.contains(uid);
        }
        return false;
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final notificationId = doc.id;
        // Use user-specific read status, fallback to global status
        final isRead = readStatusMap[notificationId] ?? (data['isRead'] ?? false);

        return {
          'id': notificationId,
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'isRead': isRead,
          'type': data['recipientType'] ?? 'all',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _allNotifications = notifications;
        _unreadNotifications = notifications.where((n) => !n['isRead']).toList();
        _readNotifications = notifications.where((n) => n['isRead']).toList();
        _unreadCount = _unreadNotifications.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to load notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final uid = _authService.getUserUID();
      if (uid == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      // Create or update user-specific notification status
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notification_status')
          .doc(notificationId)
          .set({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        for (var notification in _allNotifications) {
          if (notification['id'] == notificationId) {
            notification['isRead'] = true;
            break;
          }
        }
        _unreadNotifications = _allNotifications.where((n) => !n['isRead']).toList();
        _readNotifications = _allNotifications.where((n) => n['isRead']).toList();
        _unreadCount = _unreadNotifications.length;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to mark as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final uid = _authService.getUserUID();
      if (uid == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final batch = _firestore.batch();

      for (var notification in _unreadNotifications) {
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('notification_status')
            .doc(notification['id']);
        batch.set(docRef, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      setState(() {
        for (var notification in _allNotifications) {
          notification['isRead'] = true;
        }
        _unreadNotifications = [];
        _readNotifications = _allNotifications;
        _unreadCount = 0;
      });

      _showSuccessSnackBar('All notifications marked as read');
    } catch (e) {
      _showErrorSnackBar('Failed to mark all as read: $e');
    }
  }

  void _showNotificationDetail(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notification['message']),
              const SizedBox(height: 16),
              Text(
                _formatTimestamp(notification['timestamp']),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!notification['isRead'])
            TextButton(
              onPressed: () {
                _markAsRead(notification['id']);
                Navigator.of(context).pop();
              },
              child: const Text('Mark as Read'),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isRead = notification['isRead'] as bool;
    final timestamp = notification['timestamp'] as Timestamp;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: ListTile(
        dense: true,
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              notification['message'],
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isRead ? Colors.grey[200] : const Color(0xFF126E35),
              child: Icon(
                Icons.notifications,
                size: 16,
                color: isRead ? Colors.grey : Colors.white,
              ),
            ),
            if (!isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          if (!isRead) {
            _markAsRead(notification['id']);
          }
          _showNotificationDetail(notification);
        },
      ),
    );
  }

  Widget _buildNotificationsList(List<Map<String, dynamic>> notifications) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        itemCount: notifications.length,
        padding: const EdgeInsets.all(4),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF126E35),
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All (${_allNotifications.length})'),
            Tab(text: 'Unread ($_unreadCount)'),
            Tab(text: 'Read (${_readNotifications.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsList(_allNotifications),
          _buildNotificationsList(_unreadNotifications),
          _buildNotificationsList(_readNotifications),
        ],
      ),
    );
  }
}
