// home_screen.dart
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

  static const Color _primary   = Color(0xFF3B5BDB);
  static const Color _bg        = Color(0xFFF0F4F8);
  static const Color _textMuted = Color(0xFF94A3B8);

  String _getInitials(String? name, String? email) {
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return 'G';
  }

  Future<void> _onNotificationTap(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(currentUser.uid).get();
      final role = (userDoc.data() as Map?)?['role'] ?? 'jemaat';
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => role == 'admin'
              ? const AdminNotificationScreen()
              : const NotificationsScreen(),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat notifikasi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ── KEY FIX: return Container, NOT Scaffold ──────────────────────────
    // HomeScreen is a tab inside MainScreen's Scaffold. If we wrap in our
    // own Scaffold here, the bottom nav bar from MainScreen gets hidden
    // because Flutter only shows the innermost Scaffold's bottom nav.
    return Container(
      color: _bg,
      child: CustomScrollView(
        slivers: [

          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: _primary,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users').doc(user?.uid).snapshots(),
                    builder: (context, snapshot) {
                      String displayName = 'Jemaat';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map?;
                        if (data != null && data.containsKey('name')) {
                          displayName = data['name'];
                        }
                      }
                      return Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          child: Text(_getInitials(displayName, user?.email),
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Selamat datang,',
                                style: TextStyle(fontSize: 12, color: Colors.white70,
                                    fontWeight: FontWeight.w500)),
                            Text(displayName,
                                style: const TextStyle(fontSize: 17, color: Colors.white,
                                    fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        GestureDetector(
                          onTap: () => _onNotificationTap(context),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notifications_none_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── Registration & My Events card ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _RegistrationCard(),
            ),
          ),

          // ── Section label ────────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text('WARTA & BERITA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: _textMuted, letterSpacing: 0.8)),
            ),
          ),

          // ── News list ────────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('news')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: _primary))),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('Belum ada warta.',
                          style: TextStyle(color: _textMuted)))),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final news = NewsItem.fromFirestore(snapshot.data!.docs[index]);
                      return _NewsCard(news: news);
                    },
                    childCount: snapshot.data!.docs.length,
                  ),
                ),
              );
            },
          ),

        ],
      ),
    );
  }
}

// ─── Registration card ────────────────────────────────────────────────────────

class _RegistrationCard extends StatefulWidget {
  @override
  State<_RegistrationCard> createState() => _RegistrationCardState();
}

class _RegistrationCardState extends State<_RegistrationCard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _primary   = Color(0xFF3B5BDB);
  static const Color _border    = Color(0xFFE8ECF0);
  static const Color _textMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 16, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          decoration: const BoxDecoration(color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13))),
          child: TabBar(
            controller: _tabController,
            labelColor: _primary, unselectedLabelColor: _textMuted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: _primary, width: 2.5),
              insets: EdgeInsets.symmetric(horizontal: 16),
            ),
            tabs: const [
              Tab(text: 'Registrasi', icon: Icon(Icons.app_registration_outlined, size: 18)),
              Tab(text: 'Event Saya', icon: Icon(Icons.event_available_outlined, size: 18)),
            ],
          ),
        ),
        SizedBox(height: 220, child: TabBarView(
          controller: _tabController,
          children: [_OpenRegistrationsTab(), _MyEventsTab()],
        )),
      ]),
    );
  }
}

class _OpenRegistrationsTab extends StatelessWidget {
  static const Color _primary   = Color(0xFF3B5BDB);
  static const Color _textMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _primary));
        final events = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['type'] != 'registration') return false;
          if (data['is_finished'] == true) return false;
          final deadline = data['registrationDeadline'] != null
              ? (data['registrationDeadline'] as Timestamp).toDate() : null;
          if (deadline != null && deadline.isBefore(now)) return false;
          return (data['date'] as Timestamp).toDate().isAfter(now.subtract(const Duration(days: 1)));
        }).toList();

        if (events.isEmpty) {
          return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_outlined, color: _textMuted, size: 32),
            SizedBox(height: 8),
            Text('Tidak ada registrasi terbuka', style: TextStyle(color: _textMuted, fontSize: 13)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final data = event.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final capacity = data['capacity'] ?? 0;
            final current = data['currentRegistrants'] ?? 0;
            final isFull = current >= capacity;
            return _EventListTile(
              title: data['title'], subtitle: DateFormat('dd MMM yyyy').format(date),
              badge: '$current/$capacity', isFull: isFull,
              onTap: isFull ? null : () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => RegistrationDetailScreen(event: event))),
            );
          },
        );
      },
    );
  }
}

class _MyEventsTab extends StatelessWidget {
  static const Color _primary   = Color(0xFF3B5BDB);
  static const Color _textMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Silakan login', style: TextStyle(color: _textMuted)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations').where('userId', isEqualTo: user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_outlined, color: _textMuted, size: 32),
            SizedBox(height: 8),
            Text('Belum ada event terdaftar', style: TextStyle(color: _textMuted, fontSize: 13)),
          ]));
        }
        final docs = [...snapshot.data!.docs];
        docs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['registeredAt'] as Timestamp?;
          final bTs = (b.data() as Map<String, dynamic>)['registeredAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final reg = docs[index];
            final regData = reg.data() as Map<String, dynamic>;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('events').doc(regData['eventId']).get(),
              builder: (context, evSnap) {
                if (!evSnap.hasData) return const SizedBox.shrink();
                final evData = evSnap.data!.data() as Map<String, dynamic>?;
                if (evData == null) return const SizedBox.shrink();
                final eventDate = (evData['date'] as Timestamp).toDate();
                final isPast = eventDate.isBefore(DateTime.now());
                return _EventListTile(
                  title: regData['eventTitle'] ?? 'Event',
                  subtitle: 'Atas nama: ${regData['name']}  •  ${DateFormat('dd MMM yyyy').format(eventDate)}',
                  badge: isPast ? 'Selesai' : 'Terdaftar', isFull: isPast,
                  onTap: isPast ? null : () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => RegistrationDetailScreen(event: evSnap.data!))),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EventListTile extends StatelessWidget {
  final String title, subtitle, badge;
  final bool isFull;
  final VoidCallback? onTap;

  const _EventListTile({required this.title, required this.subtitle,
      required this.badge, required this.isFull, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: isFull ? const Color(0xFFE2E8F0) : const Color(0xFFC7D2FE), width: 1.5),
        ),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(
              color: isFull ? const Color(0xFF94A3B8) : const Color(0xFF3B5BDB), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: isFull ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: isFull ? const Color(0xFFF1F5F9) : const Color(0xFFEFF3FF),
                borderRadius: BorderRadius.circular(20)),
            child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: isFull ? const Color(0xFF94A3B8) : const Color(0xFF3B5BDB))),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
          ],
        ]),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem news;
  const _NewsCard({required this.news});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => NewsDetailScreen(news: news))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (news.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(news.imageUrl, height: 170, width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 170,
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.image_outlined, size: 40, color: Color(0xFF94A3B8)))),
            ),
          Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(news.title, style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Text(DateFormat('dd MMM yyyy').format(news.date),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                const Text('Baca selengkapnya', style: TextStyle(fontSize: 12,
                    color: Color(0xFF3B5BDB), fontWeight: FontWeight.w700)),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF3B5BDB)),
              ]),
            ],
          )),
        ]),
      ),
    );
  }
}