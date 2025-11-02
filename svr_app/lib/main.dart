import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/Admin/admin_dashboard_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SVRApp());
}

class SVRApp extends StatefulWidget {
  const SVRApp({super.key});

  @override
  State<SVRApp> createState() => _SVRAppState();
}

class _SVRAppState extends State<SVRApp> {
  bool _showingSplash = true;

  @override
  void initState() {
    super.initState();
    _handleSplashScreen();
  }

  Future<void> _handleSplashScreen() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _showingSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVR - Smart Voice Responder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _showingSplash ? const SplashScreen() : const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show splash screen while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<String?>(
            future: _authService.getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              // Route based on user role
              final userRole = roleSnapshot.data;
              print('User role detected: $userRole'); // Debug log
              
              if (userRole == 'super_admin') {
                print('Routing to Admin Dashboard'); // Debug log
                return const AdminDashboardScreen();
              } else {
                print('Routing to User Dashboard'); // Debug log
                return const DashboardScreen();
              }
            },
          );
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}
