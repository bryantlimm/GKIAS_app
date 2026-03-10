import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_model.dart';
import 'news_detail_screen.dart';
import 'package:intl/intl.dart';
import 'notifications_screen.dart';
import 'admin_notification_screen.dart';
import 'registration_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getInitials(String? name, String? email) {
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return "G";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color gkiBlue = const Color(0xFF4285F4);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: gkiBlue,
            padding: const EdgeInsets.only(bottom: 25.0),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                  builder: (context, snapshot) {
                    String displayName = 'Jemaat';
                    if (snapshot.hasData && snapshot.data!.exists) {
                      var userData = snapshot.data!.data() as Map?;
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Selamat Datang,',
                                      style: TextStyle(fontSize: 12, color: Colors.white70),
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
                              InkWell(
                                onTap: () async {
                                  final currentUser = FirebaseAuth.instance.currentUser;
                                  if (currentUser == null) return;

                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(child: CircularProgressIndicator()),
                                  );

                                  try {
                                    DocumentSnapshot userDoc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(currentUser.uid)
                                        .get();

                                    String role = 'jemaat';
                                    if (userDoc.exists) {
                                      var data = userDoc.data() as Map;
                                      role = data['role'] ?? 'jemaat';
                                    }

                                    if (context.mounted) Navigator.pop(context);

                                    if (context.mounted) {
                                      if (role == 'admin') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const AdminNotificationScreen()),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Gagal memuat notifikasi: $e")),
                                      );
                                    }
                                  }
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

          // NEW: Registration & My Events Container
          _buildRegistrationContainer(context),

          // News List
          Expanded(
            child: StreamBuilder(
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
        ],
      ),
    );
  }

  Widget _buildRegistrationContainer(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const TabBar(
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: [
                  Tab(text: "Registrasi", icon: Icon(Icons.app_registration)),
                  Tab(text: "Event Saya", icon: Icon(Icons.event_available)),
                ],
              ),
            ),
            SizedBox(
              height: 200, // Fixed height for the tab content
              child: TabBarView(
                children: [
                  // Tab 1: Open Registrations
                  _buildOpenRegistrationsTab(context),
                  // Tab 2: My Events
                  _buildMyEventsTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildOpenRegistrationsTab(BuildContext context) {
    final now = DateTime.now();

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('date')  // Simpler query - remove where clause
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter on client side
        var events = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          
          // Must be registration type
          if (data['type'] != 'registration') return false;
          
          // Must not be finished
          if (data['is_finished'] == true) return false;
          
          // Check deadline
          DateTime? deadline = data['registrationDeadline'] != null 
              ? (data['registrationDeadline'] as Timestamp).toDate() 
              : null;
          if (deadline != null && deadline.isBefore(now)) return false;
          
          // Check if event date is in future
          DateTime eventDate = (data['date'] as Timestamp).toDate();
          return eventDate.isAfter(now.subtract(const Duration(days: 1)));
        }).toList();

        if (events.isEmpty) {
          return const Center(
            child: Text(
              "Tidak ada registrasi terbuka sekarang",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: events.length,
          itemBuilder: (context, index) {
            var event = events[index];
            var data = event.data() as Map<String, dynamic>;
            DateTime date = (data['date'] as Timestamp).toDate();
            int capacity = data['capacity'] ?? 0;
            int current = data['currentRegistrants'] ?? 0;
            bool isFull = current >= capacity;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFull ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFull ? Icons.lock : Icons.app_registration,
                    color: isFull ? Colors.red : Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(
                  data['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  "${DateFormat('dd MMM yyyy').format(date)} • $current/$capacity terdaftar${isFull ? ' (PENUH)' : ''}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isFull ? Colors.red : Colors.grey[600],
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: isFull 
                    ? null 
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegistrationDetailScreen(event: event),
                          ),
                        );
                      },
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildMyEventsTab(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Silakan login"));

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('registeredBy', isEqualTo: user.uid)
          .orderBy('registeredAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "Belum ada event yang terdaftar",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }

        var registrations = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: registrations.length,
          itemBuilder: (context, index) {
            var reg = registrations[index];
            var regData = reg.data() as Map<String, dynamic>;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('events').doc(regData['eventId']).get(),
              builder: (context, eventSnapshot) {
                if (!eventSnapshot.hasData) return const SizedBox.shrink();

                var eventData = eventSnapshot.data!.data() as Map<String, dynamic>?;
                if (eventData == null) return const SizedBox.shrink();

                DateTime eventDate = (eventData['date'] as Timestamp).toDate();
                bool isPast = eventDate.isBefore(DateTime.now());

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPast ? Colors.grey[200] : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPast ? Icons.check_circle : Icons.event,
                        color: isPast ? Colors.grey : Colors.blue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      regData['eventTitle'] ?? 'Event',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isPast ? Colors.grey : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      "Atas nama: ${regData['name']}\n${DateFormat('dd MMM yyyy').format(eventDate)}",
                      style: TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: isPast
                        ? const Text("Selesai", style: TextStyle(color: Colors.grey, fontSize: 12))
                        : TextButton(
                            onPressed: () async {
                              // Navigate to detail to cancel
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegistrationDetailScreen(event: eventSnapshot.data!),
                                ),
                              );
                              if (result == true) {
                                // Refresh if needed
                              }
                            },
                            child: const Text("Detail"),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}