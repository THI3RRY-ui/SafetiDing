import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Status Bar control
import 'dart:ui';
import 'signup_page.dart';
import 'login_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  double _dragPosition = 0;
  final double _buttonHeight = 80;

  // This ensures the slider is at 0 whenever the page is built/returned to
  void _navigateToSignup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignupPage()),
    );
    // When the user comes back from SignupPage, this code runs:
    setState(() {
      _dragPosition = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // AnnotatedRegion makes the phone's status bar (battery/time) visible
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // White icons
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              // Tactical Overlay Gradient
              Container(color: Colors.black.withOpacity(0.4)),
              
              SafeArea(
                child: Column(
    children: [
      const SizedBox(height: 60),
      
      // --- NEW PRO TACTICAL HEADER ---
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            // Decorative Top Line
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 40, height: 1, color: Colors.redAccent.withOpacity(0.5)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.sensors, color: Colors.redAccent, size: 14),
                ),
                Container(width: 40, height: 1, color: Colors.redAccent.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 15),
            
            // THE MAIN TITLE
            Text(
              "SELF DISTRESS SIGNAL",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24, // Smaller, but more powerful due to spacing
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 8.0, // This makes it look "Pro"
                fontFamily: 'times new roman', // Or any Monospace font
              ),
            ),
            
            const SizedBox(height: 10),
            
            // TACTICAL UNDERLINE & SUBTEXT
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "TRU", // Tactical Response Unit Abbreviation
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 0.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.redAccent, Colors.transparent],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "SYS. ACTIVE",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),


                    const Spacer(),
                    _build3DReactorLogo(),
                    const Spacer(),
                    _buildTacticalSlider(context),
                    const SizedBox(height: 30),
                    
                    // Refined Login Link
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage())),
                      child: RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          children: [
                            TextSpan(
                              text: "LOG IN",
                              style: TextStyle(
                                color: Colors.orangeAccent[700], 
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DReactorLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 40, spreadRadius: 10),
            ],
          ),
        ),
        Container(
          width: 220, height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              colors: [Colors.white24, Colors.black.withOpacity(0.8)],
            ),
            border: Border.all(color: Colors.white24, width: 2),
          ),
        ),
        Container(
          width: 180, height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD84315),
            gradient: const RadialGradient(
              colors: [Color(0xFFFF7043), Color(0xFFBF360C)],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(5, 10), blurRadius: 20),
              const BoxShadow(color: Colors.white30, offset: Offset(-2, -5), blurRadius: 10),
            ],
          ),
          child: const Center(
            child: Text("SOS", style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildTacticalSlider(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width - 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: _buttonHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 90),
                    child: Text(
                      "SLIDE OR TAP TO START",
                      style: TextStyle(
                        color: Colors.white38,
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 2, 
                        fontSize: 12
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragPosition += details.delta.dx;
                if (_dragPosition < 0) _dragPosition = 0;
                if (_dragPosition > maxWidth - 75) _dragPosition = maxWidth - 75;
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragPosition > maxWidth * 0.70) {
                _navigateToSignup();
              } else {
                setState(() => _dragPosition = 0);
              }
            },
            onTap: _navigateToSignup,
            child: Container(
              height: _buttonHeight,
              width: double.infinity,
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned(
                    left: _dragPosition + 5,
                    top: 5,
                    child: Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD84315),
                        boxShadow: [
                          BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: const Icon(Icons.keyboard_double_arrow_right, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
    );
  }
}