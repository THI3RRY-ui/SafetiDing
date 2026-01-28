import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 
import 'welcome_page.dart';
import 'home_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("FIREBASE ERROR: $e");
  }
  runApp(const SOSApp());
}

class SOSApp extends StatelessWidget {
  const SOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SOS App',
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Check if we are still loading the auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Color(0xFFD84315))),
            );
          }

          // 2. If a session exists, verify the user is still in the database
          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
              builder: (context, userDoc) {
                if (userDoc.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Colors.black, 
                    body: Center(child: CircularProgressIndicator(color: Color(0xFFD84315)))
                  );
                }

                // If user was deleted from Firestore, force logout
                if (!userDoc.hasData || !userDoc.data!.exists) {
                  FirebaseAuth.instance.signOut();
                  return const WelcomePage();
                }

                // User exists in both Auth and Firestore, go to Home
                return const HomePage();
              },
            );
          }

          // 3. No session found, show Welcome Screen
          return const WelcomePage();
        },
      ),
    );
  }
}