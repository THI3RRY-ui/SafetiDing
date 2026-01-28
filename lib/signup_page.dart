import 'package:flutter/material.dart';
import 'dart:async';
import 'package:email_otp/email_otp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verification_page.dart';


class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(); // ADDED: Password controller

  bool _nameTouched = false;
  bool _phoneTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false; // ADDED: Track if password field was interacted with
  bool _obscurePassword = true; // ADDED: Toggle for password visibility

  EmailOTP myAuth = EmailOTP(); 
  bool _isLoading = false;

  bool _showToast = false;
  String _toastMessage = "";
  Color _toastColor = const Color(0xFFC62828);
  double _progress = 1.0;
  Timer? _toastTimer;

  bool get _isNameValid => _nameController.text.trim().length >= 2;
  bool get _isPhoneValid => RegExp(r'^6[25789][0-9]{7}$').hasMatch(_phoneController.text.trim());
  bool get _isEmailValid => RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-z]{3,}$').hasMatch(_emailController.text.trim());
  
  // ADDED: Logic for minimum 8 characters and at least one number
  bool get _isPasswordValid => 
      _passwordController.text.length >= 8 && 
      _passwordController.text.contains(RegExp(r'[0-9]'));

  void _triggerToast(String message, {bool isSuccess = false}) {
    _toastTimer?.cancel();
    setState(() { 
      _toastMessage = message; 
      _showToast = true; 
      _progress = 1.0; 
      _toastColor = isSuccess ? Colors.green.shade800 : const Color(0xFFC62828); 
    });
    _toastTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) setState(() => _progress -= 0.01);
      if (_progress <= 0) { 
        timer.cancel(); 
        if (mounted) setState(() => _showToast = false); 
      }
    });
  }

void _handleSignup() async {
  if (!_isNameValid) { _triggerToast("Full Name must be at least 2 letters"); return; }
  if (!_isPhoneValid) { _triggerToast("Please enter a valid Cameroon phone number"); return; }
  if (!_isEmailValid) { _triggerToast("Please enter a valid email address"); return; }
  if (!_isPasswordValid) { _triggerToast("Password must be 8+ characters with a number"); return; }

  setState(() => _isLoading = true);

  try {
    // 1. Check if user exists
    final existingUser = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: _emailController.text.trim())
        .get();

    if (existingUser.docs.isNotEmpty) {
      setState(() => _isLoading = false);
      _triggerToast("This email is already registered.");
      return;
    }

    // 2. CONFIGURE OTP (Critical Update)
    // We set config and SMTP every time to ensure the phone knows exactly where to go
    myAuth.setConfig(
      appEmail: "mihthierry237@gmail.com", 
      appName: "SOS App", 
      userEmail: _emailController.text.trim(), 
      otpLength: 5, 
      otpType: OTPType.digitsOnly
    );

    myAuth.setSMTP(
      host: "smtp.gmail.com", 
      auth: true, 
      username: "mihthierry237@gmail.com", 
      password: "wjzfvdxghakmasfs", // Ensure this is a 16-character App Password
      secure: "tls", 
      port: 587
    );

    // 3. SEND OTP
    bool result = await myAuth.sendOTP();
    
    if (result) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => VerificationPage(
        type: "Signup", 
        destination: _emailController.text.trim(), 
        userName: _nameController.text.trim(), 
        phoneValue: _phoneController.text.trim(), 
        passwordValue: _passwordController.text, 
        authSession: myAuth
      )));
    } else {
      // If result is false, the SMTP failed
      setState(() => _isLoading = false);
      _triggerToast("Failed to send OTP. Please try again.");
    }

  } catch (e) {
    setState(() => _isLoading = false);
    debugPrint("SIGNUP ERROR: $e");
    // If it's the specific host lookup error, we give a better message
    if (e.toString().contains("Failed host lookup")) {
      _triggerToast("Check your internet connection and try again");
    } else {
      _triggerToast("System Error: ${e.toString()}");
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), 
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
                child: Column(
                  children: [
                    const SizedBox(height: 30), 
                    _sosLogo(),
                    const SizedBox(height: 20),
                    const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),
                    
                    _inputField(
                      label: "Full Name",
                      icon: Icons.person,
                      controller: _nameController,
                      isValid: _isNameValid,
                      isTouched: _nameTouched,
                      errorText: "Name is too short, minimum 2 letters",
                      onChanged: (v) => setState(() => _nameTouched = true),
                    ),
                    const SizedBox(height: 20),
                    _inputField(
                      label: "Phone Number",
                      icon: Icons.phone_android,
                      controller: _phoneController,
                      isValid: _isPhoneValid,
                      isTouched: _phoneTouched,
                      errorText: "Format: 6XXXXXXXX",
                      type: TextInputType.phone,
                      onChanged: (v) => setState(() => _phoneTouched = true),
                    ),
                    const SizedBox(height: 20),
                    _inputField(
                      label: "Email Address",
                      icon: Icons.email,
                      controller: _emailController,
                      isValid: _isEmailValid,
                      isTouched: _emailTouched,
                      errorText: "Invalid email format, e.g name@gmail.com",
                      type: TextInputType.emailAddress,
                      onChanged: (v) => setState(() => _emailTouched = true),
                    ),
                    const SizedBox(height: 20),
                    
                    // ADDED: PASSWORD FIELD WITH EYE TOGGLE
                    _passwordInputField(),

                    const SizedBox(height: 40),
                    _isLoading ? const CircularProgressIndicator(color: Color(0xFFD84315)) : _signupButton(),
                  ],
                ),
              ),
            ),
            
            Positioned(
              top: 50,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            if (_showToast) _buildToast(),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool isValid,
    required bool isTouched,
    required String errorText,
    required Function(String) onChanged,
    TextInputType type = TextInputType.text,
  }) {
    bool showRedError = isTouched && !isValid;
    return TextField(
      controller: controller,
      keyboardType: type,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true, 
        fillColor: Colors.black45,
        prefixIcon: Icon(icon, color: isValid ? Colors.green : (showRedError ? Colors.red : const Color(0xFFD84315))),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        errorText: showRedError ? errorText : null,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: showRedError ? Colors.red : Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: isValid ? Colors.green : const Color(0xFFD84315), width: 2)),
      ),
    );
  }

  // ADDED: Separate widget for Password Field with toggle visibility
  Widget _passwordInputField() {
    bool showRedError = _passwordTouched && !_isPasswordValid;
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      onChanged: (v) => setState(() => _passwordTouched = true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black45,
        prefixIcon: Icon(Icons.lock, color: _isPasswordValid ? Colors.green : (showRedError ? Colors.red : const Color(0xFFD84315))),
        labelText: "Password",
        labelStyle: const TextStyle(color: Colors.white70),
        errorText: showRedError ? "Min 8 chars, must include a number" : null,
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: showRedError ? Colors.red : Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _isPasswordValid ? Colors.green : const Color(0xFFD84315), width: 2)),
      ),
    );
  }

  Widget _sosLogo() => Container(width: 100, height: 100, decoration: BoxDecoration(color: const Color(0xFFD84315), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: const Center(child: Text("SOS", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))));
  
  Widget _signupButton() => SizedBox(
    width: double.infinity, height: 60, 
    child: ElevatedButton.icon(
      icon: const Icon(Icons.groups, color: Colors.white, size: 30),
      label: const Text("Sign Up", style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
      onPressed: _handleSignup,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35))),
    ),
  );

  Widget _buildToast() => Positioned(
    top: 50, left: 20, right: 20, 
    child: Container(
      padding: const EdgeInsets.all(15), 
      decoration: BoxDecoration(color: _toastColor, borderRadius: BorderRadius.circular(10)), 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ADDED: X Button to dismiss alerts
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => setState(() => _showToast = false),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          Text(_toastMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: _progress, color: Colors.white, backgroundColor: Colors.white24)
        ]
      )
    )
  );
}