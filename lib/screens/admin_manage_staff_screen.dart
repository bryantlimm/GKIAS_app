import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageStaffScreen extends StatefulWidget {
  const AdminManageStaffScreen({super.key});

  @override
  State<AdminManageStaffScreen> createState() => _AdminManageStaffScreenState();
}

class _AdminManageStaffScreenState extends State<AdminManageStaffScreen> {
  String? _processingId; // To disable buttons while loading

  // Handle Approve Logic
  Future<void> _handleApprove(String requestId, String userId, String ministry, String userName) async {
    // Show a confirmation dialog first
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Konfirmasi"),
            content: Text("Terima $userName untuk pelayanan $ministry?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Terima")),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _processingId = requestId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
        final requestRef = FirebaseFirestore.instance.collection('volunteer_requests').doc(requestId);

        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) throw Exception("User document not found!");

        final userData = userDoc.data()!;

        // 1. Determine new role
        String currentRole = userData['role'] ?? 'regular';
        String newRole = currentRole == 'regular' ? 'volunteer' : currentRole;

        // 2. Safely add to ministries array
        List<dynamic> currentMinistries = List.from(userData['ministries'] ?? []);
        if (!currentMinistries.contains(ministry)) {
          currentMinistries.add(ministry);
        }

        // 3. Update both documents safely inside the transaction
        transaction.update(userRef, {
          'role': newRole,
          'ministries': currentMinistries,
        });
        transaction.update(requestRef, {'status': 'approved'});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan berhasil diterima!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  // Handle Reject Logic
  Future<void> _handleReject(String requestId, String userName) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Konfirmasi"),
            content: Text("Tolak permintaan $userName?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text("Tolak")),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _processingId = requestId);

    try {
      await FirebaseFirestore.instance.collection('volunteer_requests').doc(requestId).update({'status': 'rejected'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan berhasil ditolak.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Permintaan Pelayan"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('volunteer_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Tidak ada permintaan pelayanan yang tertunda.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            );
          }

          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            var aData = a.data() as Map;
            var bData = b.data() as Map;
            Timestamp? aTime = aData['createdAt'];
            Timestamp? bTime = bData['createdAt'];
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map;
              bool isProcessing = _processingId == doc.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['userName'] ?? 'Tanpa Nama',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              data['ministry'] ?? 'Pelayanan',
                              style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(data['userEmail'] ?? '', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                            onPressed: isProcessing ? null : () => _handleReject(doc.id, data['userName'] ?? 'user'),
                            child: const Text("Tolak"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: isProcessing ? null : () => _handleApprove(doc.id, data['userId'], data['ministry'], data['userName'] ?? 'user'),
                            child: isProcessing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Terima"),
                          ),
                        ],
                      )
                    ],
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