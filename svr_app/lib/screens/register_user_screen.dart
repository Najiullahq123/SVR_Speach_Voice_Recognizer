import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isSubmitting = false;
  bool _passwordObscured = true;
  bool _confirmPasswordObscured = true;
  bool _agreeToTerms = false;
  
  // Password strength variables
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.red;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    double strength = 0.0;
    String strengthText = '';
    Color strengthColor = Colors.red;

    if (password.isEmpty) {
      strength = 0.0;
      strengthText = '';
    } else if (password.length < 6) {
      strength = 0.2;
      strengthText = 'Too Short';
      strengthColor = Colors.red;
    } else {
      // Check various criteria
      bool hasLowercase = password.contains(RegExp(r'[a-z]'));
      bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
      bool hasDigits = password.contains(RegExp(r'[0-9]'));
      bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      bool hasMinLength = password.length >= 8;

      int criteriaCount = 0;
      if (hasLowercase) criteriaCount++;
      if (hasUppercase) criteriaCount++;
      if (hasDigits) criteriaCount++;
      if (hasSpecialCharacters) criteriaCount++;
      if (hasMinLength) criteriaCount++;

      switch (criteriaCount) {
        case 1:
        case 2:
          strength = 0.4;
          strengthText = 'Weak';
          strengthColor = Colors.red;
          break;
        case 3:
          strength = 0.6;
          strengthText = 'Fair';
          strengthColor = Colors.orange;
          break;
        case 4:
          strength = 0.8;
          strengthText = 'Good';
          strengthColor = Colors.blue;
          break;
        case 5:
          strength = 1.0;
          strengthText = 'Strong';
          strengthColor = Colors.green;
          break;
        default:
          strength = 0.2;
          strengthText = 'Weak';
          strengthColor = Colors.red;
      }
    }

    if (mounted) {
      setState(() {
        _passwordStrength = strength;
        _passwordStrengthText = strengthText;
        _passwordStrengthColor = strengthColor;
      });
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    
    List<String> errors = [];
    
    if (value.length < 8) {
      errors.add('At least 8 characters');
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      errors.add('One lowercase letter');
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      errors.add('One uppercase letter');
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      errors.add('One number');
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('One special character');
    }
    
    if (errors.isNotEmpty) {
      return 'Password must contain:\n• ${errors.join('\n• ')}';
    }
    
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms of Service and Privacy Policy'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (mounted) {
      setState(() => _isSubmitting = true);
    }
    
    try {
      final String firstName = _firstNameController.text.trim();
      final String lastName = _lastNameController.text.trim();
      final String email = _emailController.text.trim();
      final String password = _passwordController.text;
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating account...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Create user with Firebase Auth
      final UserCredential? userCredential = await _authService.createUserWithEmailAndPassword(email, password);
      
      if (!mounted) return;
      
      if (userCredential != null && userCredential.user != null) {
        // Update user profile with display name
        await userCredential.user!.updateDisplayName('$firstName $lastName');
        
        // Create user document in Firestore
        try {
          await _firestoreService.createUserDocument(
            userCredential.user!.uid,
            {
              'firstName': firstName,
              'lastName': lastName,
              'email': email,
              'displayName': '$firstName $lastName',
              'role': 'user', // Default role for new registrations
              'isActive': true,
              'profileImageUrl': '', // Empty initially
              'phoneNumber': '', // Can be updated later in profile
              'address': '', // Can be updated later in profile
              'dateOfBirth': '', // Can be updated later in profile
              'deviceCount': 0, // Initial device count
              'lastLoginAt': FieldValue.serverTimestamp(),
            },
          );
          
          // Registration successful
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome $firstName! Account created successfully.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Navigate back to previous screen with email
          Navigator.pop(context, email);
        } catch (firestoreError) {
          // If Firestore save fails, still show success but log the error
          print('Error saving user data to Firestore: $firestoreError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome $firstName! Account created successfully.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, email);
        }
      } else {
        // Registration failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Registration failed';
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          errorMessage = 'Please provide a valid email address.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        default:
          errorMessage = 'Registration failed: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF2FA85E),
      prefixIcon: Icon(icon, color: Colors.white),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFE7FF76), fontSize: 18, fontWeight: FontWeight.bold),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30), 
        borderSide: const BorderSide(color: Colors.red, width: 2)
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30), 
        borderSide: const BorderSide(color: Colors.red, width: 2)
      ),
      errorStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _passwordStrength,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _passwordStrengthText,
              style: TextStyle(
                color: _passwordStrengthColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF126E35),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Create Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF126E35), Color(0xFF0BBD35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo
                  Center(
                    child: Image.asset(
                      'assets/images/logo1.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Full Name Fields
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Color(0xFFE7FF76), fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: _fieldDecoration(hint: 'First Name', icon: Icons.person),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your first name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Color(0xFFE7FF76), fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: _fieldDecoration(hint: 'Last Name', icon: Icons.person_outline),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your last name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Color(0xFFE7FF76), fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: _fieldDecoration(hint: 'Email Address', icon: Icons.email),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email address';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password Field with Strength Indicator
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _passwordObscured,
                    style: const TextStyle(color: Color(0xFFE7FF76), fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: _fieldDecoration(hint: 'Password', icon: Icons.lock).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_passwordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _passwordObscured = !_passwordObscured;
                          });
                        },
                      ),
                    ),
                    onChanged: _checkPasswordStrength,
                    validator: _validatePassword,
                  ),
                  _buildPasswordStrengthIndicator(),
                  const SizedBox(height: 12),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _confirmPasswordObscured,
                    style: const TextStyle(color: Color(0xFFE7FF76), fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: _fieldDecoration(hint: 'Confirm Password', icon: Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_confirmPasswordObscured ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _confirmPasswordObscured = !_confirmPasswordObscured;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Terms of Service Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() {
                            _agreeToTerms = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFFE7FF76),
                        checkColor: const Color(0xFF126E35),
                        side: const BorderSide(color: Colors.white, width: 2),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(
                                    color: Color(0xFFE7FF76),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      // TODO: Navigate to Terms of Service
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Terms of Service page would open here')),
                                      );
                                    },
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                    color: Color(0xFFE7FF76),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      // TODO: Navigate to Privacy Policy
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Privacy Policy page would open here')),
                                      );
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Create Account Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: const StadiumBorder(),
                        elevation: 8,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE7FF76), Color(0xFFB6D94C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'CREATE ACCOUNT',
                                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Link to Login Page
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign In',
                            style: const TextStyle(
                              color: Color(0xFFE7FF76),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
