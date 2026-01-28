import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui'; // Required for the Blur effect
import 'home_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // FORMAT DATE AND TIME (Logic preserved)
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "SYNCING...";
    DateTime dt = timestamp.toDate();
    return "${dt.day}/${dt.month} @ ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // OPEN GOOGLE MAPS (Logic preserved)
  Future<void> _openMap(double lat, double lng) async {
  // Use the standard Google Maps URL scheme
  final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
  final String appleMapsUrl = "https://maps.apple.com/?q=$lat,$lng";

  if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
    await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
  } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
    await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch maps';
  }
}

  // SOFT DELETE LOGIC
Future<void> _confirmDelete(BuildContext context, String docId) async {
  bool? confirm = await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A0505),
      title: const Text("TERMINATE ALERT?", 
        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
      content: const Text("This alert will be archived and removed from your tactical view.", 
        style: TextStyle(color: Colors.white70, fontSize: 12)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white24))),
        TextButton(
          onPressed: () => Navigator.pop(context, true), 
          child: const Text("CONFIRM DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
        ),
      ],
    ),
  );

if (confirm == true) {
    try {
      await FirebaseFirestore.instance
          .collection('sos_alerts')
          .doc(docId)
          .update({'status': 'deleted'});
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("DELETE FAILED: $e")),
       );
    }
  }
}

  // UPDATE READ STATUS
Future<void> _markAsRead(String docId) async {
  try {
    await FirebaseFirestore.instance
        .collection('sos_alerts')
        .doc(docId)
        .set({'visibility': 'read'}, SetOptions(merge: true)); // Use 'set' with merge for a cleaner write
    print("SUCCESS: Alert $docId marked as read");
  } catch (e) {
    print("DATABASE ERROR: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("WRITE FAILED: $e"), backgroundColor: Colors.red),
    );
  }
}
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [Color(0xFF2A0A05), Colors.black],
              ),
            ),
          ),
          
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                centerTitle: true,
                expandedHeight: 75,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text("RECEIVED ALERTS",
                        style: TextStyle(color: Color(0xFFFF5722), fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Container(width: 40, height: 2, color: Colors.redAccent.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sos_alerts')
                    .where('recipients', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                    .where('status', isEqualTo: 'ACTIVE') // ONLY LOAD ACTIVE ALERTS
                    .orderBy('timestamp', descending: true)
                    .snapshots(), 
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const SliverFillRemaining(child: Center(child: Text("COMMUNICATION ERROR", style: TextStyle(color: Colors.redAccent, fontSize: 10))));
                  if (snapshot.connectionState == ConnectionState.waiting) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return SliverFillRemaining(child: _buildEmptyState());

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildSOSInboxCard(context, snapshot.data!.docs[index]),
                        childCount: snapshot.data!.docs.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: buildCustomFooter(context, 0),
    );
  }

  Widget _buildSOSInboxCard(BuildContext context, DocumentSnapshot alert) {
    Map<String, dynamic> data = alert.data() as Map<String, dynamic>;
    bool isRead = data['visibility'] == 'read';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isRead ? Colors.white.withOpacity(0.05) : Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isRead ? Colors.white.withOpacity(0.08) : Colors.redAccent.withOpacity(0.5), 
                width: isRead ? 2 : 3
              ),
            ),
            child: InkWell(
              onTap: () {
                _markAsRead(alert.id);
                _showAlertDetails(context, alert);
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(value: 1, strokeWidth: 1, color: isRead ? Colors.white24 : Colors.redAccent),
                        Icon(isRead ? Icons.mark_email_read_outlined : Icons.emergency_share_rounded, 
                             color: isRead ? Colors.white24 : Colors.redAccent, size: 24),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(data['senderName']?.toUpperCase() ?? "UNKNOWN UNIT",
                                  style: TextStyle(
                                    color: isRead ? Colors.white60 : Colors.white, 
                                    fontWeight: isRead ? FontWeight.bold : FontWeight.w900, 
                                    fontSize: 15, 
                                    letterSpacing: 1)),
                              Text(_formatTime(data['timestamp'] as Timestamp?), 
                                  style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                             if (!isRead) 
  Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.redAccent, 
      borderRadius: BorderRadius.circular(4)
    ),
    // Ensure no 'const' is blocking this if the parent is dynamic
    child: Text(
      "NEW", 
      style: TextStyle(
        color: Colors.white, 
        fontSize: 8, 
        fontWeight: FontWeight.w900, // This should now be recognized
      )
    ),
  ),
                              Expanded(
                                child: Text(data['message'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: isRead ? Colors.white24 : Colors.white38, fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(context, alert.id),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white24, size: 20),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertDetails(BuildContext context, DocumentSnapshot alert) {
    Map<String, dynamic> data = alert.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea( // PREVENTS OVERFLOW
        child: Container(
          // Removed static height factor to allow flexible fit
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            border: Border(top: BorderSide(color: Colors.redAccent, width: 2)),
          ),
          padding: const EdgeInsets.fromLTRB(30, 15, 30, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min, // COMPACT FIT
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 30),
              const Row(
                children: [
                  Icon(Icons.gpp_maybe_outlined, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text("SITUATION REPORT", style: TextStyle(color: Colors.redAccent, letterSpacing: 4, fontWeight: FontWeight.w900, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 15),
              Text(data['senderName'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 30),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
                ),
                child: _detailRow(Icons.chat_bubble_outline_rounded, "SENDER'S MESSAGE", data['message'] ?? "No message provided."),
              ),
              
              const SizedBox(height: 25),
              _detailRow(Icons.access_time_rounded, "TIME RECEIVED", _formatTime(data['timestamp'] as Timestamp?)),
              _detailRow(Icons.phone_iphone_rounded, "SECURE LINE", data['senderPhone'] ?? "N/A"),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                height: 65,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withOpacity(0.1),
                    side: const BorderSide(color: Colors.greenAccent, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                  onPressed: () {
                    if (data['latitude'] != null) _openMap(data['latitude'], data['longitude']);
                  }, 
                  icon: const Icon(Icons.location_searching_rounded, color: Colors.greenAccent),
                  label: const Text("INITIALIZE LIVE TRACKING", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 1.5)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white54, size: 18),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        )
      ],
    ),
  );

  Widget _buildEmptyState() {
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar_rounded, size: 80, color: Colors.white10),
            const SizedBox(height: 20),
            const Text("SCANNING FOR SIGNALS...", style: TextStyle(color: Colors.white24, letterSpacing: 4, fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}