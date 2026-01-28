import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isNameValid = false;
  bool _isPhoneValid = false;

  // --- 1. ADDED THE DIALOG FUNCTION (Required for the duplicate check) ---
  void _showDuplicateNumberDialog(BuildContext context, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD84315), width: 1),
        ),
        title: const Text("DUPLICATE NUMBER", 
          style: TextStyle(color: Color(0xFFD84315), fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text("The number $phone is already assigned to a contact in your emergency grid.", 
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- CAMEROON VALIDATION LOGIC (UNCHANGED) ---
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required';
    if (value.trim().length < 2) return 'Minimum 2 characters required';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Mobile number is required';
    String cleanVal = value.replaceAll(' ', '');
    String pattern = r'^((\+237|237)?)6[25789][0-9]{7}$';
    if (!RegExp(pattern).hasMatch(cleanVal)) {
      return 'Invalid: 9 digits starting with 6[2,5,7,8,9]';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        body: Stack(
          children: [
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD84315).withOpacity(0.08),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildAppBar(),
                      const SizedBox(height: 40),
                      _buildInputCard(),
                      const SizedBox(height: 45),
                      _buildCreateButton(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: buildCustomFooter(context, -1),
      ),
    );
  }

  Widget _buildAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
        ),
        const Text("CREATE CONTACT", style: TextStyle(color: Colors.white, letterSpacing: 3, fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C), 
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: (_isNameValid && _isPhoneValid) ? Colors.green.withOpacity(0.6) : Colors.white10, width: 2),
      ),
      child: Column(
        children: [
          _buildInputField(
            controller: _nameController,
            label: "FULL NAME",
            hint: "Enter Name",
            icon: Icons.person_outline_rounded,
            isValid: _isNameValid,
            validator: _validateName,
            onChanged: (val) => setState(() => _isNameValid = _validateName(val) == null),
          ),
          const SizedBox(height: 30),
          _buildInputField(
            controller: _phoneController,
            label: "MOBILE NUMBER",
            hint: "6xx xxx xxx",
            icon: Icons.phone_android_rounded,
            keyboard: TextInputType.phone,
            isValid: _isPhoneValid,
            validator: _validatePhone,
            onChanged: (val) => setState(() => _isPhoneValid = _validatePhone(val) == null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required String hint, required IconData icon, required bool isValid, required String? Function(String?) validator, required Function(String) onChanged, TextInputType keyboard = TextInputType.text}) {
    final activeColor = isValid ? Colors.greenAccent : const Color(0xFFD84315);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller, validator: validator, onChanged: onChanged, keyboardType: keyboard,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          cursorColor: activeColor,
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
            prefixIcon: Icon(icon, color: activeColor, size: 22),
            filled: true, fillColor: Colors.black.withOpacity(0.3),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: activeColor, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    bool isReady = _isNameValid && _isPhoneValid;
    return InkWell(
      onTap: () async {
        if (_formKey.currentState!.validate()) {
          final String phone = _phoneController.text.trim();
          final String name = _nameController.text.trim();
          final user = FirebaseAuth.instance.currentUser;

          if (user != null) {
            try {
              // --- DUPLICATE CHECK LOGIC ---
              final duplicateCheck = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('emergency_contacts') // Fixed Collection Name
                  .where('phone', isEqualTo: phone)
                  .get();

              if (duplicateCheck.docs.isNotEmpty) {
                if (!mounted) return;
                _showDuplicateNumberDialog(context, phone);
                return; 
              }

              // --- SAVE LOGIC ---
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('emergency_contacts') // Fixed Collection Name
                  .add({
                'name': name,
                'phone': phone,
                'timestamp': FieldValue.serverTimestamp(),
              });

              if (mounted) Navigator.pop(context);
              
            } catch (e) {
              debugPrint("Firebase Error: $e");
            }
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity, height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: isReady ? [Colors.green.shade700, Colors.greenAccent.shade700] : [const Color(0xFFD84315), const Color(0xFFE64A19)],
          ),
          boxShadow: [BoxShadow(color: (isReady ? Colors.green : const Color(0xFFD84315)).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isReady ? Icons.check_circle_outline : Icons.add_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Text("CREATE CONTACT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}