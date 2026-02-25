import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StaffVolunteerScreen extends StatelessWidget {
  const StaffVolunteerScreen({super.key});

  // Function to handle the cancellation popup and Firestore update
  Future<void> _cancelService(BuildContext context, String eventId, List currentAssignments, int myIndex) async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Batalkan Pelayanan?"),
          content: const Text("Apakah Anda yakin ingin membatalkan jadwal pelayanan ini? Admin akan menerima notifikasi pembatalan ini."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Tidak", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Ya, Batalkan", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if user dismisses the dialog

    if (confirm && context.mounted) {
      try {
        List updatedAssignments = List.from(currentAssignments);
        // Change status from 'accepted' to 'cancelled'
        updatedAssignments[myIndex]['status'] = 'cancelled';

        await FirebaseFirestore.instance.collection('service_events').doc(eventId).update({
          'assignments': updatedAssignments,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Jadwal pelayanan berhasil dibatalkan.")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Silakan login untuk melihat jadwal.")),
      );
    }

    // Wrap the Scaffold in a DefaultTabController
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Jadwal Pelayanan Saya"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Akan Datang"),
              Tab(text: "Selesai"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: UPCOMING (Akan Datang)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_events')
                  .where('date', isGreaterThanOrEqualTo: Timestamp.now())
                  .orderBy('date')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var allDocs = snapshot.data?.docs ?? [];
                
                // Filter docs where this user has 'accepted' status
                var myAcceptedServices = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  List assignments = data['assignments'] ?? [];
                  return assignments.any((a) => a['volunteerId'] == currentUser.uid && a['status'] == 'accepted');
                }).toList();

                if (myAcceptedServices.isEmpty) {
                  return const Center(child: Text("Belum ada jadwal pelayanan yang akan datang."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: myAcceptedServices.length,
                  itemBuilder: (context, index) {
                    var doc = myAcceptedServices[index];
                    var data = doc.data() as Map<String, dynamic>;
                    DateTime date = (data['date'] as Timestamp).toDate();
                    List assignments = data['assignments'] ?? [];
                    
                    // Find user's exact index in the array so we can update it if they cancel
                    int myIndex = assignments.indexWhere((a) => a['volunteerId'] == currentUser.uid && a['status'] == 'accepted');
                    var myAssignment = assignments[myIndex];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Tugas: ${myAssignment['role']}", style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text("Waktu: ${DateFormat('HH:mm').format(date)} WIB"),
                            const SizedBox(height: 12),
                            // Cancel Button
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _cancelService(context, doc.id, assignments, myIndex),
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                label: const Text("Batalkan", style: TextStyle(color: Colors.red)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // TAB 2: FINISHED (Selesai) - Empty for now
            const Center(
              child: Text("Riwayat pelayanan (Segera Hadir)", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}