import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'create_service_screen.dart';
import 'package:intl/intl.dart';
import 'admin_manage_staff_screen.dart';
import 'staff_volunteer_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _userRole = 'regular';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('role')) {
          setState(() {
            _userRole = doc['role'];
          });
        }
      } catch (e) {
        print("Error fetching role: $e");
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 1. Define the possible screens
    final List<Widget> screens = [];
    final List<BottomNavigationBarItem> navItems = [];

    // EVERYONE gets the Home Screen first
    screens.add(const HomeScreen());
    navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
    );

    // 2. Add tabs based on role
    if (_userRole == 'volunteer') {
      screens.add(const StaffVolunteerScreen());
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_ind_rounded),
          label: 'Jadwal Saya',
        ),
      );
    } else if (_userRole == 'admin') {
      // Admin Menu 1: Create/Manage Specific Services
      screens.add(const AdminServicesScreen());
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.event_note_rounded),
          label: 'Kebaktian', // Services
        ),
      );

      // Admin Menu 2: Manage Staff/Volunteers
      screens.add(const AdminManageStaffScreen());
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_rounded),
          label: 'Pelayan',
        ),
      );
    }

    // 3. If there's only 1 item (Regular User), don't show the BottomNavBar
    if (navItems.length < 2) {
      return screens[0]; // Just return the HomeScreen directly
    }

    // 4. Return the Scaffold with the BottomNavBar for Volunteers/Admins
    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF1E3A8A), // gkiBlue
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Keeps all labels visible
      ),
    );
  }
}

// ==========================================
// PLACEHOLDER SCREENS (We will build these out next)
// ==========================================

// class StaffVolunteerScreen extends StatelessWidget {
//   const StaffVolunteerScreen({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(child: Text("Halaman Pelayan/Volunteer (Segera Hadir)")),
//     );
//   }
// }

// class AdminServicesScreen extends StatelessWidget {
//   const AdminServicesScreen({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(child: Text("Halaman Admin: Kelola Kebaktian (Segera Hadir)")),
//     );
//   }
// }

class AdminServicesScreen extends StatelessWidget {
  const AdminServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Kebaktian"),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the Create Page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateServiceScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_events')
            .orderBy('date', descending: false) // Upcoming events first
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Belum ada jadwal."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              DateTime date = (data['date'] as Timestamp).toDate();
              
              // Count how many people assigned
              List assignments = data['assignments'] ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('MMM').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(DateFormat('dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                  title: Text(data['ministry'] ?? 'Kebaktian'),
                  subtitle: Text("${assignments.length} Petugas • ${data['description'] ?? ''}"),
                  trailing: const Icon(Icons.edit, color: Colors.grey), // Changed icon to edit
                  
                  // NEW: Pass the document to open Edit Mode!
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateServiceScreen(existingService: docs[index]),
                      ),
                    );
                  },
                  
                ),
              );
            },
          );
        },
      ),
    );
  }
}
