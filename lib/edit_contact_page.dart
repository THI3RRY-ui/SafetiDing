import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class EditContactPage extends StatefulWidget {
  final String contactId;
  final String currentName;
  final String currentPhone;

  const EditContactPage({
    super.key,
    required this.contactId,
    required this.currentName,
    required this.currentPhone,
  });

  @override
  State<EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<EditContactPage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  // --- TOAST/ALERT LOGIC ---
  bool _showToast = false;
  String _toastMessage = "";
  Color _toastColor = const Color(0xFFC62828);
  Timer? _toastTimer;

  // Real-time validity for Green Light effects
  bool _isNameValid = true;
  bool _isPhoneValid = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);
    
    _nameController.addListener(_validateFields);
    _phoneController.addListener(_validateFields);
  }

  void _validateFields() {
    setState(() {
      _isNameValid = _nameController.text.trim().length >= 2;
      // Strict Logic: Starts with 6, followed by 2,5,6,7,8,9, and exactly 9 digits total
      _isPhoneValid = RegExp(r'^6[256789][0-9]{7}$').hasMatch(_phoneController.text.trim());
    });
  }

  // DISMISSIBLE ALERT STYLE
  void _triggerToast(String message, bool isError) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastColor = isError ? const Color(0xFFC62828) : Colors.green.shade800;
      _showToast = true;
    });

    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  Future<void> _updateContact() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (!_isNameValid) {
      _triggerToast("NAME MUST BE AT LEAST 2 CHARACTERS", true);
      return;
    }
    if (!_isPhoneValid) {
      _triggerToast("INVALID PHONE SYNTAX (e.g. 6XXXXXXXX)", true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('emergency_contacts')
            .doc(widget.contactId)
            .update({
          'name': name,
          'phone': phone,
          'lastModified': FieldValue.serverTimestamp(),
        });

        _triggerToast("GRID UPDATED SUCCESSFULLY", false);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      _triggerToast("UPLINK ERROR: $e", true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("MODIFICATION HUB", 
          style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 14)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A0A05), Colors.black, Colors.black],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  const SizedBox(height: 140),
                  
                  // --- REAL-TIME AVATAR PREVIEW ---
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (_isNameValid && _isPhoneValid) 
                          ? [Colors.green, Colors.greenAccent] 
                          : [const Color(0xFFFF5722), const Color(0xFFFF9100)]
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ((_isNameValid && _isPhoneValid) ? Colors.greenAccent : const Color(0xFFFF5722)).withOpacity(0.5),
                          blurRadius: 30, spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : "?",
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- GLASS PANEL FORM ---
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                    ),
                    child: Column(
                      children: [
                        _buildNeonField(
                          controller: _nameController,
                          label: "FULL IDENTITY",
                          icon: Icons.person_outline,
                          isValid: _isNameValid,
                        ),
                        const SizedBox(height: 25),
                        _buildNeonField(
                          controller: _phoneController,
                          label: "FREQUENCY / PHONE",
                          icon: Icons.phone_android_outlined,
                          isPhone: true,
                          isValid: _isPhoneValid,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 50),

                  // --- SHINING ACTION BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateContact,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isNameValid && _isPhoneValid) ? Colors.green.shade700 : const Color(0xFFFF5722),
                        foregroundColor: Colors.white,
                        elevation: 15,
                        shadowColor: ((_isNameValid && _isPhoneValid) ? Colors.greenAccent : const Color(0xFFFF5722)).withOpacity(0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("SYNCHRONIZE CHANGES", 
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // --- YOUR DISMISSIBLE ALERT UI ---
          if (_showToast) _buildAlertLoader(),
        ],
      ),
    );
  }

  Widget _buildAlertLoader() => Positioned(
    top: 100, left: 20, right: 20,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showToast ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _toastColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
          border: Border.all(color: Colors.white24)
        ),
        child: Row(
          children: [
            const Icon(Icons.gpp_maybe, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_toastMessage, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            GestureDetector(
              onTap: () => setState(() => _showToast = false),
              child: const Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildNeonField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    required bool isValid,
    bool isPhone = false
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
        TextField(
          controller: controller,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: isValid ? Colors.greenAccent : const Color(0xFFFF5722)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: isValid ? Colors.greenAccent.withOpacity(0.5) : Colors.white.withOpacity(0.2), 
                width: 1.5
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: isValid ? Colors.greenAccent : const Color(0xFFFF5722), 
                width: 2
              ),
            ),
          ),
        ),
      ],
    );
  }
}