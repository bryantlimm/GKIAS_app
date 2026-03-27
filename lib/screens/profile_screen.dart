import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Helper to get initials
  String _getInitials(String? name, String? email) {
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return "U";
  }

  // Function to show the Volunteer Request Form with CONFIRMATION
  void _showVolunteerRequestSheet(BuildContext context) {
    String? selectedMinistry;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daftar Pelayanan",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text("Pilih bidang pelayanan yang ingin Anda ikuti:"),
                  const SizedBox(height: 15),

                  StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('schedules').orderBy('order').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();

                      var ministries = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        hint: const Text("Pilih Pelayanan..."),
                        value: selectedMinistry,
                        items: ministries.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc['name'],
                            child: Text(doc['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedMinistry = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting || selectedMinistry == null
                          ? null
                          : () async {
                              // NEW: Show confirmation dialog first
                              bool confirm = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Konfirmasi"),
                                      content: Text("Apakah Anda yakin ingin mendaftar untuk pelayanan $selectedMinistry?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text("Batal"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text("Ya, Daftar"),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (!confirm) return;

                              setModalState(() => isSubmitting = true);

                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                try {
                                  // Fetch actual name from Firestore for the request doc
                                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                  final actualName = userDoc.data()?['name'] ?? user.displayName ?? 'Jemaat';

                                  await FirebaseFirestore.instance.collection('volunteer_requests').add({
                                    'userId': user.uid,
                                    'userName': actualName,
                                    'userEmail': user.email,
                                    'ministry': selectedMinistry,
                                    'status': 'pending',
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Permintaan pelayanan berhasil dikirim!"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Gagal mengirim: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Kirim Permintaan", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color gkiBlue = const Color(0xFF1E3A8A);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Gagal memuat profil"));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          
          String name = userData['name'] ?? 'User';
          String email = userData['email'] ?? user?.email ?? 'No Email';
          String role = userData['role'] ?? 'regular';
          List<dynamic> ministries = userData['ministries'] ?? [];
          Timestamp? createdAt = userData['createdAt'];

          // Format role display
          String roleDisplay = role == 'admin' 
              ? 'Administrator' 
              : (role == 'volunteer' ? 'Pelayan' : 'Jemaat');

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  color: gkiBlue,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          // Large Avatar
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: Text(
                              _getInitials(name, email),
                              style: TextStyle(
                                color: gkiBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Name
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(
                              roleDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Profile Details Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Informasi Akun",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          
                          // Email
                          _buildInfoRow(Icons.email_outlined, "Email", email),
                          const SizedBox(height: 16),
                          
                          // Member Since
                          if (createdAt != null)
                            _buildInfoRow(
                              Icons.calendar_today_outlined,
                              "Bergabung Sejak",
                              DateFormat('dd MMMM yyyy', 'id_ID').format(createdAt.toDate()),
                            ),
                          const SizedBox(height: 16),
                          
                          // Ministries (if any)
                          if (ministries.isNotEmpty) ...[
                            _buildInfoRow(
                              Icons.church_outlined,
                              "Bidang Pelayanan",
                              ministries.join(", "),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // Daftar Pelayanan Button (ONLY for volunteer and regular, NOT admin)
                      if (role != 'admin') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showVolunteerRequestSheet(context),
                            icon: const Icon(Icons.volunteer_activism),
                            label: const Text("Daftar Pelayanan"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[50],
                              foregroundColor: Colors.blue[900],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // Show confirmation for logout
                            bool confirm = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Keluar"),
                                content: const Text("Apakah Anda yakin ingin keluar?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Batal"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("Keluar"),
                                  ),
                                ],
                              ),
                            ) ?? false;
                            if (!confirm) return;

                            await NotificationService.removeToken();
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                (Route route) => false,
                              );
                            }
                          },
                          
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text("Keluar", style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}