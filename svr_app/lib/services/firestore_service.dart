import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Users Collection
  Future<void> createUserDocument(String uid, Map<String, dynamic> userData) async {
    await _firestore.collection('users').doc(uid).set({
      ...userData,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserDocument(String uid, Map<String, dynamic> updates) async {
    // Use set with merge: true to create the document if it doesn't exist
    await _firestore.collection('users').doc(uid).set(updates, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Stream<QuerySnapshot> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  Future<List<Map<String, dynamic>>> getUsersList() async {
    final querySnapshot = await _firestore.collection('users').get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Get only users with 'user' role (excludes super_admin)
  Future<List<Map<String, dynamic>>> getRegularUsersList() async {
    final querySnapshot = await _firestore.collection('users')
        .where('role', isEqualTo: 'user')
        .get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
  
  Future<List<QueryDocumentSnapshot>> getAlertsByDateRange(DateTime start, DateTime end) async {
    final QuerySnapshot snapshot = await _firestore.collection('alerts')
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .get();
    return snapshot.docs;
  }

  Future<int> getActiveDeviceCount() async {
    final QuerySnapshot snapshot = await _firestore.collection('devices')
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.size;
  }

  // Devices Collection
  Future<void> createDeviceDocument(Map<String, dynamic> deviceData) async {
    await _firestore.collection('devices').add({
      ...deviceData,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDeviceDocument(String deviceId, Map<String, dynamic> updates) async {
    await _firestore.collection('devices').doc(deviceId).update(updates);
  }

  Stream<QuerySnapshot> getDevicesStream() {
    return _firestore.collection('devices').snapshots();
  }

  Future<List<Map<String, dynamic>>> getDevicesList() async {
    final querySnapshot = await _firestore.collection('devices').get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Alerts Collection
  Future<void> createAlertDocument(Map<String, dynamic> alertData) async {
    await _firestore.collection('alerts').add({
      ...alertData,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'Active',
    });
  }

  Future<void> updateAlertDocument(String alertId, Map<String, dynamic> updates) async {
    await _firestore.collection('alerts').doc(alertId).update({
      ...updates,
      'resolvedAt': updates['status'] == 'Resolved' ? FieldValue.serverTimestamp() : null,
    });
  }

  Stream<QuerySnapshot> getActiveAlertsStream() {
    return _firestore.collection('alerts')
        .where('status', isEqualTo: 'Active')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getResolvedAlertsStream() {
    return _firestore.collection('alerts')
        .where('status', isEqualTo: 'Resolved')
        .orderBy('resolvedAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getActiveAlertsList() async {
    final querySnapshot = await _firestore.collection('alerts')
        .where('status', isEqualTo: 'Active')
        .orderBy('createdAt', descending: true)
        .get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getResolvedAlertsList() async {
    final querySnapshot = await _firestore.collection('alerts')
        .where('status', isEqualTo: 'Resolved')
        .orderBy('resolvedAt', descending: true)
        .get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Notifications Collection
  Future<void> createNotificationDocument(Map<String, dynamic> notificationData) async {
    await _firestore.collection('notifications').add({
      ...notificationData,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'Sent',
      'sentBy': _auth.currentUser?.uid,
    });
  }

  Stream<QuerySnapshot> getNotificationsStream() {
    return _firestore.collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getNotificationsList() async {
    final querySnapshot = await _firestore.collection('notifications')
        .orderBy('createdAt', descending: true)
        .get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Dashboard Stats
  Future<Map<String, int>> getDashboardStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'user') // Only count users with 'user' role
          .get();
      final devicesSnapshot = await _firestore.collection('devices').get();
      final activeAlertsSnapshot = await _firestore.collection('alerts')
          .where('status', isEqualTo: 'Active')
          .get();
      final faultyDevicesSnapshot = await _firestore.collection('devices')
          .where('status', isEqualTo: 'Faulty')
          .get();

      return {
        'Total Users': usersSnapshot.docs.length,
        'Total Devices': devicesSnapshot.docs.length,
        'Active Alerts': activeAlertsSnapshot.docs.length,
        'Faulty Devices': faultyDevicesSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'Total Users': 0,
        'Total Devices': 0,
        'Active Alerts': 0,
        'Faulty Devices': 0,
      };
    }
  }

  // Device Logs
  Future<void> addDeviceLog(String deviceId, String type, String message) async {
    await _firestore.collection('devices').doc(deviceId)
        .collection('logs').add({
      'type': type,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getDeviceLogs(String deviceId) async {
    final querySnapshot = await _firestore.collection('devices').doc(deviceId)
        .collection('logs')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // Search and Filter Methods
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final querySnapshot = await _firestore.collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThan: query + '\uf8ff')
        .get();
    
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> searchDevices(String query) async {
    final querySnapshot = await _firestore.collection('devices')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: query + '\uf8ff')
        .get();
    
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> searchAlerts(String query) async {
    final querySnapshot = await _firestore.collection('alerts')
        .where('message', isGreaterThanOrEqualTo: query)
        .where('message', isLessThan: query + '\uf8ff')
        .get();
    
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // User Management Methods
  Future<void> approveUser(String uid) async {
    await updateUserDocument(uid, {'status': 'Active'});
  }

  Future<void> blockUser(String uid) async {
    await updateUserDocument(uid, {'status': 'Inactive'});
  }

  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // Device Management Methods
  Future<void> reassignDevice(String deviceId, String newUserId) async {
    await updateDeviceDocument(deviceId, {
      'assignedUserId': newUserId,
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    
    // Add log entry
    await addDeviceLog(deviceId, 'REASSIGN', 'Device reassigned to user: $newUserId');
  }

  Future<void> disableDevice(String deviceId) async {
    await updateDeviceDocument(deviceId, {
      'status': 'Offline',
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    
    await addDeviceLog(deviceId, 'STATUS_CHANGE', 'Device disabled by admin');
  }

  Future<void> markDeviceFaulty(String deviceId) async {
    await updateDeviceDocument(deviceId, {
      'status': 'Faulty',
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    
    await addDeviceLog(deviceId, 'STATUS_CHANGE', 'Device marked as faulty');
  }

  // Alert Management Methods
  Future<void> resolveAlert(String alertId, String resolution, String resolvedBy) async {
    await updateAlertDocument(alertId, {
      'status': 'Resolved',
      'resolution': resolution,
      'resolvedBy': resolvedBy,
    });
  }

  // Helper Methods
  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Never';
    
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  String getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'online':
        return 'green';
      case 'inactive':
      case 'offline':
        return 'red';
      case 'pending':
        return 'orange';
      case 'faulty':
        return 'orange';
      default:
        return 'grey';
    }
  }

  String getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'red';
      case 'medium':
        return 'orange';
      case 'low':
        return 'yellow';
      default:
        return 'grey';
    }
  }

  // Device count management methods
  Future<void> incrementUserDeviceCount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'deviceCount': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> decrementUserDeviceCount(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'deviceCount': FieldValue.increment(-1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Sync device count for a user by counting their actual devices
  Future<void> syncUserDeviceCount(String userId) async {
    try {
      final devicesSnapshot = await _firestore
          .collection('devices')
          .where('assignedUserId', isEqualTo: userId)
          .get();
      
      final actualDeviceCount = devicesSnapshot.docs.length;
      
      await _firestore.collection('users').doc(userId).update({
        'deviceCount': actualDeviceCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error syncing device count for user $userId: $e');
    }
  }

  // Sync device counts for all users
  Future<void> syncAllUserDeviceCounts() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (final userDoc in usersSnapshot.docs) {
        await syncUserDeviceCount(userDoc.id);
      }
    } catch (e) {
      print('Error syncing all device counts: $e');
    }
  }
}
