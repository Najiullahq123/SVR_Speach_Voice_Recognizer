import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash_image.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.2), // Optional: dark overlay for text visibility
          ),
          // Removed centered text
        ],
      ),
    );
  }
}
