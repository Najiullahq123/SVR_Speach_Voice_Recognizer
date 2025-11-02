import 'package:flutter/material.dart';
import 'package:svr_app/screens/activate_device_screen.dart';

class ActivateDeviceIntroScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true,
        title: null,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ActivateDeviceScreen()),
            );
          },
          child: Text('Activate Device'),
        ),
      ),
    );
  }
}
