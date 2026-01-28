import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for real-time check
import 'select_contacts_page.dart';
import 'edit_message_page.dart';
import 'add_contact_page.dart';
import 'welcome_page.dart';
import 'inbox_page.dart';
import 'sos_selection_page.dart';


class TacticalPulse extends StatefulWidget {
  final bool isActive;
  final Widget child;

  const TacticalPulse({super.key, required this.isActive, required this.child});

  @override
  State<TacticalPulse> createState() => _TacticalPulseState();
}

class _TacticalPulseState extends State<TacticalPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return widget.child;

    return Stack(
      alignment: Alignment.center,
      children: [
        // This is the "Ghost" layer that doesn't affect the glass box
        SizedBox(
          width: 0, 
          height: 0,
          child: OverflowBox(
            minWidth: 0,
            maxWidth: 400, // Large enough for waves
            minHeight: 0,
            maxHeight: 400,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (index) {
                    double progress = (_controller.value + (index / 3)) % 1.0;
                    return Container(
                      width: 180 + (progress * 120),
                      height: 180 + (progress * 120),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD84315).withOpacity(0.4 * (1.0 - progress)),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
        // The real button that defines the space
        widget.child,
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- REAL-TIME CONTACT CHECKER ---
  // This listens to the sub-collection specifically for the logged-in user
  Stream<bool> _checkContactsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(false);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('emergency_contacts')
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // --- SETTINGS POP-UP ---
  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD84315), width: 1.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 65,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFD84315),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: const Center(
                  child: Text("SYSTEM DIAGNOSTICS", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 15),
              _drawerItem(Icons.battery_std_rounded, "Power Saving", "Optimize battery usage for 48h", true),
              _drawerItem(Icons.location_searching_rounded, "GPS Accuracy", "Check satellite sync status", true),
              _drawerItem(Icons.fingerprint_rounded, "Biometric Lock", "Secure app entry with face/finger", true),

             ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text(
                "Logout Session",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text("Sign out of your account", style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pop(context); 
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const WelcomePage()),
                    (route) => false,
                  );
                }
              },
            ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // WRAP IN STREAMBUILDER TO TOGGLE THE WARNING BOX AUTOMATICALLY
    return StreamBuilder<bool>(
      stream: _checkContactsStream(),
      builder: (context, snapshot) {
        final bool hasContacts = snapshot.data ?? false;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.black,
          extendBody: true,
          drawer: _buildLeftDrawer(), 

          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildStatusIndicator(hasContacts),
                        const SizedBox(height: 25),

              // SOS BOX
              _buildTacticalBox(
                color: const Color(0xFF2A2A2A),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Prevents the box from trying to fill the screen
                  children: [
                    const Text("EMERGENCY BROADCAST", 
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    
                    const SizedBox(height: 50), // Constant gap
                    
                    // We wrap the button in a Center + SizedBox to anchor it
                    Center(
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: _buildSOSButton(hasContacts),
                      ),
                    ),

                    const SizedBox(height: 30), // Constant gap
                    
                    const Text("TAP TO ACTIVATE SIGNAL", 
                      style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

                        _buildActionTile(
                          context: context,
                          title: "Edit Default Message",
                          icon: Icons.message_outlined,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditMessagePage())),
                        ),

                        // DYNAMIC VISIBILITY RULE: Only shows if the user has 0 contacts
                        if (!hasContacts) _buildWarningBox(context),

                        const SizedBox(height: 120), 
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: buildCustomFooter(context, 1), 
        );
      }
    );
  }

  // --- UPDATED HELPERS TO REACT TO HASCONTACTS ---

  Widget _buildStatusIndicator(bool hasContacts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8, 
            decoration: BoxDecoration(
              color: hasContacts ? Colors.greenAccent : Colors.orangeAccent, 
              shape: BoxShape.circle
            )
          ),
          const SizedBox(width: 10),
          Text(hasContacts ? "SYSTEM ONLINE" : "CONFIG REQUIRED", 
            style: const TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

Widget _buildSOSButton(bool hasContacts) {
  return TacticalPulse(
    isActive: hasContacts,
    child: GestureDetector(
      onTap: () {
        if (hasContacts) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SOSSelectionPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Add contacts before sending SOS"))
          );
        }
      },
      child: Container(
        width: 180, height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: Colors.black,
          border: Border.all(color: hasContacts ? const Color(0xFFD84315) : Colors.white24, width: 4),
          boxShadow: [if (hasContacts) BoxShadow(color: const Color(0xFFD84315).withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
        ),
        child: Center(
          child: Container(
            width: 145, height: 145,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: hasContacts 
                  ? [const Color(0xFFFF5722), const Color(0xFFD84315)] 
                  : [const Color(0xFF424242), const Color(0xFF212121)]
              ),
            ),
            child: Center(
              child: Text("SOS", 
                style: TextStyle(color: hasContacts ? Colors.white : Colors.white12, fontSize: 46, fontWeight: FontWeight.w900))
            ),
          ),
        ),
      ),
    ),
  );
}

  // --- DRAWER & HEADER HELPERS (STAY THE SAME) ---

  Widget _buildLeftDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            color: const Color(0xFFD84315),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, color: Colors.white, size: 50),
                SizedBox(height: 10),
                Text("STEALTH OPS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 3)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _drawerItem(Icons.history_rounded, "SOS History", "View past alerts and logs", false),
          _drawerItem(Icons.timer_rounded, "Safety Check-in", "Automated status updates", false),
          _drawerItem(Icons.visibility_off_rounded, "Ghost Mode", "Mask app presence on device", false),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, String sub, bool isBottomSheet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isBottomSheet ? Colors.white.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFD84315).withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFD84315), size: 22),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          subtitle: Text(sub, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          onTap: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circularTopButton(Icons.menu_open, "#Menu", () => _scaffoldKey.currentState?.openDrawer()),
          const Text("COMMAND CENTER", style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w900)),
          _circularTopButton(Icons.settings, "#Settings", () => _openSettings(context)),
        ],
      ),
    );
  }
Widget _circularTopButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap, // CHANGED THIS: Now it uses the function passed to it
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: const Color(0xFFD84315).withOpacity(0.1), 
              border: Border.all(color: const Color(0xFFD84315), width: 1.5)
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionTile({required BuildContext context, required String title, required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFD84315),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFFD84315).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              const Icon(Icons.message_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 15),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              const Spacer(),
              const Icon(Icons.edit_note_rounded, color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTacticalBox({required Widget child, Color color = const Color(0xFF252525), Color borderColor = Colors.white12}) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30), border: Border.all(color: borderColor, width: 2)),
      child: child,
    );
  }

  Widget _buildWarningBox(BuildContext context) {
    return _buildTacticalBox(
      color: const Color(0xFF1E1E1E),
      borderColor: const Color(0xFFD84315),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("RECIPIENTS EMPTY", style: TextStyle(color: Color(0xFFD84315), fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text("Your SOS signal is disabled. Add a contact now.", style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddContactPage())),
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text("CREATE CONTACT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 4),
            ),
          ),
        ],
      ),
    );
  }
}

// --- FOOTER (UNCHANGED) ---
Widget buildCustomFooter(BuildContext context, int activeIndex) {
  return Container(
    height: 90, width: double.infinity,
    decoration: const BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
    ),
    child: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _footerIcon(context, 0, Icons.all_inbox_rounded, "Inbox", activeIndex, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const InboxPage()))),
          _footerIcon(context, 1, Icons.home_rounded, "Home", activeIndex, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()))),
          _footerIcon(context, 2, Icons.group_rounded, "Contacts", activeIndex, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SelectContactsPage()))),
        ],
      ),
    ),
  );
}

Widget _footerIcon(BuildContext context, int index, IconData icon, String label, int activeIndex, VoidCallback onTap) {
  bool isActive = index == activeIndex;
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: isActive ? const Color(0xFFD84315) : Colors.transparent, shape: BoxShape.circle),
          child: Icon(icon, color: isActive ? Colors.white : Colors.black45, size: 28),
        ),
        Text(label, style: TextStyle(color: isActive ? const Color(0xFFD84315) : Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}