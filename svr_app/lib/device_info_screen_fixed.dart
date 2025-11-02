import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceInfoScreen extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceInfoScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  late Map<String, dynamic> _deviceData;
  late List<TextEditingController> _phoneControllers;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _deviceData = Map<String, dynamic>.from(widget.device);
    
    // Initialize phone controllers
    List<String> phones = List<String>.from(_deviceData['phones'] ?? []);
    _phoneControllers = phones.map((phone) => TextEditingController(text: phone)).toList();
    
    // Ensure at least one phone field
    if (_phoneControllers.isEmpty) {
      _phoneControllers.add(TextEditingController());
      _deviceData['phones'] = [''];
    }
  }

  @override
  void dispose() {
    for (var controller in _phoneControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _addPhoneNumber() {
    if (mounted) {
      setState(() {
        _phoneControllers.add(TextEditingController());
        final newPhones = List<String>.from(_deviceData['phones'] ?? []);
        newPhones.add('');
        _deviceData['phones'] = newPhones;
      });
    }
  }

  void _removePhoneNumber(int index) {
    if (_phoneControllers.length > 1 && mounted) {
      setState(() {
        _phoneControllers[index].dispose();
        _phoneControllers.removeAt(index);
        final newPhones = List<String>.from(_deviceData['phones'] ?? []);
        newPhones.removeAt(index);
        _deviceData['phones'] = newPhones;
      });
    }
  }

  Future<void> _saveToFirestore() async {
    try {
      // Update phone numbers from controllers
      _deviceData['phones'] = _phoneControllers.map((controller) => controller.text.trim()).toList();
      
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(_deviceData['deviceId'])
          .update(_deviceData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 32,
              spreadRadius: 4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                          child: const Icon(
                            Icons.devices_other,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _deviceData['room']?.toString() ?? 'Device Info',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Device ID: ${_deviceData['deviceId']?.toString() ?? 'Unknown'}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Room Name
                    const Text(
                      'Room Name',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _deviceData['room']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      onChanged: (value) => _deviceData['room'] = value,
                    ),
                    const SizedBox(height: 18),

                    // Location
                    const Text(
                      'Location',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _deviceData['location']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      onChanged: (value) => _deviceData['location'] = value,
                    ),
                    const SizedBox(height: 18),

                    // Patient Name
                    const Text(
                      'Patient Name',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _deviceData['patient']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      onChanged: (value) => _deviceData['patient'] = value,
                    ),
                    const SizedBox(height: 18),

                    // Phone Numbers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Phone Numbers',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        TextButton(
                          onPressed: _addPhoneNumber,
                          child: const Text(
                            '+ Add Phone',
                            style: TextStyle(color: Color(0xFFB9FF7A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._buildPhoneFields(),
                    const SizedBox(height: 18),

                    // Email
                    const Text(
                      'Email',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _deviceData['email']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      onChanged: (value) => _deviceData['email'] = value,
                    ),
                    const SizedBox(height: 18),

                    // Creation Date
                    if (_deviceData['created_at'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Created Date',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDate(_deviceData['created_at']),
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),

                    // Save Button
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _saveToFirestore();
                          if (mounted) {
                            Navigator.of(context).pop(_deviceData);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF40C853),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Close Button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPhoneFields() {
    return List.generate(_phoneControllers.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneControllers[i],
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white24,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  hintText: 'Phone number',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                onChanged: (value) {
                  if (_deviceData['phones'] is List) {
                    List<String> phones = List<String>.from(_deviceData['phones']);
                    if (i < phones.length) {
                      phones[i] = value;
                      _deviceData['phones'] = phones;
                    }
                  }
                },
              ),
            ),
            if (_phoneControllers.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => _removePhoneNumber(i),
              ),
          ],
        ),
      );
    });
  }
}
