import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminNotificationScreen extends StatelessWidget {
  const AdminNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Target date: 30 days ago from today
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi Respons"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch events from 30 days ago up to the future
        stream: FirebaseFirestore.instance
            .collection('service_events')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          var docs = snapshot.data?.docs ?? [];
          List<Map<String, dynamic>> notifications = [];

          // Flatten the assignments into a single list of "notifications"
          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            List assignments = data['assignments'] ?? [];
            DateTime eventDate = (data['date'] as Timestamp).toDate();
            String ministry = data['ministry'] ?? 'Pelayanan';

            for (var assignment in assignments) {
              String status = assignment['status'] ?? 'pending';
              
              // Only grab people who have responded
              if (status == 'accepted' || status == 'rejected') {
                notifications.add({
                  'volunteerName': assignment['volunteerName'] ?? 'Seseorang',
                  'role': assignment['role'] ?? 'Petugas',
                  'status': status,
                  'ministry': ministry,
                  'eventDate': eventDate,
                });
              }
            }
          }

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Belum ada respons pelayanan\ndalam 30 hari terakhir.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // Sort the notifications by the Event Date so the newest/upcoming are at the top
          notifications.sort((a, b) => b['eventDate'].compareTo(a['eventDate']));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notif = notifications[index];
              bool isAccepted = notif['status'] == 'accepted';

              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isAccepted ? Colors.green[50] : Colors.red[50],
                    child: Icon(
                      isAccepted ? Icons.check_circle : Icons.cancel,
                      color: isAccepted ? Colors.green : Colors.red,
                    ),
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                      children: [
                        TextSpan(text: notif['volunteerName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: isAccepted ? " telah menerima " : " telah menolak "),
                        const TextSpan(text: "tugas sebagai "),
                        TextSpan(text: notif['role'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: " untuk "),
                        TextSpan(text: notif['ministry'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: "."),
                      ],
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('EEEE, d MMM yyyy', 'id_ID').format(notif['eventDate']),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
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