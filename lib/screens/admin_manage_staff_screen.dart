import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminManageStaffScreen extends StatefulWidget {
  const AdminManageStaffScreen({super.key});

  @override
  State<AdminManageStaffScreen> createState() => _AdminManageStaffScreenState();
}

class _AdminManageStaffScreenState extends State<AdminManageStaffScreen> {
  String? _selectedUserId; // For the Jadwal Tab filter

  @override
  Widget build(BuildContext context) {
    // We wrap the Scaffold in a DefaultTabController to get the 2 tabs
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Kelola Pelayan"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Jadwal Pelayan", icon: Icon(Icons.event_available)),
              Tab(text: "Permintaan", icon: Icon(Icons.person_add_alt_1)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: The existing Manage Schedules view
            _buildSchedulesTab(),

            // TAB 2: The new Requests Manager view
            const VolunteerRequestsTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: JADWAL PELAYAN (The code we just wrote)
  // ==========================================
  Widget _buildSchedulesTab() {
    return Column(
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
                    
                    if (_selectedUserId != null && !users.any((u) => u.id == _selectedUserId)) {
                      _selectedUserId = null;
                    }

                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedUserId,
                        hint: const Text("Semua Pelayan"),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text("Semua Pelayan", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
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
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Belum ada jadwal."));
              }

              var allDocs = snapshot.data!.docs;
              var displayDocs = allDocs.where((doc) {
                if (_selectedUserId == null) return true; 
                var data = doc.data() as Map<String, dynamic>;
                List assignments = data['assignments'] ?? [];
                return assignments.any((a) => a['volunteerId'] == _selectedUserId);
              }).toList();

              if (displayDocs.isEmpty) {
                return const Center(child: Text("Pelayan ini belum memiliki jadwal."));
              }

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
                            String status = a['status'] ?? 'pending';
                            Color statusColor = status == 'accepted' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
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
    );
  }
}

// ==========================================
// TAB 2: PERMINTAAN PELAYAN (Ported from React)
// ==========================================
class VolunteerRequestsTab extends StatefulWidget {
  const VolunteerRequestsTab({super.key});

  @override
  State<VolunteerRequestsTab> createState() => _VolunteerRequestsTabState();
}

class _VolunteerRequestsTabState extends State<VolunteerRequestsTab> {
  String? _processingId; // To disable buttons while loading

  // Translate the Handle Approve Logic
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
    ) ?? false;

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
        List currentMinistries = List.from(userData['ministries'] ?? []);
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

  // Translate the Handle Reject Logic
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
    ) ?? false;

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
    return StreamBuilder<QuerySnapshot>(
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

        // Sort manually by date on the client (just like the React code)
        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
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
            var data = doc.data() as Map<String, dynamic>;
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
    );
  }
}