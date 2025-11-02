import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/platform_qr_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool isScanning = true;
  String? scannedData;

  void _onQRViewCreated(String data) {
    if (isScanning && data.isNotEmpty) {
      setState(() {
        scannedData = data;
        isScanning = false;
      });
      
      // Validate and process the scanned data
      if (_isValidDeviceId(data)) {
        Navigator.pop(context, data);
      } else {
        _showInvalidQRDialog();
      }
    }
  }

  bool _isValidDeviceId(String data) {
    // Basic validation for device ID format
    return data.length >= 3 && data.length <= 50 && !data.contains(' ');
  }

  void _showInvalidQRDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid QR Code'),
        content: const Text(
          'The scanned QR code does not contain a valid device ID. '
          'Please try scanning a different QR code or enter the device ID manually.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => isScanning = true);
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          kIsWeb ? 'Enter Device ID' : 'Scan Device QR Code',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // QR Scanner or Web Input Area
          Expanded(
            flex: 4,
            child: PlatformQRScanner.buildQRView(
              onQRViewCreated: _onQRViewCreated,
              qrKey: qrKey,
            ),
          ),
          
          // Instructions and controls
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!kIsWeb) ...[
                    const Text(
                      'Point your camera at the QR code on the device',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'The QR code is usually on a label attached to the device',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const Text(
                      'Enter the device ID manually',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Find the device ID on the device label or QR code',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
