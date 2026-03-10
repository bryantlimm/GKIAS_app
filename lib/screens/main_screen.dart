import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'create_service_screen.dart';
import 'package:intl/intl.dart';
import 'admin_manage_staff_screen.dart';
import 'staff_volunteer_screen.dart';
import 'admin_events_screen.dart'; // CHANGED from admin_services_screen
import 'profile_screen.dart';

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

    final List<Widget> screens = [];
    final List<BottomNavigationBarItem> navItems = [];

    // EVERYONE gets Home
    screens.add(const HomeScreen());
    navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
    );

    // Role-specific screens
    if (_userRole == 'volunteer') {
      screens.add(const StaffVolunteerScreen());
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_ind_rounded),
          label: 'Jadwal Saya',
        ),
      );
    } else if (_userRole == 'admin') {
      // Admin: Events (Kebaktian + Registrasi)
      screens.add(const AdminEventsScreen()); // CHANGED
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.event_note_rounded),
          label: 'Events', // CHANGED from 'Kebaktian'
        ),
      );

      // Admin: Users (Permintaan)
      screens.add(const AdminManageStaffScreen());
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_add_alt_1_rounded),
          label: 'Users',
        ),
      );
    }

    // EVERYONE gets Profile
    screens.add(const ProfileScreen());
    navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_rounded),
        label: 'Profil',
      ),
    );

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}