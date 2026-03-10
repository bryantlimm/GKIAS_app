import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminManageStaffScreen extends StatefulWidget {
  const AdminManageStaffScreen({super.key});

  @override
  State<AdminManageStaffScreen> createState() => _AdminManageStaffScreenState();
}

class _AdminManageStaffScreenState extends State<AdminManageStaffScreen> {
  String? _processingId;

  @override
  Widget build(BuildContext context) {
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
              Tab(text: "Daftar Akun", icon: Icon(Icons.people)),
              Tab(text: "Permintaan", icon: Icon(Icons.person_add_alt_1)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Daftar Akun - semua akun
            const UsersListTab(),
            
            // TAB 2: Permintaan - yg request jadi volunteer
            const VolunteerRequestsTab(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 1: DAFTAR AKUN
// ==========================================
class UsersListTab extends StatelessWidget {
  const UsersListTab({super.key});

  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    return name[0].toUpperCase();
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'volunteer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplay(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'volunteer':
        return 'Pelayan';
      default:
        return 'Jemaat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("Tidak ada pengguna terdaftar.", 
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }

        var users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userDoc = users[index];
            var userData = userDoc.data() as Map<String, dynamic>;
            
            String name = userData['name'] ?? 'Tanpa Nama';
            String email = userData['email'] ?? 'No Email';
            String role = userData['role'] ?? 'regular';
            List<dynamic> ministries = userData['ministries'] ?? [];
            bool isStaffRequested = userData['isStaffRequested'] ?? false;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(role).withOpacity(0.2),
                  child: Text(
                    _getInitials(name),
                    style: TextStyle(
                      color: _getRoleColor(role),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(email, style: const TextStyle(fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getRoleColor(role).withOpacity(0.3)),
                  ),
                  child: Text(
                    _getRoleDisplay(role),
                    style: TextStyle(
                      color: _getRoleColor(role),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                children: [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Bidang Pelayanan:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        if (ministries.isNotEmpty) ...[
                          // Show assigned ministries for volunteers
                          ...ministries.map((ministry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, 
                                    size: 16, 
                                    color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(ministry.toString()),
                                ],
                              ),
                            );
                          }).toList(),
                        ] else if (isStaffRequested) ...[
                          // Show pending request indicator
                          StreamBuilder(
                            stream: FirebaseFirestore.instance
                                .collection('volunteer_requests')
                                .where('userId', isEqualTo: userDoc.id)
                                .where('status', isEqualTo: 'pending')
                                .snapshots(),
                            builder: (context, requestSnapshot) {
                              if (!requestSnapshot.hasData || requestSnapshot.data!.docs.isEmpty) {
                                return const Text(
                                  "Tidak ada permintaan pelayanan",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              }
                              
                              var requests = requestSnapshot.data!.docs;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: requests.map((req) {
                                  var reqData = req.data() as Map<String, dynamic>;
                                  String ministry = reqData['ministry'] ?? 'Unknown';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.pending, 
                                          size: 16, 
                                          color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Text(
                                          "$ministry - permintaan diproses",
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ] else ...[
                          // No ministries and no pending request
                          const Text(
                            "Belum terdaftar di bidang pelayanan manapun",
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// TAB 2: PERMINTAAN PELAYAN
// ==========================================
class VolunteerRequestsTab extends StatefulWidget {
  const VolunteerRequestsTab({super.key});

  @override
  State<VolunteerRequestsTab> createState() => _VolunteerRequestsTabState();
}

class _VolunteerRequestsTabState extends State<VolunteerRequestsTab> {
  String? _processingId;

  Future<void> _handleApprove(String requestId, String userId, String ministry, String userName) async {
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

        String currentRole = userData['role'] ?? 'regular';
        String newRole = currentRole == 'regular' ? 'volunteer' : currentRole;

        List<dynamic> currentMinistries = List.from(userData['ministries'] ?? []);
        if (!currentMinistries.contains(ministry)) {
          currentMinistries.add(ministry);
        }

        transaction.update(userRef, {
          'role': newRole,
          'ministries': currentMinistries,
          'isStaffRequested': false,
        });
        transaction.update(requestRef, {'status': 'approved'});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permintaan berhasil diterima!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _handleReject(String requestId, String userName) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Konfirmasi"),
            content: Text("Tolak permintaan $userName?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Tolak")),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _processingId = requestId);

    try {
      await FirebaseFirestore.instance.collection('volunteer_requests').doc(requestId).update({'status': 'rejected'});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Permintaan berhasil ditolak.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
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
            child: Text("Tidak ada permintaan pelayanan yang tertunda.",
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }

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
                          decoration:
                              BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            data['ministry'] ?? 'Pelayanan',
                            style: TextStyle(
                                color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold),
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
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                          onPressed: isProcessing ? null : () => _handleReject(doc.id, data['userName'] ?? 'user'),
                          child: const Text("Tolak"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: isProcessing
                              ? null
                              : () => _handleApprove(
                                  doc.id, data['userId'], data['ministry'], data['userName'] ?? 'user'),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
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