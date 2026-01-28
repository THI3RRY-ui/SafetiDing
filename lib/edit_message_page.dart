import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class EditMessagePage extends StatefulWidget {
  const EditMessagePage({super.key});

  @override
  State<EditMessagePage> createState() => _EditMessagePageState();
}

class _EditMessagePageState extends State<EditMessagePage> {
  // RULE: Original default text remains as starting value
  final TextEditingController _messageController = TextEditingController(
    text: "EMERGENCY: I need immediate assistance. Please track my location.",
  );

  @override
  void initState() {
    super.initState();
    _syncFromDatabase(); // Silent sync in background
  }

  Future<void> _syncFromDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()?['sos_message'] != null) {
      setState(() {
        _messageController.text = doc.data()!['sos_message'];
      });
    }
  }

  // --- CIRCULAR INFO LAW: POPUP ---
  void _showLawInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), 
          side: const BorderSide(color: Color(0xFFD84315), width: 1.5),
        ),
        title: const Text("MESSAGE SYSTEM", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
          "This message will be sent automatically with your GPS coordinates, profile name and contact during an SOS trigger.",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("UNDERSTOOD", style: TextStyle(color: Color(0xFFD84315))),
          )
        ],
      ),
    );
  }

  // --- SAVE & SYNC LAW ---
Future<void> _saveMessage() async {
    final String newMessage = _messageController.text.trim();
    if (newMessage.isEmpty) return;

    // Show the custom loading spinner
    _showLoadingSpinner(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Set a 30-second timeout for the Firestore operation
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'sos_message': newMessage,
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 30));

        if (mounted) {
          Navigator.pop(context); // Dismiss loading spinner
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("UPDATE SUCCESSFUL: Message Sync Successful", 
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              backgroundColor: Colors.green[800],
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            ),
          );
          Navigator.pop(context); // Go back to previous screen
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading spinner
        
        // Check if error is a timeout or general connection issue
        String errorMsg = "SIGNAL FAILED: Check connection and try again.";
        if (e.toString().contains("TimeoutException")) {
          errorMsg = "CONNECTION TIMEOUT: Please check your internet.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          ),
        );
      }
    }
  }

  void _showLoadingSpinner(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // User cannot tap away while saving
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button from dismissing
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: Color(0xFFD84315),
                strokeWidth: 3,
              ),
              const SizedBox(height: 25),
              const Text(
                "SYNCING CLOUD...",
                style: TextStyle(
                  color: Colors.white, 
                  letterSpacing: 2, 
                  fontSize: 12, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Please do not close the app",
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // LAW: 70% PAGE HEIGHT CONSTRAINT
    final double constrainedHeight = MediaQuery.of(context).size.height * 0.7;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text("MESSAGE CONFIG", 
            style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SizedBox(
                height: constrainedHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Edit Default\nMessage",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        // LAW: CIRCULAR i ICON
                        IconButton(
                          onPressed: _showLawInfo,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // LAW: ORIGINAL MESSAGE RECTANGLE
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white12, width: 2),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                          cursorColor: const Color(0xFFD84315),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Type SOS message...",
                            hintStyle: TextStyle(color: Colors.white10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // LAW: SAVE CHANGES BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 65,
                      child: ElevatedButton(
                        onPressed: _saveMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD84315),
                          shape: const StadiumBorder(),
                          elevation: 8,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_as_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Text(
                              "SAVE CHANGES",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
        bottomNavigationBar: buildCustomFooter(context, -1),
      ),
    );
  }
}