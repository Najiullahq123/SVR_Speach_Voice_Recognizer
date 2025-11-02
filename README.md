
# svr_app
 
 A Flutter project.
 
 ## Getting Started
 
 This project is a starting point for a Flutter application and the mobile
 client used by the SVR system. It contains the app screens used for:
 
 - Device provisioning and management (Admin)
 - User login and profile flows
 - Notifications and analytics dashboards
 
 ### Quick start
 
 1. Open a terminal in this folder:
 
 ```powershell
 cd "D:\SVR Project\New folder\SVR_Project\svr_app"
 ```
 
 2. Install dependencies:
 
 ```powershell
 flutter pub get
 ```
 
 3. Run analyzer:
 
 ```powershell
 flutter analyze
 ```
 
 4. Run on an emulator/device:
 
 ```powershell
 flutter run
 ```
 
 ## About this app
 
 The mobile client manages device provisioning, shows device status and logs,
 and provides admin tools. It integrates with Firebase and server-side
 provisioning logic defined in the repository.
 
 ## Device: how it's made (hardware & firmware)
 
 This section summarizes the typical hardware, firmware stack, and factory
 process for SVR devices.
 
 Hardware components (typical):
 
 - Single Board Computer (e.g., Raspberry Pi)
 - Microphone(s) — Respeaker array depending on accuracy requirements
 - Wi‑Fi module (embedded)
 - Speaker for voice feedback
 - Power supply, enclosure, and necessary peripherals
 
 Firmware & software stack:
 
 - Bootloader and base OS (Linux/RTOS) on SBCs/microcontrollers
 - Device agent (Python / Node / C++ binary) — performs audio capture,
	 local pre-processing, and communicates securely with backend services
 - Optional on-device speech models or cloud-based speech API integration
 - Secure local storage for device credentials / tokens
 
 Factory / assembly flow (high level):
 
 1. Produce or assemble the hardware (PCB assembly if applicable).
 2. Flash base firmware image (OS + agent) in factory; keep long-lived
		credentials out of the image.
 3. Run QA tests (network, audio capture, sensors) and assign a device ID.
 4. Log the device serial/ID into inventory and ship.
 
 Security note: avoid shipping images with embedded API keys. Provision
 unique credentials at first boot or during a secure factory step.
 
 ## Device setup & provisioning (practical guide)
 
 The app supports QR-based provisioning (preferred) and manual entry. Follow
 these steps to register a device and assign it to your project.
 
 1) Admin pre-steps
		- Ensure Firebase and server functions are deployed and you have an admin
			account in the mobile app.
 
 2) Device provisioning mode
		- Devices should boot into a provisioning mode when first powered or after
			a factory reset. In that mode they either:
			- Display a QR code containing a deviceId + short token, and/or
			- Broadcast a provisioning token via LAN (mDNS/UDP) for the app to
				discover.
 
 3) Mobile app flow
		- Sign in to the app as User → `Register Device`.
		- Tap `Scan QR` and scan the device QR payload, or choose `Manual` and
			enter the deviceId + provisioning token.
		- The app calls the provisioning endpoint which validates the token and
			issues short-lived credentials for the device.
 
 4) Secure credentials
		- The backend returns short-lived tokens or signed certificates which the
			device stores in secure storage and uses for subsequent API/Firestore
			authentication.
 
 5) Verify
		- After provisioning the device reports `online` status. Check the Admin
			dashboard for `lastSeen` and health info.
 
 6) Reprovisioning/reset
		- Clear the device credentials (factory reset) and re-run provisioning.
 
 ### Example QR payload
 
 Embed JSON into the QR code. Example payload:
 
 ```json
 {
	 "deviceId": "SVR-000123",
	 "model": "SVR-v2",
	 "provisionToken": "short-lived-token-abc123",
	 "wifi": { "ssid": "SiteSSID", "secure": true }
 }
 ```
 
 ### Security Recommendations
 
 - Use short-lived provisioning tokens and rotate keys.
 - Validate tokens server-side before issuing credentials.
 - Use TLS for all device→server communication and consider certificate
	 pinning where possible.
 
 ### OTA & maintenance
 
 - Support signed OTA updates with verification and rollback.
 - Monitor update results and provide remote diagnostics in the Admin UI.
 
 ## Where to find device docs in this repo
 
 - `DEVICE_PROVISIONING_SYSTEM.md` — architectural notes and sequence diagrams
 - `DEVICE_COUNT_SYNC_FIX.md` — known sync edge-cases and fixes
 
 ---
 
 If you want, I can:
 
 - Extract the exact QR schema from `dataconnect/schema` and add it here.
 - Add a PowerShell helper script to generate QR payloads and perform a test
	 provisioning request.
 
 Tell me which of those you want next and I will implement it.
