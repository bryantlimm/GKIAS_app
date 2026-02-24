import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminManageStaffScreen extends StatefulWidget {
  const AdminManageStaffScreen({super.key});

  @override
  State<AdminManageStaffScreen> createState() => _AdminManageStaffScreenState();
}

class _AdminManageStaffScreenState extends State<AdminManageStaffScreen> {
  String? _selectedUserId; // null means "Show All"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Pelayan"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // 1. THE FILTER DROPDOWN
          Container(
            color: Colors.blue[50],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', whereIn: ['volunteer', 'admin'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Text("Memuat pelayan...");

                      var users = snapshot.data!.docs;
                      
                      // Safety check: if selected user was deleted, reset filter
                      if (_selectedUserId != null && !users.any((u) => u.id == _selectedUserId)) {
                        _selectedUserId = null;
                      }

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _selectedUserId,
                          hint: const Text("Semua Pelayan"),
                          items: [
                            // Default "All" option
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text("Semua Pelayan", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            // Map the users to dropdown items
                            ...users.map((user) {
                              var data = user.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String?>(
                                value: user.id,
                                child: Text(data['name'] ?? 'Tanpa Nama'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedUserId = val;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. THE LIST OF SERVICES
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_events')
                  .orderBy('date', descending: true) // Newest first
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Belum ada jadwal."));
                }

                var allDocs = snapshot.data!.docs;

                // --- FILTER LOGIC ---
                // Keep only the services where the selected user is assigned
                var displayDocs = allDocs.where((doc) {
                  if (_selectedUserId == null) return true; // Show all if no filter
                  
                  var data = doc.data() as Map<String, dynamic>;
                  List assignments = data['assignments'] ?? [];
                  
                  // Return true if any assignment matches the selected user's ID
                  return assignments.any((a) => a['volunteerId'] == _selectedUserId);
                }).toList();

                if (displayDocs.isEmpty) {
                  return const Center(child: Text("Pelayan ini belum memiliki jadwal."));
                }

                // --- BUILD THE LIST ---
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: displayDocs.length,
                  itemBuilder: (context, index) {
                    var data = displayDocs[index].data() as Map<String, dynamic>;
                    DateTime date = (data['date'] as Timestamp).toDate();
                    List assignments = data['assignments'] ?? [];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: ExpansionTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.event, color: Colors.white, size: 20),
                        ),
                        title: Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date)),
                        children: assignments.isEmpty 
                          ? [const Padding(padding: EdgeInsets.all(16.0), child: Text("Belum ada petugas assigned."))]
                          : assignments.map((a) {
                              
                              // Visual status setup
                              String status = a['status'] ?? 'pending';
                              Color statusColor = status == 'accepted' 
                                  ? Colors.green 
                                  : (status == 'rejected' ? Colors.red : Colors.orange);
                              
                              // Highlight row if it belongs to the filtered user
                              bool isHighlighted = a['volunteerId'] == _selectedUserId;

                              return Container(
                                color: isHighlighted ? Colors.yellow[100] : null,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
                                  title: Text(a['volunteerName'] ?? 'Unknown', style: TextStyle(fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal)),
                                  subtitle: Text("Tugas: ${a['role']}"),
                                  trailing: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              );
                          }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}