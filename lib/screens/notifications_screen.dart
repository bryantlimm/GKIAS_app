// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _updateStatus(
    BuildContext context,
    String serviceId,
    List currentAssignments,
    int userIndex,
    String newStatus,
  ) async {
    try {
      List updatedAssignments = List.from(currentAssignments);
      updatedAssignments[userIndex]['status'] = newStatus;

      await FirebaseFirestore.instance
          .collection('service_events')
          .doc(serviceId)
          .update({'assignments': updatedAssignments});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'accepted'
                  ? 'Jadwal berhasil diterima'
                  : 'Jadwal berhasil ditolak',
            ),
            backgroundColor:
                newStatus == 'accepted' ? Colors.green[700] : Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Diterima';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule;
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
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Silakan login")));
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text("Notifikasi & Jadwal",
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
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
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

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(
              icon: Icons.notifications_none,
              message: "Belum ada jadwal baru.",
            );
          }

          List<_AssignmentEntry> myEntries = [];

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final List assignments = data['assignments'] ?? [];

            int myIndex = -1;
            for (int i = 0; i < assignments.length; i++) {
              final a = assignments[i];
              if (a is Map &&
                  a['volunteerId'] != null &&
                  a['volunteerId'].toString() == currentUser.uid) {
                myIndex = i;
                break;
              }
            }

            if (myIndex != -1) {
              myEntries.add(_AssignmentEntry(
                doc: doc,
                data: data,
                assignments: assignments,
                myIndex: myIndex,
              ));
            }
          }

          if (myEntries.isEmpty) {
            return _buildEmptyState(
              icon: Icons.event_available_outlined,
              message: "Anda belum memiliki jadwal pelayanan.",
            );
          }

          // Separate pending from the rest
          final pending =
              myEntries.where((e) => _getStatus(e) == 'pending').toList();
          final others =
              myEntries.where((e) => _getStatus(e) != 'pending').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (pending.isNotEmpty) ...[
                _sectionHeader("Perlu Konfirmasi", Icons.pending_actions,
                    Colors.orange),
                const SizedBox(height: 8),
                ...pending.map((e) => _buildCard(context, e)),
                const SizedBox(height: 16),
              ],
              if (others.isNotEmpty) ...[
                _sectionHeader("History", Icons.history, Colors.blueGrey),
                const SizedBox(height: 8),
                ...others.map((e) => _buildCard(context, e)),
              ],
            ],
          );
        },
      ),
    );
  }

  String _getStatus(_AssignmentEntry entry) {
    return entry.assignments[entry.myIndex]['status'] ?? 'pending';
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _AssignmentEntry entry) {
    final data = entry.data;
    final myAssignment = entry.assignments[entry.myIndex];
    final DateTime date = (data['date'] as Timestamp).toDate();
    final String status = myAssignment['status'] ?? 'pending';
    final Color sColor = _statusColor(status);
    final bool isPending = status == 'pending';

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
        border: isPending
            ? Border.all(color: Colors.orange.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['ministry'] ?? 'Kebaktian',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 12, color: sColor),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: sColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Date
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, d MMMM yyyy • HH:mm', 'id_ID').format(date),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Role
            Row(
              children: [
                Icon(Icons.volunteer_activism,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  "Tugas: ${myAssignment['role']}",
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            // Description
            if (data['description'] != null &&
                (data['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Tema: ${data['description']}",
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Action buttons (pending only)
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _updateStatus(context, entry.doc.id,
                          entry.assignments, entry.myIndex, 'rejected'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text("Tolak"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _updateStatus(context, entry.doc.id,
                          entry.assignments, entry.myIndex, 'accepted'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text("Terima"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssignmentEntry {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final List assignments;
  final int myIndex;

  const _AssignmentEntry({
    required this.doc,
    required this.data,
    required this.assignments,
    required this.myIndex,
  });
}