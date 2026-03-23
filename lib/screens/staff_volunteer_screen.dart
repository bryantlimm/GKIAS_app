// staff_volunteer_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StaffVolunteerScreen extends StatelessWidget {
  const StaffVolunteerScreen({super.key});

  // ── Brand colors ──────────────────────────────────────────────────────────
  static const Color _primary      = Color(0xFF3B5BDB);
  static const Color _bg           = Color(0xFFF0F4F8);
  static const Color _cardBg       = Color(0xFFFFFFFF);
  static const Color _border       = Color(0xFFE8ECF0);
  static const Color _textMain     = Color(0xFF1E293B);
  static const Color _textSub      = Color(0xFF64748B);
  static const Color _textMuted    = Color(0xFF94A3B8);
  static const Color _successBg    = Color(0xFFF0FDF4);
  static const Color _successBorder = Color(0xFFBBF7D0);
  static const Color _successText  = Color(0xFF16A34A);
  static const Color _errorBg      = Color(0xFFFFF5F5);
  static const Color _errorBorder  = Color(0xFFFECACA);
  static const Color _errorText    = Color(0xFFDC2626);
  static const Color _warnBg       = Color(0xFFFFFBEB);
  static const Color _warnBorder   = Color(0xFFFDE68A);
  static const Color _warnText     = Color(0xFFD97706);

  // ── Cancel service ────────────────────────────────────────────────────────
  Future<void> _cancelService(
      BuildContext context, String eventId, List currentAssignments, int myIndex) async {
    final confirm = await _showConfirmDialog(
      context,
      title: 'Batalkan Pelayanan?',
      message: 'Apakah Anda yakin ingin membatalkan jadwal pelayanan ini?',
      confirmLabel: 'Ya, Batalkan',
      isDestructive: true,
    );
    if (confirm && context.mounted) {
      final updated = List.from(currentAssignments);
      updated[myIndex]['status'] = 'cancelled';
      await FirebaseFirestore.instance
          .collection('service_events')
          .doc(eventId)
          .update({'assignments': updated});
      if (context.mounted) _showToast(context, 'Jadwal berhasil dibatalkan.');
    }
  }

  // ── Attendance dialog ─────────────────────────────────────────────────────
  Future<void> _showAttendanceDialog(
      BuildContext context, String docId, Map<String, dynamic> currentData) async {
    final countCtrl = TextEditingController(
        text: currentData['attendance_count']?.toString() ?? '');
    final notesCtrl = TextEditingController(
        text: currentData['attendance_notes'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => _DataInputDialog(
        title: 'Input Kehadiran',
        icon: Icons.people_outline_rounded,
        iconColor: _primary,
        fields: [
          _DialogFieldConfig(controller: countCtrl, label: 'Jumlah Kehadiran', keyboardType: TextInputType.number),
          _DialogFieldConfig(controller: notesCtrl, label: 'Keterangan (Opsional)', maxLines: 2),
        ],
        onSave: () async {
          await FirebaseFirestore.instance
              .collection('service_events')
              .doc(docId)
              .update({
            'attendance_count': int.tryParse(countCtrl.text) ?? 0,
            'attendance_notes': notesCtrl.text,
          });
        },
      ),
    );
  }

  // ── Offering dialog ───────────────────────────────────────────────────────
  Future<void> _showOfferingDialog(
      BuildContext context, String docId, Map<String, dynamic> currentData) async {
    final amountCtrl = TextEditingController(
        text: currentData['offering_amount']?.toString() ?? '');
    final notesCtrl = TextEditingController(
        text: currentData['offering_notes'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => _DataInputDialog(
        title: 'Input Persembahan',
        icon: Icons.volunteer_activism_outlined,
        iconColor: _successText,
        fields: [
          _DialogFieldConfig(controller: amountCtrl, label: 'Total Persembahan (Rp)', keyboardType: TextInputType.number, prefixText: 'Rp '),
          _DialogFieldConfig(controller: notesCtrl, label: 'Keterangan (Opsional)', maxLines: 2),
        ],
        onSave: () async {
          await FirebaseFirestore.instance
              .collection('service_events')
              .doc(docId)
              .update({
            'offering_amount': int.tryParse(
                    amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
            'offering_notes': notesCtrl.text,
          });
        },
      ),
    );
  }

  // ── Mark finished ─────────────────────────────────────────────────────────
  Future<void> _finishService(BuildContext context, String docId) async {
    final confirm = await _showConfirmDialog(
      context,
      title: 'Selesaikan Ibadah?',
      message: 'Data kehadiran dan persembahan akan dikunci dan ibadah dipindahkan ke riwayat Selesai.',
      confirmLabel: 'Ya, Selesai',
      confirmColor: _successText,
    );
    if (confirm) {
      await FirebaseFirestore.instance
          .collection('service_events')
          .doc(docId)
          .update({'is_finished': true});
    }
  }

  // ── Finished details dialog ───────────────────────────────────────────────
  void _showFinishedDetails(
      BuildContext context, Map<String, dynamic> data, DateTime date) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Detail Ibadah Selesai',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['ministry'] ?? 'Kebaktian',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textMain)),
            Text(DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date),
                style: const TextStyle(fontSize: 13, color: _primary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      icon: Icons.people_outline,
                      label: 'Kehadiran',
                      value: '${data['attendance_count'] ?? 0} jiwa',
                    ),
                  ),
                  Container(width: 1, height: 36, color: _border),
                  Expanded(
                    child: _SummaryItem(
                      icon: Icons.volunteer_activism_outlined,
                      label: 'Persembahan',
                      value: NumberFormat.currency(
                              locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                          .format(data['offering_amount'] ?? 0),
                    ),
                  ),
                ],
              ),
            ),
            if (data['attendance_notes'] != null &&
                (data['attendance_notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              _NoteRow(label: 'Catatan kehadiran', value: data['attendance_notes']),
            ],
            if (data['offering_notes'] != null &&
                (data['offering_notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              _NoteRow(label: 'Catatan persembahan', value: data['offering_notes']),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static void _showToast(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? _errorText : _successText,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
    Color confirmColor = _primary,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
            content: Text(message,
                style: const TextStyle(fontSize: 14, color: _textSub)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal', style: TextStyle(color: _textSub)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive ? _errorText : confirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Silakan login.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('Jadwal Pelayanan Saya',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
          backgroundColor: _cardBg,
          foregroundColor: _textMain,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              children: [
                Container(height: 1, color: _border),
                const TabBar(
                  labelColor: _primary,
                  unselectedLabelColor: _textMuted,
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(color: _primary, width: 2.5),
                    insets: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  tabs: [Tab(text: 'Akan Datang'), Tab(text: 'Selesai')],
                ),
              ],
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('service_events')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: _errorText)),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }

            final allDocs = snapshot.data?.docs ?? [];

            // Only show services the volunteer has explicitly accepted.
            // Pending and rejected assignments are handled by the notifications screen.
            final myServices = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final List assignments = data['assignments'] ?? [];
              return assignments.any((a) =>
                  a['volunteerId'] == currentUser.uid &&
                  a['status'] == 'accepted');
            }).toList();

            final upcoming = myServices
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['is_finished'] != true)
                .toList()
              ..sort((a, b) => ((a.data() as Map)['date'] as Timestamp)
                  .compareTo((b.data() as Map)['date'] as Timestamp));

            final finished = myServices
                .where((doc) =>
                    (doc.data() as Map<String, dynamic>)['is_finished'] == true)
                .toList()
              ..sort((a, b) => ((b.data() as Map)['date'] as Timestamp)
                  .compareTo((a.data() as Map)['date'] as Timestamp));

            return TabBarView(
              children: [
                // ── Tab 1: Upcoming ──────────────────────────────────────
                upcoming.isEmpty
                    ? _EmptyState(
                        icon: Icons.event_available_outlined,
                        message: 'Belum ada jadwal pelayanan.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: upcoming.length,
                        itemBuilder: (context, index) {
                          final doc = upcoming[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final date = (data['date'] as Timestamp).toDate();
                          final List assignments = data['assignments'] ?? [];
                          final myIndex = assignments.indexWhere((a) =>
                              a['volunteerId'] == currentUser.uid &&
                              a['status'] != 'cancelled');

                          if (myIndex == -1) return const SizedBox.shrink();

                          final myRole = assignments[myIndex]['role'] ?? '-';
                          final myStatus = assignments[myIndex]['status'] ?? 'pending';
                          final hasAttendance = data.containsKey('attendance_count') && data['attendance_count'] != null;
                          final hasOffering = data.containsKey('offering_amount') && data['offering_amount'] != null;
                          final isPast = date.isBefore(DateTime.now());

                          return _UpcomingServiceCard(
                            ministry: data['ministry'] ?? 'Kebaktian',
                            date: date,
                            role: myRole,
                            assignmentStatus: myStatus,
                            hasAttendance: hasAttendance,
                            attendanceCount: data['attendance_count'],
                            hasOffering: hasOffering,
                            isPast: isPast,
                            onAttendance: () => _showAttendanceDialog(context, doc.id, data),
                            onOffering: () => _showOfferingDialog(context, doc.id, data),
                            onFinish: () => _finishService(context, doc.id),
                            onCancel: () => _cancelService(context, doc.id, assignments, myIndex),
                          );
                        },
                      ),

                // ── Tab 2: Finished ──────────────────────────────────────
                finished.isEmpty
                    ? _EmptyState(
                        icon: Icons.history_rounded,
                        message: 'Belum ada riwayat pelayanan selesai.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: finished.length,
                        itemBuilder: (context, index) {
                          final doc = finished[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final date = (data['date'] as Timestamp).toDate();
                          return _FinishedServiceCard(
                            ministry: data['ministry'] ?? 'Kebaktian',
                            date: date,
                            attendanceCount: data['attendance_count'],
                            offeringAmount: data['offering_amount'],
                            onTap: () => _showFinishedDetails(context, data, date),
                          );
                        },
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Upcoming service card ────────────────────────────────────────────────────

class _UpcomingServiceCard extends StatelessWidget {
  final String ministry, role, assignmentStatus;
  final DateTime date;
  final bool hasAttendance, hasOffering, isPast;
  final int? attendanceCount;
  final VoidCallback onAttendance, onOffering, onFinish, onCancel;

  static const Color _primary      = Color(0xFF3B5BDB);
  static const Color _cardBg       = Color(0xFFFFFFFF);
  static const Color _border       = Color(0xFFE8ECF0);
  static const Color _textMain     = Color(0xFF1E293B);
  static const Color _textSub      = Color(0xFF64748B);
  static const Color _successText  = Color(0xFF16A34A);
  static const Color _errorText    = Color(0xFFDC2626);
  static const Color _warnText     = Color(0xFFD97706);

  const _UpcomingServiceCard({
    required this.ministry,
    required this.date,
    required this.role,
    required this.assignmentStatus,
    required this.hasAttendance,
    required this.attendanceCount,
    required this.hasOffering,
    required this.isPast,
    required this.onAttendance,
    required this.onOffering,
    required this.onFinish,
    required this.onCancel,
  });

  Color get _statusColor => assignmentStatus == 'accepted'
      ? _successText
      : (assignmentStatus == 'rejected' ? _errorText : _warnText);

  String get _statusLabel => assignmentStatus == 'accepted'
      ? 'DITERIMA'
      : (assignmentStatus == 'rejected' ? 'DITOLAK' : 'MENUNGGU');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPast ? const Color(0xFFFDE68A) : const Color(0xFFC7D2FE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date badge
                Container(
                  width: 48, height: 52,
                  decoration: BoxDecoration(
                    color: isPast ? const Color(0xFFFFFBEB) : const Color(0xFFEFF3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                          color: isPast ? _warnText : _primary,
                        ),
                      ),
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, height: 1.1,
                          color: isPast ? _warnText : _primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ministry,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
                      const SizedBox(height: 3),
                      Text('Tugas: $role',
                          style: const TextStyle(fontSize: 13, color: _textSub, fontWeight: FontWeight.w600)),
                      Text(DateFormat('HH:mm').format(date) + ' WIB',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                // Assignment status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor)),
                ),
              ],
            ),
          ),

          // ── Overdue warning ──
          if (isPast) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: _warnText),
                    SizedBox(width: 6),
                    Text('Ibadah sudah berlangsung — mohon lengkapi data.',
                        style: TextStyle(fontSize: 12, color: _warnText, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8ECF0)),
          const SizedBox(height: 10),

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionButton(
                  icon: hasAttendance ? Icons.check_circle_rounded : Icons.people_outline_rounded,
                  label: hasAttendance ? 'Kehadiran: $attendanceCount' : '+ Kehadiran',
                  color: hasAttendance ? _successText : _primary,
                  bg: hasAttendance ? const Color(0xFFF0FDF4) : const Color(0xFFEFF3FF),
                  border: hasAttendance ? const Color(0xFFBBF7D0) : const Color(0xFFC7D2FE),
                  onTap: onAttendance,
                ),
                _ActionButton(
                  icon: hasOffering ? Icons.check_circle_rounded : Icons.volunteer_activism_outlined,
                  label: hasOffering ? 'Persembahan: Diisi' : '+ Persembahan',
                  color: hasOffering ? _successText : _primary,
                  bg: hasOffering ? const Color(0xFFF0FDF4) : const Color(0xFFEFF3FF),
                  border: hasOffering ? const Color(0xFFBBF7D0) : const Color(0xFFC7D2FE),
                  onTap: onOffering,
                ),
                _ActionButton(
                  icon: Icons.done_all_rounded,
                  label: 'Ibadah Selesai',
                  color: _successText,
                  bg: const Color(0xFFF0FDF4),
                  border: const Color(0xFFBBF7D0),
                  onTap: onFinish,
                ),
              ],
            ),
          ),

          // ── Cancel link ──
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCancel,
              child: const Text('Batalkan Jadwal',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Finished service card ────────────────────────────────────────────────────

class _FinishedServiceCard extends StatelessWidget {
  final String ministry;
  final DateTime date;
  final int? attendanceCount, offeringAmount;
  final VoidCallback onTap;

  static const Color _cardBg   = Color(0xFFFFFFFF);
  static const Color _border   = Color(0xFFE8ECF0);
  static const Color _textMain = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _primary  = Color(0xFF3B5BDB);

  const _FinishedServiceCard({
    required this.ministry,
    required this.date,
    required this.attendanceCount,
    required this.offeringAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date badge
            Container(
              width: 44, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('MMM').format(date).toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _textMuted, letterSpacing: 0.5)),
                  Text(DateFormat('dd').format(date),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textMuted, height: 1.1)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ministry,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textMain)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.people_outline, size: 13, color: _textMuted),
                    const SizedBox(width: 4),
                    Text('${attendanceCount ?? 0} jiwa',
                        style: const TextStyle(fontSize: 12, color: _textMuted)),
                    const SizedBox(width: 12),
                    const Icon(Icons.volunteer_activism_outlined, size: 13, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(
                      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                          .format(offeringAmount ?? 0),
                      style: const TextStyle(fontSize: 12, color: _textMuted),
                    ),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable dialog with configurable fields ─────────────────────────────────

class _DialogFieldConfig {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? prefixText;
  final int maxLines;

  const _DialogFieldConfig({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.prefixText,
    this.maxLines = 1,
  });
}

class _DataInputDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_DialogFieldConfig> fields;
  final Future<void> Function() onSave;

  const _DataInputDialog({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.fields,
    required this.onSave,
  });

  @override
  State<_DataInputDialog> createState() => _DataInputDialogState();
}

class _DataInputDialogState extends State<_DataInputDialog> {
  bool _isSaving = false;

  static const Color _primary  = Color(0xFF3B5BDB);
  static const Color _textMain = Color(0xFF1E293B);
  static const Color _textSub  = Color(0xFF64748B);
  static const Color _border   = Color(0xFFE2E8F0);
  static const Color _errorText = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: widget.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Text(widget.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textMain)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.fields.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: f.controller,
            keyboardType: f.keyboardType,
            maxLines: f.maxLines,
            style: const TextStyle(fontSize: 14, color: _textMain),
            decoration: InputDecoration(
              labelText: f.label,
              labelStyle: const TextStyle(fontSize: 13, color: _textSub),
              prefixText: f.prefixText,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
        )).toList(),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: _textSub)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            disabledBackgroundColor: const Color(0xFF93A3C7),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  try {
                    await widget.onSave();
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Gagal menyimpan: $e'),
                        backgroundColor: _errorText,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Misc widgets ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg, border;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon, required this.label,
    required this.color, required this.bg, required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _SummaryItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    ]);
  }
}

class _NoteRow extends StatelessWidget {
  final String label, value;
  const _NoteRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic))),
    ]);
  }
}