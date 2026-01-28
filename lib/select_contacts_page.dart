import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'add_contact_page.dart';
import 'edit_contact_page.dart';

class SelectContactsPage extends StatefulWidget {
  const SelectContactsPage({super.key});

  @override
  State<SelectContactsPage> createState() => _SelectContactsPageState();
}

class _SelectContactsPageState extends State<SelectContactsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _sortBy = "name"; // Default sort: name, newest, oldest

  void _confirmDelete(BuildContext context, DocumentSnapshot contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: const Text("TERMINATE CONTACT?", 
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text("Are you sure you want to remove ${contact['name']} from your emergency grid?", 
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              contact.reference.delete();
              Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("EMERGENCY CONTACTS", 
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, Color(0xFF1A0A05), Colors.black],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 110), // Space for Transparent AppBar
            
            // --- SEARCH & SORT BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFD84315).withOpacity(0.03), blurRadius: 20, spreadRadius: 2),
                          BoxShadow(color: const Color.fromARGB(146, 255, 255, 255).withOpacity(0.07), blurRadius: 10, spreadRadius: 10)
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search contacts...",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF5722)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // --- SORT BUTTON ---
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.sort_rounded, color: Colors.white),
                      color: const Color(0xFF1A1A1A),
                      onSelected: (value) => setState(() => _sortBy = value),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: "name", child: Text("Sort by Name (A-Z)", style: TextStyle(color: Colors.white))),
                        const PopupMenuItem(value: "newest", child: Text("Sort by Newest", style: TextStyle(color: Colors.white))),
                        const PopupMenuItem(value: "oldest", child: Text("Sort by Oldest", style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // --- CONTACTS LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('emergency_contacts')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Sync Error", style: TextStyle(color: Colors.white)));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: _buildAddButton(context));
                  }

                  // 1. Filter
                  var list = snapshot.data!.docs.where((doc) {
                    String n = doc['name'].toString().toLowerCase();
                    String p = doc['phone'].toString().toLowerCase();
                    return n.contains(_searchQuery) || p.contains(_searchQuery);
                  }).toList();

                  // 2. Sort Logic
                  if (_sortBy == "name") {
                    list.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
                  } else if (_sortBy == "newest") {
                    list.sort((a, b) => (b['timestamp'] as Timestamp?)?.compareTo((a['timestamp'] as Timestamp?) ?? Timestamp.now()) ?? 0);
                  } else if (_sortBy == "oldest") {
                    list.sort((a, b) => (a['timestamp'] as Timestamp?)?.compareTo((b['timestamp'] as Timestamp?) ?? Timestamp.now()) ?? 0);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      var contact = list[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF9100)]),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: const Color(0xFFFF5722).withOpacity(0.3), blurRadius: 10)],
                            ),
                            child: Center(
                              child: Text(contact['name'][0].toUpperCase(), 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            ),
                          ),
                          title: Text(contact['name'], 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text(contact['phone'], 
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.white38),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => EditContactPage(
                                    contactId: contact.id,
                                    currentName: contact['name'],
                                    currentPhone: contact['phone'],
                                  )),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                                onPressed: () => _confirmDelete(context, contact),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildCustomFooter(context, 2),
      floatingActionButton: FloatingActionButton(
  onPressed: () => Navigator.push(
    context, 
    MaterialPageRoute(builder: (context) => const AddContactPage())
  ),
  backgroundColor: const Color(0xFFFF5722),
  elevation: 10,
  child: const Icon(Icons.add, color: Colors.white, size: 30), // Only the + icon
),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_moon_outlined, size: 100, color: Colors.white.withOpacity(0.05)),
        const SizedBox(height: 20),
        const Text("EMPTY GRID", style: TextStyle(color: Colors.white24, letterSpacing: 5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddContactPage())),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5722),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text("INITIALIZE GRID"),
        )
      ],
    );
  }
}