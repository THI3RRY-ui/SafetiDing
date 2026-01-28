import 'package:flutter/material.dart';
import 'dart:async';
import 'package:email_otp/email_otp.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class VerificationPage extends StatefulWidget {
  final String type; 
  final String destination;
  final String phoneValue;
  final String userName;
  final String passwordValue;
  final EmailOTP authSession;

  const VerificationPage({
    super.key, 
    required this.type, 
    required this.destination, 
    required this.phoneValue,
    required this.userName,
    required this.passwordValue,
    required this.authSession,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final List<TextEditingController> _controllers = List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());

  bool _isVerifying = false;
  bool _showToast = false;
  String _toastMessage = "";
  Color _toastColor = const Color(0xFFC62828);
  double _progress = 1.0;
  Timer? _toastTimer;

//hashing function
  String hashPassword(String password) {
  var bytes = utf8.encode(password); // Convert string to bytes
  var digest = sha256.convert(bytes); // Apply SHA-256
  return digest.toString(); // Return hashed string
}

  void _triggerToast(String message, {bool isSuccess = false}) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _showToast = true;
      _progress = 1.0;
      _toastColor = isSuccess ? Colors.green.shade800 : const Color(0xFFC62828);
    });

    const duration = Duration(seconds: 10);
    const interval = Duration(milliseconds: 100);
    int totalSteps = duration.inMilliseconds ~/ interval.inMilliseconds;
    int currentStep = 0;

    _toastTimer = Timer.periodic(interval, (timer) {
      currentStep++;
      if (mounted) setState(() => _progress = 1.0 - (currentStep / totalSteps));
      if (currentStep >= totalSteps) {
        timer.cancel();
        if (mounted) setState(() => _showToast = false);
      }
    });
  }



  Future<void> _handleVerify() async {
    String code = _controllers.map((e) => e.text).join();
    if (code.length < 5) {
      _triggerToast("Enter all 5 digits");
      return;
    }

    setState(() => _isVerifying = true);

    if (await widget.authSession.verifyOTP(otp: code)) {
  try {
    String hashedPassword = hashPassword(widget.passwordValue);

    // CREATE the user in Firebase Auth
    UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: widget.destination,
      password: hashedPassword,
    );

    // SAVE details to Firestore using the NEW UID
    await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
      'name': widget.userName,
      'email': widget.destination,
      'phone': widget.phoneValue,
      'password': hashedPassword,
      'uid': userCred.user!.uid,
    });

        _triggerToast("VERIFICATION SUCCESSFUL!", isSuccess: true);
        
        await Future.delayed(const Duration(milliseconds: 1500));
        setState(() => _isVerifying = false);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      } catch (e) {
        setState(() => _isVerifying = false);
        _triggerToast("Error: $e");
      }
    } else {
      setState(() => _isVerifying = false);
      _triggerToast("Invalid Code!");
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
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: IconButton(icon: const Icon(Icons.arrow_circle_left, size: 50, color: Colors.grey), onPressed: () => Navigator.pop(context))),
                    _sosLogo(),
                    const SizedBox(height: 25),
                    const Text("VERIFY EMAIL", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),
                    // NEW: Centered and adjusted squares
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => _otpBox(i))),
                    const SizedBox(height: 30),
                    Text("Code sent to: ${widget.destination}", style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 50),
                    _isVerifying ? const CircularProgressIndicator(color: Color(0xFFD84315)) : _verifyButton(),
                  ],
                ),
              ),
            ),
            if (_showToast) _buildToast(),
          ],
        ),
      ),
    );
  }

  Widget _buildToast() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 15),
        color: _toastColor,
        child: Column(
          children: [
            Row(
              children: [
                Icon(_toastColor == Colors.green.shade800 ? Icons.check_circle : Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(_toastMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _showToast = false))
              ],
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: _progress, backgroundColor: Colors.white24, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // UPDATED: Sizing logic for the OTP boxes
  Widget _otpBox(int index) => Container(
    width: 55, height: 60, // Shorter and more square
    margin: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(color: const Color(0xFFC4C4C4), borderRadius: BorderRadius.circular(15)),
    child: TextField(
      controller: _controllers[index], focusNode: _focusNodes[index],
      textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 1,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
      decoration: const InputDecoration(counterText: "", border: InputBorder.none),
      onChanged: (v) {
        if (v.length == 1 && index < 4) _focusNodes[index + 1].requestFocus();
        if (v.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
      },
    ),
  );

  Widget _sosLogo() => Container(width: 100, height: 100, decoration: BoxDecoration(color: const Color(0xFFD84315), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: const Center(child: Text("SOS", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))));
  
  Widget _verifyButton() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: SizedBox(
      width: double.infinity, height: 55, 
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check_circle, color: Colors.white), // RESTORED ICON
        onPressed: _handleVerify, 
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), 
        label: const Text("Verify", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold))
      )
    ),
  );
}