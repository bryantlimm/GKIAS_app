import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_model.dart';
import 'news_detail_screen.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart'; // Make sure this matches your login screen filename

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Helper to get initials (fallback to email if name is empty)
  String _getInitials(String? name, String? email) {
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return "G";
  }

  // Function to show the Volunteer Request Form
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

                  StreamBuilder<QuerySnapshot>(
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
                        initialValue: selectedMinistry,
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
    final Color gkiBlue = const Color(0xFF4285F4); 

    return Scaffold(
      backgroundColor: Colors.grey[100], 
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: gkiBlue, 
            padding: const EdgeInsets.only(bottom: 25.0), 
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: StreamBuilder<DocumentSnapshot>(
                  // Listen to the current user's document in Firestore
                  stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                  builder: (context, snapshot) {
                    
                    // Default values while loading
                    String displayName = 'Jemaat';
                    
                    // If we have data, get the name
                    if (snapshot.hasData && snapshot.data!.exists) {
                      var userData = snapshot.data!.data() as Map<String, dynamic>?;
                      if (userData != null && userData.containsKey('name')) {
                        displayName = userData['name'];
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3), 
                            borderRadius: BorderRadius.circular(20), 
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                          child: Row(
                            children: [
                              // A. The Avatar 
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.white,
                                child: Text(
                                  _getInitials(displayName, user?.email),
                                  style: const TextStyle(
                                    color: Color(0xFF1E3A8A), 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 15),

                              // B. The Welcome Text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Selamat Datang,',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // C. Notification Bell
                              InkWell(
                                onTap: () {
                                  print("Notification Bell Clicked!");
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(
                                    Icons.notifications_none_rounded, 
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 10),

                              // D. The Logout Button FIX
                              InkWell(
                                onTap: () async {
                                  // 1. Sign out of Firebase
                                  await FirebaseAuth.instance.signOut();
                                  
                                  // 2. Force navigate to LoginScreen and wipe navigation history
                                  if (context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (context) => const LoginScreen()), 
                                      (Route<dynamic> route) => false,
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ),
          ),

          // ==========================================
          // 2. THE NEWS LIST
          // ==========================================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('news')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Belum ada warta.'));
                }

                final newsDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 0), 
                  itemCount: newsDocs.length,
                  itemBuilder: (context, index) {
                    final news = NewsItem.fromFirestore(newsDocs[index]);

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewsDetailScreen(news: news),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), 
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), 
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (news.imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: Image.network(
                                  news.imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) => Container(
                                    height: 180,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image, size: 50, color: Colors.grey),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    news.title,
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(news.date),
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
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
          ),

          // Daftar pelayanan button
          ElevatedButton.icon(
            onPressed: () => _showVolunteerRequestSheet(context),
            icon: const Icon(Icons.volunteer_activism),
            label: const Text("Daftar Pelayanan"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[100],
              foregroundColor: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }
}