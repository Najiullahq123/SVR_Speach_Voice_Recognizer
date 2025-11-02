import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

// Platform-aware QR scanner wrapper
class PlatformQRScanner {
  static bool get isWebPlatform => kIsWeb;
  
  static Widget buildQRView({
    required Function(String) onQRViewCreated,
    required GlobalKey qrKey,
  }) {
    if (isWebPlatform) {
      // For web, show a manual input alternative
      return _WebQRFallback(onCodeScanned: onQRViewCreated);
    } else {
      // For mobile, use the actual QR scanner
      try {
        // Import dynamically to avoid web compilation issues
        return _MobileQRView(
          onQRViewCreated: onQRViewCreated,
          qrKey: qrKey,
        );
      } catch (e) {
        // Fallback if QR scanner fails
        return _WebQRFallback(onCodeScanned: onQRViewCreated);
      }
    }
  }
}

// Web fallback widget for manual QR code input
class _WebQRFallback extends StatefulWidget {
  final Function(String) onCodeScanned;
  
  const _WebQRFallback({required this.onCodeScanned});
  
  @override
  State<_WebQRFallback> createState() => _WebQRFallbackState();
}

class _WebQRFallbackState extends State<_WebQRFallback> {
  final TextEditingController _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.qr_code_scanner,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          const Text(
            'QR Scanner not available on web',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please enter the device ID manually:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Device ID',
              hintText: 'Enter device ID from QR code',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.devices),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                widget.onCodeScanned(value.trim());
              }
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                widget.onCodeScanned(_controller.text.trim());
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Use This Device ID'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE7FF76),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Note: On mobile devices, this will show a camera scanner',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// Mobile QR view using mobile_scanner package
class _MobileQRView extends StatefulWidget {
  final Function(String) onQRViewCreated;
  final GlobalKey qrKey;
  
  const _MobileQRView({
    required this.onQRViewCreated,
    required this.qrKey,
  });
  
  @override
  State<_MobileQRView> createState() => _MobileQRViewState();
}

class _MobileQRViewState extends State<_MobileQRView> {
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() => _hasPermission = status.isGranted);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Camera permission is required to scan QR codes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestCameraPermission,
              child: const Text('Grant Camera Permission'),
            ),
          ],
        ),
      );
    }

    return MobileScanner(
      key: widget.qrKey,
      onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        if (barcodes.isNotEmpty) {
          final String? code = barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            widget.onQRViewCreated(code);
          }
        }
      },
    );
  }
}
