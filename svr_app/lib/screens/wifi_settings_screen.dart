import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class WiFiSettingsScreen extends StatefulWidget {
  const WiFiSettingsScreen({Key? key}) : super(key: key);

  @override
  State<WiFiSettingsScreen> createState() => _WiFiSettingsScreenState();
}

class _WiFiSettingsScreenState extends State<WiFiSettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _savedNetworks = [];
  List<Map<String, dynamic>> _availableNetworks = [];
  bool _isScanning = false;
  bool _isLoading = true;
  bool _isWiFiEnabled = true;
  
  final TextEditingController _networkNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedSecurity = 'WPA2';
  
  @override
  void initState() {
    super.initState();
    _loadDataInParallel();
  }

  @override
  void dispose() {
    _networkNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadDataInParallel() async {
    // Load saved networks and scan for available networks in parallel
    final futures = [
      _loadSavedNetworks(),
      _scanForNetworks(),
    ];
    
    await Future.wait(futures);
  }

  Future<void> _loadSavedNetworks() async {
    try {
      setState(() => _isLoading = true);
      
      final uid = _authService.getUserUID();
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load saved WiFi networks for the user
      final userDoc = await _firestoreService.getUserDocument(uid);
      final networks = userDoc?['wifiNetworks'] as List<dynamic>? ?? [];
      
      if (mounted) {
        setState(() {
          _savedNetworks = networks.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading saved networks: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load saved networks: $e');
      }
    }
  }

  Future<void> _scanForNetworks() async {
    try {
      setState(() => _isScanning = true);
      
      // Reduce delay for faster loading (simulate WiFi scanning)
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Mock available networks
      final mockNetworks = [
        {
          'ssid': 'Home_WiFi_5G',
          'signal': -35,
          'security': 'WPA2',
          'frequency': '5GHz',
          'isConnected': false,
        },
        {
          'ssid': 'Office_Network',
          'signal': -45,
          'security': 'WPA3',
          'frequency': '2.4GHz',
          'isConnected': true,
        },
        {
          'ssid': 'Guest_Network',
          'signal': -60,
          'security': 'Open',
          'frequency': '2.4GHz',
          'isConnected': false,
        },
        {
          'ssid': 'Neighbor_WiFi',
          'signal': -75,
          'security': 'WPA2',
          'frequency': '5GHz',
          'isConnected': false,
        },
        {
          'ssid': 'SVR_Device_AP',
          'signal': -25,
          'security': 'WPA2',
          'frequency': '2.4GHz',
          'isConnected': false,
        },
      ];
      
      setState(() {
        _availableNetworks = mockNetworks;
        _isScanning = false;
      });
    } catch (e) {
      print('Error scanning networks: $e');
      setState(() => _isScanning = false);
      _showErrorSnackBar('Failed to scan networks: $e');
    }
  }

  Future<void> _saveNetworkConfiguration(String ssid, String password, String security) async {
    try {
      final uid = _authService.getUserUID();
      if (uid == null) return;

      final networkConfig = {
        'ssid': ssid,
        'password': password,
        'security': security,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'isActive': false,
      };

      // Add to saved networks list
      final updatedNetworks = List<Map<String, dynamic>>.from(_savedNetworks);
      
      // Remove existing network with same SSID
      updatedNetworks.removeWhere((network) => network['ssid'] == ssid);
      
      // Add new configuration
      updatedNetworks.insert(0, networkConfig);

      // Update user document
      await _firestoreService.updateUserDocument(uid, {
        'wifiNetworks': updatedNetworks,
        'lastWiFiUpdate': DateTime.now().millisecondsSinceEpoch,
      });

      setState(() {
        _savedNetworks = updatedNetworks;
      });

      _showSuccessSnackBar('WiFi network saved successfully');
      Navigator.of(context).pop(); // Close the add network dialog
    } catch (e) {
      print('Error saving network: $e');
      _showErrorSnackBar('Failed to save network: $e');
    }
  }

  Future<void> _connectToNetwork(Map<String, dynamic> network) async {
    try {
      // Simulate connection process
      _showLoadingDialog('Connecting to ${network['ssid']}...');
      
      await Future.delayed(const Duration(seconds: 3));
      
      Navigator.of(context).pop(); // Close loading dialog
      
      // Update connection status
      setState(() {
        for (var net in _availableNetworks) {
          net['isConnected'] = net['ssid'] == network['ssid'];
        }
      });
      
      _showSuccessSnackBar('Connected to ${network['ssid']}');
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar('Failed to connect: $e');
    }
  }

  Future<void> _forgetNetwork(String ssid) async {
    try {
      final uid = _authService.getUserUID();
      if (uid == null) return;

      final updatedNetworks = _savedNetworks.where((network) => network['ssid'] != ssid).toList();

      await _firestoreService.updateUserDocument(uid, {
        'wifiNetworks': updatedNetworks,
        'lastWiFiUpdate': DateTime.now().millisecondsSinceEpoch,
      });

      setState(() {
        _savedNetworks = updatedNetworks;
      });

      _showSuccessSnackBar('Network forgotten');
    } catch (e) {
      print('Error forgetting network: $e');
      _showErrorSnackBar('Failed to forget network: $e');
    }
  }

  void _showAddNetworkDialog() {
    _networkNameController.clear();
    _passwordController.clear();
    _selectedSecurity = 'WPA2';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF126E35),
              title: const Text(
                'Add WiFi Network',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Network Name
                    TextFormField(
                      controller: _networkNameController,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFE7FF76),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        labelText: 'Network Name (SSID)',
                        labelStyle: TextStyle(color: Colors.black54),
                        prefixIcon: Icon(Icons.wifi, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Security Type
                    DropdownButtonFormField<String>(
                      value: _selectedSecurity,
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedSecurity = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFE7FF76),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                        labelText: 'Security',
                        labelStyle: TextStyle(color: Colors.black54),
                        prefixIcon: Icon(Icons.security, color: Colors.black54),
                      ),
                      dropdownColor: const Color(0xFFE7FF76),
                      style: const TextStyle(color: Colors.black),
                      items: const [
                        DropdownMenuItem(value: 'Open', child: Text('Open')),
                        DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                        DropdownMenuItem(value: 'WPA', child: Text('WPA')),
                        DropdownMenuItem(value: 'WPA2', child: Text('WPA2')),
                        DropdownMenuItem(value: 'WPA3', child: Text('WPA3')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Password (only if not Open)
                    if (_selectedSecurity != 'Open')
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.black),
                        obscureText: true,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFE7FF76),
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.black54),
                          prefixIcon: Icon(Icons.lock, color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final ssid = _networkNameController.text.trim();
                    final password = _passwordController.text.trim();
                    
                    if (ssid.isEmpty) {
                      _showErrorSnackBar('Please enter network name');
                      return;
                    }
                    
                    if (_selectedSecurity != 'Open' && password.isEmpty) {
                      _showErrorSnackBar('Please enter password');
                      return;
                    }
                    
                    _saveNetworkConfiguration(ssid, password, _selectedSecurity);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE7FF76),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF126E35),
          content: Row(
            children: [
              const CircularProgressIndicator(color: Color(0xFFE7FF76)),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE7FF76),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF126E35),
      appBar: AppBar(
        backgroundColor: const Color(0xFF126E35),
        elevation: 0,
        title: const Text(
          'WiFi Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: _isScanning 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isScanning ? null : _scanForNetworks,
            tooltip: 'Scan for networks',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE7FF76)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // WiFi Toggle
                    _buildWiFiToggleCard(),
                    const SizedBox(height: 16),

                    // Available Networks
                    _buildAvailableNetworksSection(),
                    const SizedBox(height: 16),

                    // Saved Networks
                    _buildSavedNetworksSection(),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNetworkDialog,
        backgroundColor: const Color(0xFFE7FF76),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
        tooltip: 'Add Network',
      ),
    );
  }

  Widget _buildWiFiToggleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFE7FF76),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WiFi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isWiFiEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isWiFiEnabled,
            onChanged: (value) {
              setState(() {
                _isWiFiEnabled = value;
              });
            },
            activeColor: const Color(0xFFE7FF76),
            activeTrackColor: const Color(0xFFE7FF76).withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableNetworksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Available Networks',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isScanning)
              const Text(
                'Scanning...',
                style: TextStyle(
                  color: Color(0xFFE7FF76),
                  fontSize: 14,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: _availableNetworks.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.wifi_off,
                          color: Colors.white.withOpacity(0.5),
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No networks found',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _availableNetworks.length,
                  itemBuilder: (context, index) {
                    final network = _availableNetworks[index];
                    return _buildNetworkTile(network, isAvailable: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSavedNetworksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saved Networks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: _savedNetworks.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.wifi_protected_setup,
                          color: Colors.white.withOpacity(0.5),
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No saved networks',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _savedNetworks.length,
                  itemBuilder: (context, index) {
                    final network = _savedNetworks[index];
                    return _buildNetworkTile(network, isAvailable: false);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNetworkTile(Map<String, dynamic> network, {required bool isAvailable}) {
    final bool isConnected = network['isConnected'] ?? false;
    final int signal = network['signal'] ?? -100;
    final String ssid = network['ssid'] ?? 'Unknown';
    final String security = network['security'] ?? 'Unknown';
    
    IconData signalIcon;
    if (signal > -50) {
      signalIcon = Icons.wifi;
    } else if (signal > -65) {
      signalIcon = Icons.wifi_2_bar;
    } else if (signal > -80) {
      signalIcon = Icons.wifi_1_bar;
    } else {
      signalIcon = Icons.wifi_off;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isConnected ? const Color(0xFFE7FF76) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            signalIcon,
            color: isConnected ? Colors.black : Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          ssid,
          style: TextStyle(
            color: isConnected ? const Color(0xFFE7FF76) : Colors.white,
            fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '${security}${isConnected ? ' • Connected' : ''}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        trailing: isAvailable
            ? IconButton(
                icon: Icon(
                  isConnected ? Icons.check_circle : Icons.arrow_forward_ios,
                  color: isConnected ? const Color(0xFFE7FF76) : Colors.white.withOpacity(0.7),
                  size: 16,
                ),
                onPressed: isConnected ? null : () => _connectToNetwork(network),
              )
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                onSelected: (value) {
                  if (value == 'forget') {
                    _forgetNetwork(ssid);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'forget',
                    child: Text('Forget'),
                  ),
                ],
              ),
        onTap: isAvailable && !isConnected ? () => _connectToNetwork(network) : null,
      ),
    );
  }
}
