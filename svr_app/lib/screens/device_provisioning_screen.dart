import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/device_provisioning_service.dart';
import 'dart:async';

class DeviceProvisioningScreen extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic> deviceInfo;

  const DeviceProvisioningScreen({
    Key? key,
    required this.deviceId,
    required this.deviceInfo,
  }) : super(key: key);

  @override
  State<DeviceProvisioningScreen> createState() => _DeviceProvisioningScreenState();
}

class _DeviceProvisioningScreenState extends State<DeviceProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _wifiSSIDController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();
  
  bool _isProvisioning = false;
  bool _isConnectedToDevice = false;
  bool _passwordVisible = false;
  List<Map<String, String>> _availableNetworks = [];
  LEDStatus? _currentLEDStatus;
  StreamSubscription<LEDStatus?>? _ledStatusSubscription;
  
  @override
  void initState() {
    super.initState();
    _checkDeviceConnection();
  }

  @override
  void dispose() {
    _wifiSSIDController.dispose();
    _wifiPasswordController.dispose();
    _ledStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkDeviceConnection() async {
    setState(() => _isProvisioning = true);
    
    final isConnected = await DeviceProvisioningService.isConnectedToDeviceHotspot();
    setState(() {
      _isConnectedToDevice = isConnected;
      _isProvisioning = false;
    });

    if (isConnected) {
      _startLEDMonitoring();
      _loadAvailableNetworks();
    } else {
      _showConnectionInstructions();
    }
  }

  void _startLEDMonitoring() {
    _ledStatusSubscription = DeviceProvisioningService.monitorLEDStatus()
        .listen((status) {
      if (mounted) {
        setState(() => _currentLEDStatus = status);
      }
    });
  }

  Future<void> _loadAvailableNetworks() async {
    try {
      final networks = await DeviceProvisioningService.getAvailableNetworks();
      setState(() => _availableNetworks = networks);
    } catch (e) {
      print('Error loading networks: $e');
    }
  }

  void _showConnectionInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Device Hotspot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('To provision this device, you need to:'),
            const SizedBox(height: 12),
            const Text('1. Go to WiFi settings on your phone'),
            const Text('2. Connect to: HELP_DEVICE_[DEVICE_ID]'),
            const Text('3. Return to this app'),
            const SizedBox(height: 12),
            const Text('The device LED should be RED (unprovisioned).'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkDeviceConnection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE7FF76),
            ),
            child: const Text(
              'I\'m Connected',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _provisionDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProvisioning = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final success = await DeviceProvisioningService.provisionDevice(
        deviceId: widget.deviceId,
        wifiSSID: _wifiSSIDController.text.trim(),
        wifiPassword: _wifiPasswordController.text,
        additionalConfig: {
          'firebase_uid': user.uid,
          'user_email': user.email ?? '',
          ...widget.deviceInfo,
        },
      );

      if (success) {
        _showProvisioningSuccess();
      } else {
        _showError('Failed to send credentials to device');
      }
    } catch (e) {
      _showError('Provisioning failed: $e');
    } finally {
      setState(() => _isProvisioning = false);
    }
  }

  void _showProvisioningSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Credentials Sent!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text('WiFi credentials sent to device successfully!'),
            const SizedBox(height: 8),
            const Text('The device LED should turn BLUE while connecting, then WHITE when online.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // Return success
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE7FF76),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildNetworkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available WiFi Networks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: _availableNetworks.isEmpty
              ? const Center(
                  child: Text(
                    'Loading networks...',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: _availableNetworks.length,
                  itemBuilder: (context, index) {
                    final network = _availableNetworks[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.wifi,
                        color: _getSignalColor(network['signal'] ?? '0'),
                        size: 20,
                      ),
                      title: Text(
                        network['ssid'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Signal: ${network['signal']}% | ${network['security']}',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                      ),
                      onTap: () {
                        _wifiSSIDController.text = network['ssid'] ?? '';
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getSignalColor(String signal) {
    final strength = int.tryParse(signal) ?? 0;
    if (strength > 70) return Colors.green;
    if (strength > 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildLEDStatusIndicator() {
    if (_currentLEDStatus == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Checking device status...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: DeviceProvisioningService.getLEDStatusColor(_currentLEDStatus!),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: DeviceProvisioningService.getLEDStatusColor(_currentLEDStatus!),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device LED Status: ${_currentLEDStatus!.name.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DeviceProvisioningService.getLEDStatusDescription(_currentLEDStatus!),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        title: const Text(
          'Device Provisioning',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isConnectedToDevice
            ? _buildProvisioningForm()
            : _buildConnectionError(),
      ),
    );
  }

  Widget _buildConnectionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            const Text(
              'Not Connected to Device',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please connect to the device hotspot:\nHELP_DEVICE_${widget.deviceId}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _checkDeviceConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE7FF76),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Check Connection',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvisioningForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLEDStatusIndicator(),
            const SizedBox(height: 16),

            Text(
              'Device: ${widget.deviceId}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildNetworkSelector(),
            const SizedBox(height: 16),

            // Manual WiFi entry
            const Text(
              'WiFi Network Name (SSID)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _wifiSSIDController,
              decoration: InputDecoration(
                hintText: 'Enter WiFi network name',
                filled: true,
                fillColor: const Color(0xFFE7FF76),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.wifi, color: Colors.black),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'WiFi network name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            const Text(
              'WiFi Password',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _wifiPasswordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                hintText: 'Enter WiFi password',
                filled: true,
                fillColor: const Color(0xFFE7FF76),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.lock, color: Colors.black),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() => _passwordVisible = !_passwordVisible);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'WiFi password is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProvisioning ? null : _provisionDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE7FF76),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProvisioning
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Send WiFi Credentials',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Note: After sending credentials, the device LED will turn BLUE while connecting, then WHITE when successfully connected to WiFi and Firebase.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
