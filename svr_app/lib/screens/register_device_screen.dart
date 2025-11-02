import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/dashboard_screen.dart';
import '../services/firestore_service.dart';
import '../services/device_provisioning_service.dart';
import 'qr_scanner_screen.dart';
import 'device_provisioning_screen.dart';

class RegisterDeviceScreen extends StatefulWidget {
  const RegisterDeviceScreen({Key? key}) : super(key: key);

  @override
  State<RegisterDeviceScreen> createState() => _RegisterDeviceScreenState();
}

class _RegisterDeviceScreenState extends State<RegisterDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController mainLocation = TextEditingController();
  final TextEditingController subLocation = TextEditingController();
  final TextEditingController patientName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController deviceIdController = TextEditingController();
  final TextEditingController wifiSsidController = TextEditingController();
  final TextEditingController wifiPasswordController = TextEditingController();
  final List<TextEditingController> phoneControllers = [
    TextEditingController(),
  ];

  bool _isProvisioned = false;
  bool _isScanning = false;
  bool _isLoading = false;
  bool _showWifiFields = false;

  // Add UID validation
  bool _validateUID() {
    return deviceIdController.text.trim().isNotEmpty &&
        deviceIdController.text.trim().length >= 6;
  }

  @override
  void dispose() {
    mainLocation.dispose();
    subLocation.dispose();
    patientName.dispose();
    email.dispose();
    deviceIdController.dispose();
    wifiSsidController.dispose();
    wifiPasswordController.dispose();
    for (var controller in phoneControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPhoneField() {
    setState(() {
      phoneControllers.add(TextEditingController());
    });
  }

  bool _validatePhones() {
    for (var controller in phoneControllers) {
      if (controller.text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _scanQRCode() async {
    try {
      setState(() => _isScanning = true);

      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const QRScannerScreen()),
      );

      if (result != null && result.isNotEmpty) {
        setState(() {
          deviceIdController.text = result;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device ID scanned: $result'),
            backgroundColor: const Color(0xFFE7FF76),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _startProvisioning() async {
    if (!_formKey.currentState!.validate() ||
        !_validatePhones() ||
        !_validateUID()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly.')),
      );
      return;
    }

    final deviceInfo = {
      'room': subLocation.text.isNotEmpty ? subLocation.text : 'New Room',
      'location': mainLocation.text,
      'patient': patientName.text,
      'email': email.text.trim(),
      'phones': phoneControllers.map((c) => c.text.trim()).toList(),
    };

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceProvisioningScreen(
          deviceId: deviceIdController.text.trim(),
          deviceInfo: deviceInfo,
        ),
      ),
    );

    if (result == true) {
      setState(() => _isProvisioned = true);
      _saveDeviceToFirestore();
    }
  }

  Future<void> _saveDeviceToFirestore() async {
    try {
      // Provision WiFi if enabled and credentials provided
      if (_showWifiFields &&
          wifiSsidController.text.trim().isNotEmpty &&
          wifiPasswordController.text.trim().isNotEmpty) {
        setState(() => _isLoading = true);

        final success = await DeviceProvisioningService.provisionDevice(
          deviceId: deviceIdController.text.trim(),
          wifiSSID: wifiSsidController.text.trim(),
          wifiPassword: wifiPasswordController.text.trim(),
        );

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to provision WiFi credentials. Device will be registered without WiFi setup.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      final deviceData = {
        'deviceId': deviceIdController.text.trim(),
        'room': subLocation.text.isNotEmpty ? subLocation.text : 'New Room',
        'location': mainLocation.text,
        'patient': patientName.text,
        'email': email.text.trim(),
        'phones': phoneControllers.map((c) => c.text.trim()).toList(),
        'assignedUserId': FirebaseAuth.instance.currentUser!.uid,
        'created_at': FieldValue.serverTimestamp(),
        'provisioned_at': FieldValue.serverTimestamp(),
        'status': 'Online', // Device is provisioned and should be online
        'wifiConfigured':
            _showWifiFields &&
            wifiSsidController.text.trim().isNotEmpty &&
            wifiPasswordController.text.trim().isNotEmpty,
      };

      final deviceId = deviceIdController.text.trim();
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Save device to devices collection
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .set(deviceData);

      // Increment user's device count using FirestoreService
      await _firestoreService.incrementUserDeviceCount(userId);

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _showWifiFields &&
                    wifiSsidController.text.trim().isNotEmpty &&
                    wifiPasswordController.text.trim().isNotEmpty
                ? 'Device registered and WiFi provisioned successfully!'
                : 'Device registered successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save device: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE7FF76),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF126E35)),
        title: const Text(
          'Register New Device',
          style: TextStyle(
            color: Color(0xFF126E35),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo1.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Register New Device',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Device ID Section (Read-only, filled by QR scan at bottom)
                  _buildOutlinedField(
                    controller: deviceIdController,
                    hint: 'Device ID (Use QR scanner below to fill)',
                    readOnly: true,
                    icon: Icons.devices,
                  ),

                  // WiFi Provisioning Toggle
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _showWifiFields,
                        onChanged: (value) {
                          setState(() {
                            _showWifiFields = value ?? false;
                          });
                        },
                        fillColor: MaterialStateProperty.all(
                          const Color(0xFFE7FF76),
                        ),
                        checkColor: Colors.black,
                      ),
                      const Text(
                        'Provision WiFi settings to device',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),

                  // WiFi Provisioning Section
                  if (_showWifiFields) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WiFi Configuration',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildOutlinedField(
                            controller: wifiSsidController,
                            hint: 'WiFi Network Name (SSID)',
                            icon: Icons.wifi,
                          ),
                          const SizedBox(height: 8),
                          _buildOutlinedField(
                            controller: wifiPasswordController,
                            hint: 'WiFi Password',
                            icon: Icons.lock,
                            isPassword: true,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'WiFi credentials will be sent to the device',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildOutlinedField(
                    controller: mainLocation,
                    hint: 'Main Location',
                  ),
                  const SizedBox(height: 16),
                  _buildOutlinedField(
                    controller: subLocation,
                    hint: 'Sub Location',
                  ),
                  const SizedBox(height: 16),
                  _buildOutlinedField(
                    controller: patientName,
                    hint: 'Patient Name',
                  ),
                  const SizedBox(height: 16),
                  ..._buildPhoneFields(),
                  const SizedBox(height: 16),
                  _buildOutlinedField(
                    controller: email,
                    hint: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 32),
                  // QR Scanner Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning
                          ? null
                          : () async {
                              setState(() => _isScanning = true);
                              final scannedId = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const QRScannerScreen(),
                                ),
                              );
                              if (scannedId != null && mounted) {
                                deviceIdController.text = scannedId;
                              }
                              if (mounted) {
                                setState(() => _isScanning = false);
                              }
                            },
                      icon: _isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.black,
                            ),
                      label: Text(
                        _isScanning ? 'Scanning...' : 'Scan Device QR Code',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProvisioned
                          ? _saveDeviceToFirestore
                          : _startProvisioning,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: const StadiumBorder(),
                        elevation: 8,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isProvisioned
                                ? [
                                    const Color(0xFF4CAF50),
                                    const Color(0xFF2E7D32),
                                  ]
                                : [
                                    const Color(0xFFE7FF76),
                                    const Color(0xFFB6D94C),
                                  ],
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
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            _isProvisioned
                                ? 'COMPLETE REGISTRATION'
                                : 'PROVISION DEVICE',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 32,
                  ), // Extra bottom padding to prevent overflow
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    IconData? icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      obscureText: isPassword,
      style: TextStyle(
        color: readOnly ? Colors.grey : const Color(0xFFE7FF76),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: readOnly ? Colors.grey : const Color(0xFFE7FF76),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFFE7FF76))
            : null,
        suffixIcon: isPassword
            ? Icon(Icons.visibility_off, color: const Color(0xFFE7FF76))
            : null,
        filled: true,
        fillColor: readOnly ? Colors.grey.shade800 : const Color(0xFF2FA85E),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFE7FF76), width: 2.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFE7FF76), width: 2.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.grey, width: 2.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      validator: (value) {
        if (controller == deviceIdController) {
          if (value == null || value.trim().isEmpty) return 'ID required';
          if (value.trim().length < 6) return 'Minimum 6 characters';
        }
        if (value == null || value.trim().isEmpty) return 'Required';
        return null;
      },
    );
  }

  List<Widget> _buildPhoneFields() {
    List<Widget> fields = [];
    for (int i = 0; i < phoneControllers.length; i++) {
      fields.add(
        Row(
          children: [
            Expanded(
              child: _buildOutlinedField(
                controller: phoneControllers[i],
                hint: 'Phone Number',
                keyboardType: TextInputType.phone,
              ),
            ),
            if (i == phoneControllers.length - 1)
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: _addPhoneField,
              ),
          ],
        ),
      );
      fields.add(const SizedBox(height: 10));
    }
    return fields;
  }
}
