import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'reset_password_screen.dart';

class ResetCodeScreen extends StatefulWidget {
  final String email;
  const ResetCodeScreen({super.key, required this.email});

  @override
  State<ResetCodeScreen> createState() => _ResetCodeScreenState();
}

class _ResetCodeScreenState extends State<ResetCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isVerifying = false;

  void _verifyCode(BuildContext context) {
    setState(() => _isVerifying = true);
    
    // TODO: Implement actual code verification
    Future.delayed(const Duration(seconds: 1), () {
      if (_codeController.text == '123456') { // Temporary validation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(email: widget.email),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid verification code'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isVerifying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF126E35),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Verify Code', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Enter 6-digit code sent to\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2FA85E),
                hintText: '••••••',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isVerifying ? null : () => _verifyCode(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE7FF76),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: _isVerifying
                  ? const CircularProgressIndicator(color: Color(0xFF126E35))
                  : const Text(
                      'Verify Code',
                      style: TextStyle(
                        color: Color(0xFF126E35),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
