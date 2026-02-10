import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_model.dart';
import 'package:intl/intl.dart';
import 'news_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // @override
  // Helper to get initials from email (e.g., "bryant@..." -> "B")
  String _getInitials(String? email) {
    if (email == null || email.isEmpty) return "G"; // G for Guest or GKI
    return email[0].toUpperCase();
  }

  // Helper to get a display name (e.g., "bryant@..." -> "Bryant")
  String _getName(User user) {
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    // Fallback: take the part before @ in the email
    String emailName = user.email!.split('@')[0];
    // Capitalize first letter
    return emailName[0].toUpperCase() + emailName.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Define GKI Blue color (approximate, you can change this hex code)
    final Color gkiBlue = const Color.fromARGB(255, 74, 138, 250); 

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for the body
      appBar: AppBar(
        backgroundColor: gkiBlue,
        elevation: 0, // Flat look like the screenshot
        toolbarHeight: 80, // Taller to fit the avatar nicely
        title: Row(
          children: [
            // 1. The Avatar (Profile Picture)
            CircleAvatar(
              radius: 24, // Size of the circle
              backgroundColor: Colors.white.withOpacity(0.2), // Slightly transparent white
              child: Text(
                _getInitials(user?.email),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            
            const SizedBox(width: 12), // Space between avatar and text
            
            // 2. The Text (Welcome + Name)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Selamat Datang,', // "Welcome" in Indonesian
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                Text(
                  user != null ? _getName(user) : 'Jemaat',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 3. The Settings/Logout Icon
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () {
                // Add a confirmation dialog before logging out?
                FirebaseAuth.instance.signOut();
              },
            ),
          ),
        ],
      ),
      // StreamBuilder listens to the database in real-time
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news')
            .orderBy('date', descending: true) // Newest first
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Is it loading?
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Was there an error?
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // 3. Is the data empty?
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No bulletins found.'));
          }

          // 4. Success! Let's build the list
          final newsDocs = snapshot.data!.docs;
          
          return ListView.builder(
            itemCount: newsDocs.length,
            itemBuilder: (context, index) {
              final news = NewsItem.fromFirestore(newsDocs[index]);

              // WRAP THE CARD IN INKWELL TO DETECT TAPS
              return InkWell(
                onTap: () {
                  // Navigate to the Detail Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewsDetailScreen(news: news),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Adjusted margin slightly
                  elevation: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (news.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          child: Image.network(
                            news.imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, o, s) => Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. The Title
                            Text(
                              news.title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // 2. The Date
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd MMM yyyy').format(news.date),
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            
                            // 3. (Deleted the content preview here!)
                          ],
                        ),
                      ),
                    ],

                    //
                  ),
                ),
              );
            },
          );

          //
        },
      ),
    );
  }
}