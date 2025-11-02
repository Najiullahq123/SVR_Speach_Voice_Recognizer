import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _mockMode = false; // Always use real Firebase Auth

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Whether a user is currently considered signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Create user via callable function (requires super_admin)
  Future<Map<String, dynamic>> createUserViaFunction({
    required String email,
    required String password,
    String role = 'user',
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'createUserWithRole',
      );
      final result = await callable.call({
        'email': email,
        'password': password,
        'role': role,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error calling function: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  // Create user with email and password
  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set default role for new users based on email pattern
      if (credential.user != null) {
        String defaultRole = 'user';

        // Check if this should be a super admin based on email
        if (email.contains('superadmin') || email.contains('admin')) {
          defaultRole = 'super_admin';
        }

        // Call your cloud function to set the role (if available)
        try {
          await createUserViaFunction(
            email: email,
            password: password,
            role: defaultRole,
          );
        } catch (e) {
          print('Failed to set default role via cloud function: $e');
          // Fallback: You could set custom claims directly here if needed
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Create Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user role from Firestore user document. Defaults to 'user' if absent.
  Future<String?> getUserRole(String uid) async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Check for local super admin override first
      final prefs = await SharedPreferences.getInstance();
      final localSuperAdmin =
          prefs.getBool('local_super_admin_${user.uid}') ?? false;
      if (localSuperAdmin) {
        print('Local super admin override active for user: ${user.email}');
        return 'super_admin';
      }

      // Get user role from Firestore document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final role = userData?['role'] as String?;
        if (role != null && role.isNotEmpty) {
          print('User role from Firestore: $role for user: ${user.email}');
          return role;
        }
      }

      // Fallback: Check Firebase custom claims
      final IdTokenResult tokenResult = await user.getIdTokenResult(true);
      final Map<String, dynamic>? claims = tokenResult.claims;
      final String? role = claims != null ? claims['role'] as String? : null;

      if (role != null) {
        print('User role from custom claims: $role for user: ${user.email}');
        return role;
      }

      // Final fallback: Check email pattern for existing super admin users
      final email = user.email?.toLowerCase() ?? '';
      if (email.contains('superadmin') || email.contains('admin')) {
        print(
          'Email contains admin pattern: $email - granting super_admin role',
        );
        return 'super_admin';
      }

      print(
        'User email: $email - no admin pattern found, defaulting to user role',
      );
      return 'user';
    } catch (e) {
      print('Error getting user role: $e');
      // Return default role on error
      return 'user';
    }
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    String? role = await getUserRole(_auth.currentUser?.uid ?? '');
    return role == 'super_admin' || role == 'admin';
  }

  // Check if user is super admin
  Future<bool> isSuperAdmin() async {
    String? role = await getUserRole(_auth.currentUser?.uid ?? '');
    return role == 'super_admin';
  }

  // Get user display name
  String? getUserDisplayName() {
    return _auth.currentUser?.displayName;
  }

  // Get user email
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  // Get user UID
  String? getUserUID() {
    return _auth.currentUser?.uid;
  }

  // Check if mock mode is enabled
  bool get isMockMode => _mockMode;

  // Manually set user role (useful for existing users)
  Future<void> setUserRole(String uid, String role) async {
    try {
      await createUserViaFunction(
        email: _auth.currentUser?.email ?? '',
        password: '', // You might need to handle this differently
        role: role,
      );

      // Force refresh the token to get updated claims
      await _auth.currentUser?.getIdTokenResult(true);
    } catch (e) {
      print('Failed to set user role: $e');
      rethrow;
    }
  }

  // Set super admin role for current user (bypasses cloud function for initial setup)
  Future<void> setCurrentUserAsSuperAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Try cloud function first
      try {
        await createUserViaFunction(
          email: user.email!,
          password:
              'temp_password_for_role_update', // This will be ignored by the function
          role: 'super_admin',
        );
        print('Successfully set super admin via cloud function');
      } catch (e) {
        print('Cloud function failed, using local override: $e');
        // Fallback: Set local override if cloud function fails
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('local_super_admin_${user.uid}', true);
        print('Set local super admin override for user: ${user.email}');
      }

      // Force refresh the token to get updated claims
      await user.getIdTokenResult(true);
    } catch (e) {
      print('Failed to set current user as super admin: $e');
      rethrow;
    }
  }

  // Set local super admin override (for development/emergency use)
  Future<void> setLocalSuperAdminOverride() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('local_super_admin_${user.uid}', true);
    print('Local super admin override set for user: ${user.email}');
  }

  // Remove local super admin override
  Future<void> removeLocalSuperAdminOverride() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_super_admin_${user.uid}');
    print('Local super admin override removed for user: ${user.email}');
  }

  // Check if current user should be super admin based on email
  bool get shouldBeSuperAdmin {
    final email = _auth.currentUser?.email ?? '';
    return email.contains('superadmin') || email.contains('admin');
  }
}
