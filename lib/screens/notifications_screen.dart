import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _updateStatus(BuildContext context, String serviceId, List currentAssignments, int userIndex, String newStatus) async {
    try {
      // 1. Copy the assignments array
      List updatedAssignments = List.from(currentAssignments);
      
      // 2. Update the status of the specific user
      updatedAssignments[userIndex]['status'] = newStatus;

      // 3. Save it back to Firestore
      await FirebaseFirestore.instance.collection('service_events').doc(serviceId).update({
        'assignments': updatedAssignments,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Berhasil diubah menjadi: $newStatus")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const Scaffold(body: Center(child: Text("Silakan login")));

    print('Current user UID: ${currentUser.uid}');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi & Jadwal"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_events')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // debug
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              )
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Belum ada jadwal baru."));
          }

          // Filter only the services where THIS user is assigned
          List<Widget> myAssignmentsWidgets = [];

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            List assignments = data['assignments'] ?? [];
            
            // Debug: Print assignment info
            print('Service: ${data['ministry']}, Assignments count: ${assignments.length}');
            for (var a in assignments) {
              print('  Assignment: ${a['volunteerId']} (looking for ${currentUser.uid})');
            }
            
            // Find if the current user is in this assignment list
            int myIndex = -1;
            for (int i = 0; i < assignments.length; i++) {
              var a = assignments[i];
              if (a is Map && a['volunteerId'] != null && a['volunteerId'].toString() == currentUser.uid) {
                myIndex = i;
                break;
              }
            }

            if (myIndex != -1) {
              var myAssignment = assignments[myIndex];
              DateTime date = (data['date'] as Timestamp).toDate();
              String status = myAssignment['status'] ?? 'pending';

              myAssignmentsWidgets.add(
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              data['ministry'] ?? 'Kebaktian',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                            ),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'accepted' ? Colors.green[100] : (status == 'rejected' ? Colors.red[100] : Colors.orange[100]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'accepted' ? Colors.green[800] : (status == 'rejected' ? Colors.red[800] : Colors.orange[800]),
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(DateFormat('EEEE, d MMMM yyyy • HH:mm', 'id_ID').format(date)),
                        const SizedBox(height: 4),
                        Text("Tugas: ${myAssignment['role']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (data['description'] != null && data['description'].isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text("Tema: ${data['description']}", style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],

                        // Show Accept/Reject buttons ONLY if status is pending
                        if (status == 'pending') ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                  onPressed: () => _updateStatus(context, doc.id, assignments, myIndex, 'rejected'),
                                  child: const Text("Tolak"),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  onPressed: () => _updateStatus(context, doc.id, assignments, myIndex, 'accepted'),
                                  child: const Text("Terima"),
                                ),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
                )
              );
            }
          }

          if (myAssignmentsWidgets.isEmpty) {
            return const Center(child: Text("Anda belum memiliki jadwal pelayanan."));
          }

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            children: myAssignmentsWidgets,
          );
        },
      ),
    );
  }
}