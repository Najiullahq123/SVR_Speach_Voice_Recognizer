import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:svr_app/services/auth_service.dart';

class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key});

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String _selectedType = 'All Users';
  List<String> _selectedUsers = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _notificationHistory = [];
  String? _currentUserRole;
  bool _isSettingAdminRole = false;
  final TextEditingController _uidController = TextEditingController();
  String? _searchedUserId;
  String? _searchedUserName;
  bool _isSearchingUser = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadNotificationHistory();
    _checkUserRole();
  }

  Future<void> _initializeNotifications() async {
    // Request permission for iOS devices
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(initializationSettings);
  }

  Future<void> _loadNotificationHistory() async {
    setState(() => _isLoading = true);
    try {
      // First try with the composite index query
      QuerySnapshot snapshot;
      try {
        snapshot = await _firestore
            .collection('notifications')
            .where('senderRole', isEqualTo: 'super_admin')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();
      } catch (e) {
        // If index doesn't exist, fall back to a simpler query
        print('Index not available, using fallback query: $e');
        snapshot = await _firestore
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();
      }

      setState(() {
        _notificationHistory = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'title': data['title'] ?? '',
            'message': data['message'] ?? '',
            'recipientType': data['recipientType'] ?? 'all',
            'recipientId': data['recipientId'],
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
            'status': data['status'] ?? 'sent',
            'readCount': data['readCount'] ?? 0,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading notification history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Check if user has super_admin role using AuthService
    final authService = AuthService();
    final userRole = await authService.getUserRole(
      FirebaseAuth.instance.currentUser?.uid ?? '',
    );

    if (userRole != 'super_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Access denied. User role: $userRole (requires super_admin)',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Get FCM tokens based on notification type
      List<String> targetTokens = [];

      if (_selectedType == 'Specific Users' && _selectedUsers.isNotEmpty) {
        // Get tokens for specific users
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: _selectedUsers)
            .get();

        for (var doc in usersSnapshot.docs) {
          final userData = doc.data();
          final token = userData['fcmToken'];
          if (token != null && token.isNotEmpty) {
            targetTokens.add(token);
          }
        }
      } else if (_selectedType == 'Active Users') {
        // Get tokens for active users
        final usersSnapshot = await _firestore
            .collection('users')
            .where('status', isEqualTo: 'active')
            .get();

        for (var doc in usersSnapshot.docs) {
          final userData = doc.data();
          final token = userData['fcmToken'];
          if (token != null && token.isNotEmpty) {
            targetTokens.add(token);
          }
        }
      } else {
        // Get all user tokens
        final usersSnapshot = await _firestore.collection('users').get();

        for (var doc in usersSnapshot.docs) {
          final userData = doc.data();
          final token = userData['fcmToken'];
          if (token != null && token.isNotEmpty) {
            targetTokens.add(token);
          }
        }
      }

      // Create notification document
      String recipientType;
      switch (_selectedType) {
        case 'All Users':
          recipientType = 'all';
          break;
        case 'Active Users':
          recipientType = 'active_users';
          break;
        case 'Specific Users':
          recipientType = 'specific_users';
          break;
        default:
          recipientType = 'all';
      }

      final notification = {
        'title': _titleController.text,
        'message': _messageController.text,
        'recipientType': recipientType,
        'recipientId': _selectedType == 'Specific Users'
            ? _selectedUsers.join(',')
            : null,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sending',
        'isRead': false,
        'senderRole': 'super_admin',
        'senderId': FirebaseAuth.instance.currentUser?.uid,
        'recipientCount': targetTokens.length,
      };

      final docRef = await _firestore
          .collection('notifications')
          .add(notification);

      // Send FCM notifications directly from client
      if (targetTokens.isNotEmpty) {
        await _sendFCMNotifications(
          targetTokens,
          _titleController.text,
          _messageController.text,
        );

        // Update notification status to sent
        await _firestore.collection('notifications').doc(docRef.id).update({
          'status': 'sent',
          'sentAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update notification status if no tokens found
        await _firestore.collection('notifications').doc(docRef.id).update({
          'status': 'no_recipients',
          'sentAt': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification sent to ${targetTokens.length} users'),
        ),
      );

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedType = 'All Users';
        _selectedUsers = [];
      });

      // Refresh history
      await _loadNotificationHistory();
    } catch (e) {
      print('Error sending notification: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending notification: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFCMNotifications(
    List<String> tokens,
    String title,
    String message,
  ) async {
    // You'll need to get your server key from Firebase Console
    // Go to Project Settings > Cloud Messaging > Server Key
    const String serverKey =
        'YOUR_SERVER_KEY_HERE'; // Replace with your actual server key

    const String fcmUrl = 'https://fcm.googleapis.com/fcm/send';

    // Send notifications in batches of 100 (FCM limit)
    const int batchSize = 100;
    for (int i = 0; i < tokens.length; i += batchSize) {
      final batch = tokens.sublist(
        i,
        i + batchSize > tokens.length ? tokens.length : i + batchSize,
      );

      final Map<String, dynamic> notificationPayload = {
        'registration_ids': batch,
        'notification': {'title': title, 'body': message, 'sound': 'default'},
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': 'admin_notification',
        },
      };

      try {
        final response = await http.post(
          Uri.parse(fcmUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=$serverKey',
          },
          body: jsonEncode(notificationPayload),
        );

        if (response.statusCode == 200) {
          print('FCM batch sent successfully: ${batch.length} tokens');
        } else {
          print('FCM batch failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Error sending FCM batch: $e');
      }
    }
  }

  Future<void> _checkUserRole() async {
    final authService = AuthService();
    _currentUserRole = await authService.getUserRole(
      FirebaseAuth.instance.currentUser?.uid ?? '',
    );
    setState(() {});
  }

  Future<void> _setSuperAdminRole() async {
    setState(() => _isSettingAdminRole = true);
    try {
      final authService = AuthService();

      // Try to set via cloud function first, fallback to local override
      try {
        await authService.setCurrentUserAsSuperAdmin();
      } catch (e) {
        print('Cloud function failed, trying local override: $e');
        // Fallback to local override
        await authService.setLocalSuperAdminOverride();
      }

      // Refresh the role
      await _checkUserRole();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Successfully set as Super Admin! You can now send notifications.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error setting super admin role: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting super admin role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSettingAdminRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF126E35),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications Panel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Admin Setup Section (only show if user is not super admin)
              if (_currentUserRole != 'super_admin') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Admin Setup Required',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Current role: ${_currentUserRole ?? 'unknown'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need super admin privileges to send notifications. Click the button below to set yourself as a super admin.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSettingAdminRole
                              ? null
                              : _setSuperAdminRole,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSettingAdminRole
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Set as Super Admin',
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
                ),
              ],

              // New Notification Form
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send New Notification',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      dropdownColor: const Color(0xFF2FA85E),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Notification Type',
                        labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'All Users',
                          child: Text('All Users'),
                        ),
                        DropdownMenuItem(
                          value: 'Active Users',
                          child: Text('Active Users'),
                        ),
                        DropdownMenuItem(
                          value: 'Specific Users',
                          child: Text('Specific Users'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                          if (value != 'Specific Users') {
                            _selectedUsers = [];
                          }
                        });
                      },
                    ),
                    if (_selectedType == 'Specific Users') ...[
                      const SizedBox(height: 16),
                      // UID Input Section
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _uidController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Enter User UID',
                                labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: _searchUserByUid,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSearchingUser
                                ? null
                                : _addSearchedUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2FA85E),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            child: _isSearchingUser
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Add User'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Searched User Display
                      if (_searchedUserId != null &&
                          _searchedUserName != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                _searchedUserName == 'User not found' ||
                                    _searchedUserName == 'Error searching user'
                                ? Colors.red.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  _searchedUserName == 'User not found' ||
                                      _searchedUserName ==
                                          'Error searching user'
                                  ? Colors.red.withOpacity(0.3)
                                  : Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _searchedUserName == 'User not found' ||
                                        _searchedUserName ==
                                            'Error searching user'
                                    ? Icons.error
                                    : Icons.check_circle,
                                color:
                                    _searchedUserName == 'User not found' ||
                                        _searchedUserName ==
                                            'Error searching user'
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _searchedUserName!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_searchedUserName != 'User not found' &&
                                        _searchedUserName !=
                                            'Error searching user')
                                      Text(
                                        'UID: ${_searchedUserId!}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_searchedUserName != 'User not found' &&
                                  _searchedUserName != 'Error searching user')
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.green,
                                  ),
                                  onPressed: _addSearchedUser,
                                  tooltip: 'Add this user',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Selected UIDs Display
                      if (_selectedUsers.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          children: _selectedUsers.map((userId) {
                            return FutureBuilder<DocumentSnapshot<Object?>>(
                              future: _firestore
                                  .collection('users')
                                  .doc(userId)
                                  .get(),
                              builder: (context, snapshot) {
                                String displayName = userId;
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final userData =
                                      snapshot.data!.data()
                                          as Map<String, dynamic>;
                                  displayName =
                                      userData['displayName'] ??
                                      userData['email'] ??
                                      userId;
                                }

                                return Chip(
                                  label: Text(
                                    displayName.length > 15
                                        ? '${displayName.substring(0, 15)}...'
                                        : displayName,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: const Color(0xFF2FA85E),
                                  deleteIcon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedUsers.remove(userId);
                                    });
                                  },
                                );
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // User List from Firestore
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('users').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          return Wrap(
                            spacing: 8,
                            children: snapshot.data!.docs.map((doc) {
                              final userData =
                                  doc.data() as Map<String, dynamic>;
                              final userId = doc.id;
                              final isSelected = _selectedUsers.contains(
                                userId,
                              );

                              return FilterChip(
                                label: Text(
                                  userData['displayName'] ?? userId,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedUsers.add(userId);
                                    } else {
                                      _selectedUsers.remove(userId);
                                    }
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: const Color(0xFF2FA85E),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendNotification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(),
                              )
                            : const Text(
                                'Send Notification',
                                style: TextStyle(
                                  color: Color(0xFF126E35),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notification History
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    else if (_notificationHistory.isEmpty)
                      Center(
                        child: Text(
                          'No notifications sent yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _notificationHistory.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: Colors.white24, height: 32),
                        itemBuilder: (context, index) {
                          final notification = _notificationHistory[index];
                          return InkWell(
                            onTap: () => _showNotificationDetails(notification),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification['title'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  notification['status'] ==
                                                      'sent'
                                                  ? Colors.green
                                                  : Colors.orange,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              notification['status']
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _deleteNotification(
                                                  notification['id'],
                                                ),
                                            tooltip: 'Delete notification',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    notification['message'],
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Recipient Information
                                  if (notification['recipientType'] ==
                                          'specific_users' &&
                                      notification['recipientId'] != null) ...[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Sent to specific users:',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.6),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children:
                                                    (notification['recipientId']
                                                            as String)
                                                        .split(',')
                                                        .map(
                                                          (uid) => Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors.blue
                                                                  .withOpacity(
                                                                    0.2,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              border: Border.all(
                                                                color: Colors
                                                                    .blue
                                                                    .withOpacity(
                                                                      0.3,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              uid.length > 8
                                                                  ? '${uid.substring(0, 8)}...'
                                                                  : uid,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        10,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 16,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getRecipientTypeDisplay(
                                          notification['recipientType'],
                                        ),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(notification['timestamp']),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (notification['recipientCount'] !=
                                          null) ...[
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.send,
                                          size: 16,
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${notification['recipientCount']} recipients',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Tap for details',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchUserByUid(String uid) async {
    if (uid.isEmpty) {
      setState(() {
        _searchedUserId = null;
        _searchedUserName = null;
        _isSearchingUser = false;
      });
      return;
    }

    setState(() => _isSearchingUser = true);

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _searchedUserId = uid;
          _searchedUserName =
              userData['displayName'] ?? userData['email'] ?? 'Unknown User';
        });
      } else {
        setState(() {
          _searchedUserId = uid;
          _searchedUserName = 'User not found';
        });
      }
    } catch (e) {
      setState(() {
        _searchedUserId = uid;
        _searchedUserName = 'Error searching user';
      });
    } finally {
      setState(() => _isSearchingUser = false);
    }
  }

  Future<void> _addSearchedUser() async {
    if (_searchedUserId != null &&
        _searchedUserName != null &&
        _searchedUserName != 'User not found' &&
        _searchedUserName != 'Error searching user') {
      if (!_selectedUsers.contains(_searchedUserId)) {
        setState(() {
          _selectedUsers.add(_searchedUserId!);
        });
        _uidController.clear();
        setState(() {
          _searchedUserId = null;
          _searchedUserName = null;
        });
      }
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
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
                notification['title'],
                style: const TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification['message'],
                      style: const TextStyle(
                        color: Color(0xFFE7FF76),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE7FF76)),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Type',
                      _getRecipientTypeDisplay(notification['recipientType']),
                    ),
                    _buildDetailRow(
                      'Status',
                      notification['status']?.toString().toUpperCase() ??
                          'UNKNOWN',
                    ),
                    _buildDetailRow(
                      'Sent',
                      _formatDate(notification['timestamp']),
                    ),
                    if (notification['recipientCount'] != null)
                      _buildDetailRow(
                        'Recipients',
                        '${notification['recipientCount']} users',
                      ),

                    // Show specific recipients if available
                    if (notification['recipientType'] == 'specific_users' &&
                        notification['recipientId'] != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Recipients:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFFE7FF76),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final recipientIds =
                              (notification['recipientId'] as String)
                                  .split(',')
                                  .map((uid) => uid.trim()) // Trim whitespace
                                  .where(
                                    (uid) => uid.isNotEmpty,
                                  ) // Filter out empty strings
                                  .toList();

                          if (recipientIds.isEmpty) {
                            return const Text(
                              'No recipients found',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFE7FF76),
                              ),
                            );
                          }

                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: recipientIds
                                .map(
                                  (
                                    uid,
                                  ) => FutureBuilder<DocumentSnapshot<Object?>>(
                                    future: _firestore
                                        .collection('users')
                                        .doc(uid)
                                        .get(),
                                    builder: (context, snapshot) {
                                      String displayName = uid;
                                      if (snapshot.hasData &&
                                          snapshot.data!.exists) {
                                        final userData =
                                            snapshot.data!.data()
                                                as Map<String, dynamic>;
                                        displayName =
                                            userData['displayName'] ??
                                            userData['email'] ??
                                            uid;
                                      } else if (snapshot.hasError) {
                                        displayName = 'Error loading user';
                                      }

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          displayName.length > 20
                                              ? '${displayName.substring(0, 20)}...'
                                              : displayName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFE7FF76),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Color(0xFFE7FF76)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteNotification(notification['id']);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text(
                      'Delete',
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFFE7FF76),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Color(0xFFE7FF76)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    final confirmed = await showDialog<bool>(
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
              const Text(
                'Delete Notification',
                style: TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to delete this notification? This action cannot be undone.',
                style: TextStyle(color: Color(0xFFE7FF76), fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFE7FF76)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text(
                      'Delete',
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

    if (confirmed == true) {
      try {
        // Check user role before attempting delete
        final authService = AuthService();
        final userRole = await authService.getUserRole(
          FirebaseAuth.instance.currentUser?.uid ?? '',
        );

        print('User role for delete operation: $userRole');
        print('Current user UID: ${FirebaseAuth.instance.currentUser?.uid}');
        print(
          'Current user email: ${FirebaseAuth.instance.currentUser?.email}',
        );

        if (userRole != 'super_admin') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Access denied. User role: $userRole (requires super_admin)',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Try to delete the notification
        await _firestore
            .collection('notifications')
            .doc(notificationId)
            .delete();

        // Also delete user-specific read status
        final usersSnapshot = await _firestore.collection('users').get();
        final batch = _firestore.batch();

        for (var userDoc in usersSnapshot.docs) {
          batch.delete(
            _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('notification_status')
                .doc(notificationId),
          );
        }

        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the history
        await _loadNotificationHistory();
      } catch (e) {
        print('Delete error details: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getRecipientTypeDisplay(String? recipientType) {
    switch (recipientType) {
      case 'all':
        return 'All Users';
      case 'active_users':
        return 'Active Users';
      case 'specific_users':
        return 'Specific Users';
      default:
        return 'All Users';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _uidController.dispose();
    super.dispose();
  }
}
