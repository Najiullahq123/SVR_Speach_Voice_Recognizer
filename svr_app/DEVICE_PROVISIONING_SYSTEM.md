# Device Provisioning System

## Overview
This implementation adds comprehensive device provisioning features with QR code scanning, WiFi provisioning, and LED status indicators for Raspberry Pi devices.

## Features Added

### 1. QR Code Scanning
- Camera-based QR code scanning
- Device ID extraction from QR codes
- Auto-population of device fields

### 2. WiFi Provisioning
- Detection of device hotspot (HELP_DEVICE_XXXX)
- REST API communication with Raspberry Pi
- WiFi credential transmission

### 3. LED Status Monitoring
- Real-time LED status display
- Visual feedback for device states
- Connection status indicators

### 4. Device States
- **Unprovisioned**: Red LED (waiting for setup)
- **Provisioning**: Blue LED (receiving credentials)
- **Connected**: White LED (online with Firebase)
- **Error**: Blinking Red LED (connection issues)

## Implementation Details

### Dependencies Added:
```yaml
dependencies:
  qr_code_scanner: ^1.0.1
  permission_handler: ^10.4.3
  connectivity_plus: ^4.0.2
  http: ^1.1.0
  wifi_iot: ^0.3.18
```

### New Screens:
- `qr_scanner_screen.dart` - QR code scanning interface
- `device_provisioning_screen.dart` - WiFi provisioning interface
- `provisioning_status_screen.dart` - LED status monitoring

### Enhanced Screens:
- `register_device_screen.dart` - Added QR scanning and provisioning flow
- `device_info_screen.dart` - Added LED status display and re-provisioning

## API Endpoints (Raspberry Pi)

### GET /status
Returns current device status and LED state.

### POST /provision
Accepts WiFi credentials and Firebase configuration.

### GET /led_status
Returns current LED status for monitoring.

## Usage Flow

1. **Scan QR Code**: User scans device QR to get device ID
2. **Enter Details**: User fills device information
3. **Connect to Hotspot**: App detects and connects to device hotspot
4. **Send Credentials**: App sends WiFi and Firebase credentials
5. **Monitor Status**: App monitors LED status for connection confirmation
6. **Complete Setup**: Device goes online with white LED

## Error Handling

- Camera permission management
- WiFi connection timeouts
- API communication failures
- Device offline scenarios
- LED status interpretation

This system provides a seamless device onboarding experience with visual feedback and robust error handling.
