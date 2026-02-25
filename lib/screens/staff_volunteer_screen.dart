import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StaffVolunteerScreen extends StatelessWidget {
  const StaffVolunteerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Silakan login untuk melihat jadwal.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Pelayanan Saya"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch upcoming services, ordered by date so the nearest is at the top
        stream: FirebaseFirestore.instance
            .collection('service_events')
            .where('date', isGreaterThanOrEqualTo: Timestamp.now())
            .orderBy('date')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var allDocs = snapshot.data?.docs ?? [];

          // --- CLIENT-SIDE FILTER LOGIC ---
          // Keep only the services where THIS user is assigned AND status == 'accepted'
          var myAcceptedServices = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            List assignments = data['assignments'] ?? [];
            return assignments.any((a) => 
                a['volunteerId'] == currentUser.uid && 
                a['status'] == 'accepted');
          }).toList();

          if (myAcceptedServices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "Belum ada jadwal pelayanan\nyang telah Anda terima.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              )
            );
          }

          // --- BUILD THE LIST ---
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: myAcceptedServices.length,
            itemBuilder: (context, index) {
              var doc = myAcceptedServices[index];
              var data = doc.data() as Map<String, dynamic>;
              DateTime date = (data['date'] as Timestamp).toDate();
              
              // We need to extract the user's specific assignment to show their role
              List assignments = data['assignments'] ?? [];
              var myAssignment = assignments.firstWhere(
                (a) => a['volunteerId'] == currentUser.uid && a['status'] == 'accepted',
                orElse: () => {'role': 'Pelayan'} // Fallback
              );

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200)
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('MMM').format(date).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green[800])),
                        Text(DateFormat('dd').format(date), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green[900])),
                      ],
                    ),
                  ),
                  title: Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.badge, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text("Tugas: ${myAssignment['role']}", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text("${DateFormat('HH:mm').format(date)} WIB", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(child: Text(data['description'], style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}