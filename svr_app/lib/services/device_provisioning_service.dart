import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:async';

// LED Status Enum
enum LEDStatus {
  disconnected,  // Offline/Disconnected  
  connecting,    // Attempting to connect
  connected,     // Connected/Online
  error,         // Connection Error
  unknown        // Status unknown
}

class DeviceProvisioningService {
  static const String deviceHotspotSSID = 'HELP_DEVICE';
  static const String deviceApiBaseUrl = 'http://192.168.4.1';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Device provisioning data structure
  static Map<String, dynamic> createProvisioningData({
    required String deviceId,
    required String wifiSSID,
    required String wifiPassword,
    required String firebaseConfig,
    Map<String, dynamic>? deviceInfo,
  }) {
    return {
      'device_id': deviceId,
      'wifi_ssid': wifiSSID,
      'wifi_password': wifiPassword,
      'firebase_config': firebaseConfig,
      'device_info': deviceInfo ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Check if connected to device hotspot
  static Future<bool> isConnectedToDeviceHotspot() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.wifi) {
        return false;
      }

      // Try to reach the device API endpoint
      final response = await http.get(
        Uri.parse('$deviceApiBaseUrl/status'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get available WiFi networks from device
  static Future<List<Map<String, String>>> getAvailableNetworks() async {
    try {
      final response = await http.get(
        Uri.parse('$deviceApiBaseUrl/scan'),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['networks'] is List) {
          return List<Map<String, String>>.from(
            data['networks'].map((network) => {
              'ssid': network['ssid']?.toString() ?? '',
              'security': network['security']?.toString() ?? 'open',
              'signal_strength': network['signal_strength']?.toString() ?? '0',
            }),
          );
        }
      }
      return [];
    } catch (e) {
      print('Error getting available networks: $e');
      return [];
    }
  }

  // Get device status
  static Future<Map<String, dynamic>?> getDeviceStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$deviceApiBaseUrl/status'),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting device status: $e');
      return null;
    }
  }

  // Provision device with WiFi credentials
  static Future<bool> provisionDevice({
    required String deviceId,
    required String wifiSSID,
    required String wifiPassword,
    Map<String, dynamic>? additionalConfig,
  }) async {
    try {
      final provisioningData = createProvisioningData(
        deviceId: deviceId,
        wifiSSID: wifiSSID,
        wifiPassword: wifiPassword,
        firebaseConfig: json.encode(additionalConfig ?? {}),
        deviceInfo: additionalConfig,
      );

      final response = await http.post(
        Uri.parse('$deviceApiBaseUrl/provision'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(provisioningData),
      ).timeout(apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error provisioning device: $e');
      return false;
    }
  }

  // Get current LED status
  static Future<LEDStatus?> getLEDStatus() async {
    try {
      final status = await getDeviceStatus();
      if (status != null && status.containsKey('led_status')) {
        switch (status['led_status'].toString().toLowerCase()) {
          case 'red':
          case 'error':
            return LEDStatus.error;
          case 'blue':
          case 'connecting':
            return LEDStatus.connecting;
          case 'white':
          case 'connected':
            return LEDStatus.connected;
          case 'blinking_red':
          case 'disconnected':
            return LEDStatus.disconnected;
          default:
            return LEDStatus.unknown;
        }
      }
      return LEDStatus.unknown;
    } catch (e) {
      print('Error getting LED status: $e');
      return LEDStatus.unknown;
    }
  }

  // Monitor LED status with periodic updates
  static Stream<LEDStatus?> monitorLEDStatus({Duration interval = const Duration(seconds: 2)}) async* {
    while (true) {
      try {
        final status = await getLEDStatus();
        yield status;
        await Future.delayed(interval);
      } catch (e) {
        print('Error monitoring LED status: $e');
        yield LEDStatus.unknown;
        await Future.delayed(interval);
      }
    }
  }

  // Send test command to device
  static Future<bool> testDeviceConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$deviceApiBaseUrl/test'),
      ).timeout(apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error testing device connection: $e');
      return false;
    }
  }

  // Reset device configuration
  static Future<bool> resetDevice() async {
    try {
      final response = await http.post(
        Uri.parse('$deviceApiBaseUrl/reset'),
      ).timeout(apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error resetting device: $e');
      return false;
    }
  }

  // Get LED status description
  static String getLEDStatusDescription(LEDStatus status) {
    switch (status) {
      case LEDStatus.disconnected:
        return 'Device is offline and disconnected';
      case LEDStatus.connecting:
        return 'Device is attempting to connect to WiFi';
      case LEDStatus.connected:
        return 'Device is connected and online';
      case LEDStatus.error:
        return 'Device has a connection error - needs reprovisioning';
      case LEDStatus.unknown:
        return 'Device status is unknown';
    }
  }

  // Get LED status color for UI
  static Color getLEDStatusColor(LEDStatus status) {
    switch (status) {
      case LEDStatus.disconnected:
        return Colors.grey;
      case LEDStatus.connecting:
        return Colors.orange;
      case LEDStatus.connected:
        return Colors.green;
      case LEDStatus.error:
        return Colors.red;
      case LEDStatus.unknown:
        return Colors.grey.shade600;
    }
  }
}

// Device status model
class DeviceStatus {
  final String deviceId;
  final bool isProvisioned;
  final bool wifiConnected;
  final bool firebaseConnected;
  final LEDStatus ledStatus;
  final String? wifiSSID;
  final int? signalStrength;
  final DateTime lastUpdate;

  DeviceStatus({
    required this.deviceId,
    required this.isProvisioned,
    required this.wifiConnected,
    required this.firebaseConnected,
    required this.ledStatus,
    this.wifiSSID,
    this.signalStrength,
    required this.lastUpdate,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      deviceId: json['device_id'] ?? '',
      isProvisioned: json['is_provisioned'] ?? false,
      wifiConnected: json['wifi_connected'] ?? false,
      firebaseConnected: json['firebase_connected'] ?? false,
      ledStatus: _parseLEDStatus(json['led_status']),
      wifiSSID: json['wifi_ssid'],
      signalStrength: json['signal_strength'],
      lastUpdate: DateTime.now(),
    );
  }

  static LEDStatus _parseLEDStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'red':
      case 'error':
        return LEDStatus.error;
      case 'blue':
      case 'connecting':
        return LEDStatus.connecting;
      case 'white':
      case 'connected':
        return LEDStatus.connected;
      case 'blinking_red':
      case 'disconnected':
        return LEDStatus.disconnected;
      default:
        return LEDStatus.unknown;
    }
  }
}
