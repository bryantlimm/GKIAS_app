// lib/screens/admin_notification_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminNotificationScreen extends StatelessWidget {
  const AdminNotificationScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.event_busy;
      default:
        return Icons.schedule;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Diterima';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  static const Color _primary      = Color(0xFF3B5BDB);
  static const Color _bg           = Color(0xFFF0F4F8);
  static const Color _cardBg       = Color(0xFFFFFFFF);
  static const Color _border       = Color(0xFFE8ECF0);
  static const Color _textMain     = Color(0xFF1E293B);
  static const Color _textSub      = Color(0xFF64748B);
  static const Color _textMuted    = Color(0xFF94A3B8);
  static const Color _successBg    = Color(0xFFF0FDF4);
  static const Color _successText  = Color(0xFF16A34A);
  static const Color _errorBg      = Color(0xFFFFF5F5);
  static const Color _errorText    = Color(0xFFDC2626);
  static const Color _warnText     = Color(0xFFD97706);
  @override
  Widget build(BuildContext context) {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("Notifikasi Respons", 
        style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textMain,
            )),
        backgroundColor: _cardBg,
        foregroundColor: _textMain,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_events')
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(
                      "Terjadi kesalahan:\n${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final List<Map<String, dynamic>> notifications = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final List assignments = data['assignments'] ?? [];
            final DateTime eventDate = (data['date'] as Timestamp).toDate();
            final String ministry = data['ministry'] ?? 'Pelayanan';

            for (var assignment in assignments) {
              final String status = assignment['status'] ?? 'pending';
              if (status == 'accepted' ||
                  status == 'rejected' ||
                  status == 'cancelled') {
                notifications.add({
                  'volunteerName': assignment['volunteerName'] ?? 'Seseorang',
                  'role': assignment['role'] ?? 'Petugas',
                  'status': status,
                  'ministry': ministry,
                  'eventDate': eventDate,
                });
              }
            }
          }

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    "Belum ada respons pelayanan\ndalam 30 hari terakhir.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          }

          notifications
              .sort((a, b) => b['eventDate'].compareTo(a['eventDate']));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final String status = notif['status'];
              final Color sColor = _statusColor(status);
              final DateTime eventDate = notif['eventDate'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: sColor.withOpacity(0.12),
                        child: Icon(
                          _statusIcon(status),
                          color: sColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Narrative text
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: notif['volunteerName'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (status == 'cancelled') ...[
                                    const TextSpan(
                                        text:
                                            " membatalkan jadwal pelayanan "),
                                    TextSpan(
                                      text: notif['ministry'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: " pada "),
                                    TextSpan(
                                      text: DateFormat('dd MMM yyyy')
                                          .format(eventDate),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: "."),
                                  ] else ...[
                                    TextSpan(
                                      text: status == 'accepted'
                                          ? " menerima "
                                          : " menolak ",
                                    ),
                                    const TextSpan(text: "tugas sebagai "),
                                    TextSpan(
                                      text: notif['role'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: " untuk "),
                                    TextSpan(
                                      text: notif['ministry'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(text: "."),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Footer row: date + status badge
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('EEEE, d MMM yyyy', 'id_ID')
                                      .format(eventDate),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: sColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                      color: sColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
    );
  }
}