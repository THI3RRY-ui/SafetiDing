import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; // ADDED for utf8 encoding
import 'package:crypto/crypto.dart'; // ADDED for hashing logic
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEmailValid = false;
  bool _obscurePassword = true;

  bool _showToast = false;
  String _toastMessage = "";
  Color _toastColor = const Color(0xFFC62828);
  double _progress = 1.0;
  Timer? _toastTimer;

  // --- HASHING FUNCTION ---
  // This must match the exact logic used in your Signup/Verification page
  String _hashPassword(String password) {
    var bytes = utf8.encode(password); 
    var digest = sha256.convert(bytes);
    return digest.toString(); 
  }

  void _validateEmail() {
    setState(() {
      _isEmailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-z]{3,}$').hasMatch(_emailController.text.trim());
    });
  }

  void _triggerToast(String message, {bool isSuccess = false}) {
    _toastTimer?.cancel();
    setState(() { 
      _toastMessage = message; 
      _showToast = true; 
      _progress = 1.0; 
      _toastColor = isSuccess ? Colors.green.shade800 : const Color(0xFFC62828); 
    });
    _toastTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) setState(() => _progress -= 0.01);
      if (_progress <= 0) { 
        timer.cancel(); 
        if (mounted) setState(() => _showToast = false); 
      }
    });
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_isEmailValid) { _triggerToast("Please enter a valid email"); return; }
    if (password.isEmpty) { _triggerToast("Please enter your password"); return; }
    
    setState(() => _isLoading = true);

 try {
    // 1. You still need the hashed password to match your database
    String hashedInput = _hashPassword(password);

    // 2. AUTHENTICATE with Firebase Auth first
    // Use the email and the HASHED password as the secret
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: hashedInput,
    );

    // 3. Success! Now go to Home
    _triggerToast("Login Successful!", isSuccess: true);
      
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );

  } on FirebaseAuthException catch (e) {
    setState(() => _isLoading = false);
    _triggerToast(e.message ?? "Login Failed");
  } catch (e) {
    setState(() => _isLoading = false);
    _triggerToast("Error: ${e.toString()}");
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
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
                child: Column(
                  children: [
                    _sosLogo(),
                    const SizedBox(height: 30),
                    const Text("Welcome Back", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    
                    TextField(
                      controller: _emailController,
                      onChanged: (_) => _validateEmail(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Email Address", 
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.email, color: _isEmailValid ? Colors.green : const Color(0xFFD84315)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _isEmailValid ? Colors.green : Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _isEmailValid ? Colors.green : const Color(0xFFD84315), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Password", 
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFFD84315)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFFD84315), width: 2)),
                      ),
                    ),

                    const SizedBox(height: 40),
                    _isLoading ? const CircularProgressIndicator(color: Color(0xFFD84315)) : _loginButton(),
                  ],
                ),
              ),
            ),
            
            Positioned(
              top: 50, left: 20,
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

  Widget _sosLogo() => Container(
    width: 100, height: 100, 
    decoration: BoxDecoration(color: const Color(0xFFD84315), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), 
    child: const Center(child: Text("SOS", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)))
  );

  Widget _loginButton() => SizedBox(
    width: double.infinity, height: 60, 
    child: ElevatedButton.icon(
      onPressed: _handleLogin, 
      icon: const Icon(Icons.login, color: Colors.white), 
      label: const Text("Log In", style: TextStyle(fontSize: 20, color: Colors.white)), 
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), 
    )
  );

  Widget _buildToast() => Positioned(
    top: 50, left: 20, right: 20, 
    child: Container(
      padding: const EdgeInsets.all(15), 
      decoration: BoxDecoration(color: _toastColor, borderRadius: BorderRadius.circular(10)), 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => setState(() => _showToast = false),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
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