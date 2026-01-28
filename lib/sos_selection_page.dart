import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class SOSSelectionPage extends StatefulWidget {
  const SOSSelectionPage({super.key});

  @override
  State<SOSSelectionPage> createState() => _SOSSelectionPageState();
}

class _SOSSelectionPageState extends State<SOSSelectionPage> {
  final List<String> _selectedContactIds = [];
  String _searchQuery = "";
  bool _isSending = false;

  // Sorting State
  String _sortBy = 'name'; // 'name' or 'timestamp'
  bool _isAscending = true;

  // --- THE LOGIC: BROADCAST SYSTEM (ORIGINAL) ---
// --- THE LOGIC: BROADCAST SYSTEM (UPDATED WITH STATUS & VISIBILITY) ---
Future<void> _processSOS() async {
  setState(() => _isSending = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    
    String senderRealName = senderDoc.data()?['name'] ?? "Tactical User";
    String senderRealPhone = senderDoc.data()?['phone'] ?? "No Phone";
    String senderRealEmail = user.email ?? "No Email";
    
    String userCustomMessage = senderDoc.data()?['sos_message'] ?? 
        "EMERGENCY: I need immediate assistance. Please track my location.";

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );

    List<String> registeredUids = [];
    List<Map<String, String>> unregisteredContacts = [];

    final contactsSnapshot = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('emergency_contacts').get();

    for (var doc in contactsSnapshot.docs) {
      if (_selectedContactIds.contains(doc.id)) {
        String phone = doc['phone'];
        final userLookup = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phone)
            .get();

        if (userLookup.docs.isNotEmpty) {
          String foundUid = userLookup.docs.first.id;
          if (foundUid != user.uid) registeredUids.add(foundUid);
        } else {
          unregisteredContacts.add({'name': doc['name'], 'phone': phone});
        }
      }
    }

    if (registeredUids.isNotEmpty) {
      // THE PAYLOAD: Now includes 'status' and 'visibility'
      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'senderId': user.uid,
        'senderName': senderRealName,
        'senderPhone': senderRealPhone,
        'senderEmail': senderRealEmail,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'recipients': registeredUids,
        'message': userCustomMessage,
        'status': 'ACTIVE',      // Preserved for Soft Delete logic
        'visibility': 'unread',  // Preserved for Read/Unread UI logic
      });
    }

    if (mounted) _showBroadcastReport(context, registeredUids, unregisteredContacts);
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("SIGNAL FAILED: $e"), backgroundColor: Colors.redAccent),
      );
    }
  } finally {
    if (mounted) setState(() => _isSending = false);
  }
}

  // --- UI HELPER: SORT MENU ---
  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("SORT COMMAND", style: TextStyle(color: Colors.white38, letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _sortOption("Name (A-Z)", 'name', true),
            _sortOption("Name (Z-A)", 'name', false),
            _sortOption("Recently Added", 'timestamp', false),
            _sortOption("Oldest Contacts", 'timestamp', true),
          ],
        ),
      ),
    );
  }

  Widget _sortOption(String title, String field, bool asc) {
    bool isCurrent = _sortBy == field && _isAscending == asc;
    return ListTile(
      title: Text(title, style: TextStyle(color: isCurrent ? const Color(0xFFFF5722) : Colors.white70, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
      trailing: isCurrent ? const Icon(Icons.check_circle, color: Color(0xFFFF5722)) : null,
      onTap: () {
        setState(() { _sortBy = field; _isAscending = asc; });
        Navigator.pop(context);
      },
    );
  }

  // --- UI HELPER: MISSION DEBRIEF ---
  void _showBroadcastReport(BuildContext context, List<String> registered, List<Map<String, String>> unregistered) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DefaultTabController(
        length: 2,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Text("MISSION DEBRIEF", style: TextStyle(color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _debriefStatCard("SENT", registered.length.toString(), Colors.greenAccent),
                    const SizedBox(width: 15),
                    _debriefStatCard("NOT SENT", unregistered.length.toString(), Colors.redAccent),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              
              const TabBar(
                indicatorColor: Color(0xFFFF5722),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white24,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: "SUCCESSFUL"),
                  Tab(text: "OFF-GRID"),
                ],
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    _buildSentList(registered),
                    _buildOffGridList(unregistered),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 30),
                child: SizedBox(
                  width: double.infinity, height: 60, 
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.white10))
                    ),
                    child: const Text("CLOSE REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5))
                  )
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _debriefStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildSentList(List<String> registeredIds) {
    if (registeredIds.isEmpty) return const Center(child: Text("No secure transmissions.", style: TextStyle(color: Colors.white24)));
    
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: registeredIds).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            var user = snapshot.data!.docs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.greenAccent),
                title: Text(user['name'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Node Verified", style: TextStyle(color: Colors.white24, fontSize: 11)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOffGridList(List<Map<String, String>> unregistered) {
    if (unregistered.isEmpty) return const Center(child: Text("Zero off-grid nodes.", style: TextStyle(color: Colors.white24)));
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: unregistered.length,
      itemBuilder: (context, i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          title: Text(unregistered[i]['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(unregistered[i]['phone']!, style: const TextStyle(color: Colors.white24, fontSize: 11)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFF5722).withOpacity(0.5)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text("INVITE", style: TextStyle(color: Color(0xFFFF5722), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 110.0,
                pinned: true,
                backgroundColor: Colors.black,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    onPressed: _showSortMenu,
                    icon: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 10),
                ],
                flexibleSpace: const FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text("SELECT CONTACTS TO INFORM", 
                    style: TextStyle(letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search contact...",
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF5722), size: 22),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.12),
                      contentPadding: const EdgeInsets.all(18),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1)),
                    ),
                  ),
                ),
              ),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users').doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('emergency_contacts').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))));
                  
                  var contacts = snapshot.data!.docs.where((d) {
                    final name = d['name'].toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();

                  contacts.sort((a, b) {
                    var valA = a[_sortBy] ?? '';
                    var valB = b[_sortBy] ?? '';
                    return _isAscending ? valA.compareTo(valB) : valB.compareTo(valA);
                  });

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final d = contacts[i];
                          bool isSel = _selectedContactIds.contains(d.id);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFFF5722).withOpacity(0.25) : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSel ? const Color(0xFFFF5722) : Colors.white12, width: 2),
                            ),
                            child: ListTile(
                              onTap: () => setState(() => isSel ? _selectedContactIds.remove(d.id) : _selectedContactIds.add(d.id)),
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: isSel ? const Color(0xFFFF5722) : Colors.white10,
                                child: Text(d['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(d['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Text(d['phone'], style: const TextStyle(color: Colors.white38, fontSize: 13)),
                              trailing: Icon(
                                isSel ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, 
                                color: isSel ? const Color(0xFFFF5722) : Colors.white24,
                                size: 28,
                              ),
                            ),
                          );
                        },
                        childCount: contacts.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9), Colors.black],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton.icon(
                  onPressed: _isSending || _selectedContactIds.isEmpty ? null : _processSOS,
                  icon: _isSending 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
                  label: Text(
                    _isSending ? "TRANSMITTING..." : "INITIATE BROADCAST (${_selectedContactIds.length})", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    disabledBackgroundColor: Colors.white10,
                    elevation: 10,
                    shadowColor: const Color(0xFFFF5722).withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}