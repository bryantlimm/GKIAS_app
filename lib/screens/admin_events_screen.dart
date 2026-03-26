// admin_events_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'create_service_screen.dart';
import 'create_registration_screen.dart';

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  // ── Brand colors ──────────────────────────────────────────────────────────
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

  // ── Edit finished service dialog ──────────────────────────────────────────
  Future<void> _editFinishedService(
      BuildContext context, DocumentSnapshot doc, String collection) async {
    final data = doc.data() as Map<String, dynamic>;
    final attCountCtrl  = TextEditingController(text: data['attendance_count']?.toString() ?? '0');
    final attNotesCtrl  = TextEditingController(text: data['attendance_notes'] ?? '');
    final offAmountCtrl = TextEditingController(text: data['offering_amount']?.toString() ?? '0');
    final offNotesCtrl  = TextEditingController(text: data['offering_notes'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Detail & Edit Ibadah',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['title'] ?? data['ministry'] ?? 'Kebaktian',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textMain)),
              Text(
                DateFormat('EEEE, d MMM yyyy')
                    .format((data['date'] as Timestamp).toDate()),
                style: const TextStyle(color: _textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _DialogSectionLabel(text: 'Kehadiran'),
              const SizedBox(height: 8),
              _DialogField(controller: attCountCtrl, label: 'Jumlah Kehadiran', keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              _DialogField(controller: attNotesCtrl, label: 'Catatan Kehadiran'),
              const SizedBox(height: 16),
              _DialogSectionLabel(text: 'Persembahan'),
              const SizedBox(height: 8),
              _DialogField(controller: offAmountCtrl, label: 'Total Persembahan (Rp)', keyboardType: TextInputType.number, prefixText: 'Rp '),
              const SizedBox(height: 8),
              _DialogField(controller: offNotesCtrl, label: 'Catatan Persembahan'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: _textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await doc.reference.update({
                'attendance_count': int.tryParse(attCountCtrl.text) ?? 0,
                'attendance_notes': attNotesCtrl.text,
                'offering_amount': int.tryParse(offAmountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                'offering_notes':  offNotesCtrl.text,
              });
              if (context.mounted) {
                Navigator.pop(context);
                _showToast(context, 'Data berhasil diperbarui!');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── Registrants bottom sheet ──────────────────────────────────────────────
// ── Registrants bottom sheet ──────────────────────────────────────────────
  void _showRegistrants(BuildContext context, DocumentSnapshot eventDoc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Daftar Registran',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textMain)),
                              Text(eventDoc['title'] ?? '',
                                  style: const TextStyle(fontSize: 13, color: _textMuted)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: _textSub),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('registrations')
                          .where('eventId', isEqualTo: eventDoc.id)
                          // ✅ Removed .orderBy('registeredAt') — that requires a composite
                          //    index in Firestore and causes the stream to hang without one.
                          //    We sort client-side below instead.
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Terjadi kesalahan:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _errorText, fontSize: 13),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: _primary));
                        }

                        if (snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 40, color: _textMuted),
                                SizedBox(height: 8),
                                Text('Belum ada registran.',
                                    style: TextStyle(color: _textMuted, fontSize: 14)),
                              ],
                            ),
                          );
                        }

                        // ✅ Sort client-side by registeredAt descending
                        final docs = snapshot.data!.docs.toList()
                          ..sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            final aTime = aData['registeredAt'] as Timestamp?;
                            final bTime = bData['registeredAt'] as Timestamp?;
                            if (aTime == null || bTime == null) return 0;
                            return bTime.compareTo(aTime);
                          });

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final reg = docs[index];
                            final regData = reg.data() as Map<String, dynamic>;
                            final initials = (regData['name'] ?? 'U')[0].toUpperCase();

                            return Container(
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _border, width: 1.5),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _primary,
                                  child: Text(initials,
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                                title: Text(regData['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14, color: _textMain)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Kontak: ${regData['contact'] ?? '-'}',
                                        style: const TextStyle(fontSize: 12, color: _textSub)),
                                    if (regData['description'] != null &&
                                        (regData['description'] as String).isNotEmpty)
                                      Text('Keterangan: ${regData['description']}',
                                          style: const TextStyle(fontSize: 12, color: _textSub)),
                                    if (regData['registeredAt'] != null)
                                      Text(
                                        DateFormat('dd MMM yyyy, HH:mm').format(
                                            (regData['registeredAt'] as Timestamp).toDate()),
                                        style: const TextStyle(fontSize: 11, color: _textMuted),
                                      ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: _errorText, size: 20),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) =>
                                              _ConfirmDeleteDialog(name: regData['name'] ?? ''),
                                        ) ??
                                        false;
                                    if (confirm) {
                                      await reg.reference.delete();
                                      await eventDoc.reference.update({
                                        'currentRegistrants': FieldValue.increment(-1),
                                      });
                                    }
                                  },
                                ),
                                onTap: regData['documentUrl'] != null
                                    ? () => showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14)),
                                            title: const Text('Dokumen Registran'),
                                            content: Image.network(regData['documentUrl']),
                                            actions: [
                                              TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('Tutup'))
                                            ],
                                          ),
                                        )
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── Delete event ──────────────────────────────────────────────────────────
  Future<void> _deleteEvent(
      BuildContext context, DocumentSnapshot doc, String eventType, String collection) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Event',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
        content: Text(
          'Apakah Anda yakin ingin menghapus ${eventType == 'kebaktian' ? 'kebaktian' : 'registrasi'} ini?',
          style: const TextStyle(fontSize: 14, color: _textSub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: _textSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _errorText, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      if (eventType == 'registration') {
        final regs = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: doc.id)
            .get();
        for (final reg in regs.docs) await reg.reference.delete();
      }
      await doc.reference.delete();
      if (context.mounted) _showToast(context, 'Event berhasil dihapus.');
    } catch (e) {
      if (context.mounted) _showToast(context, 'Gagal menghapus: $e', isError: true);
    }
  }

  // ── Create options sheet ──────────────────────────────────────────────────
  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Buat Event Baru',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textMain)),
              const SizedBox(height: 4),
              const Text('Pilih jenis event yang ingin dibuat',
                  style: TextStyle(fontSize: 13, color: _textMuted)),
              const SizedBox(height: 20),
              _CreateOptionTile(
                icon: Icons.church_outlined,
                color: _primary,
                title: 'Kebaktian',
                subtitle: 'Jadwal ibadah dengan petugas',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateServiceScreen()));
                },
              ),
              const SizedBox(height: 10),
              _CreateOptionTile(
                icon: Icons.app_registration_outlined,
                color: _successText,
                title: 'Registrasi',
                subtitle: 'Form pendaftaran untuk acara',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRegistrationScreen()));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showToast(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? _errorText : _successText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('Events',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textMain)),
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
                  tabs: [
                    Tab(text: 'Akan Datang'),
                    Tab(text: 'Selesai'),
                  ],
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateOptions(context),
          backgroundColor: _primary,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, eventsSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_events')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, serviceSnapshot) {
                if (eventsSnapshot.connectionState == ConnectionState.waiting ||
                    serviceSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primary));
                }

                // Merge both collections
                final List<DocumentSnapshot> allDocs = [];
                if (eventsSnapshot.hasData) {
                  allDocs.addAll(eventsSnapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['type'] == 'registration';
                  }));
                }
                if (serviceSnapshot.hasData) {
                  allDocs.addAll(serviceSnapshot.data!.docs);
                }

                final now = DateTime.now();

                final upcomingDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isFinished = data['is_finished'] == true;
                  final isRegistration = data['type'] == 'registration';
                  final eventDate = (data['date'] as Timestamp).toDate();

                  if (isRegistration) {
                    // Registration: upcoming = not yet passed today
                    return !isFinished && eventDate.isAfter(now.subtract(const Duration(days: 1)));
                  } else {
                    // Service (kebaktian): upcoming = not marked finished, even if date is past
                    return !isFinished;
                  }
                }).toList()
                  ..sort((a, b) {
                    final dateA = ((a.data() as Map)['date'] as Timestamp).toDate();
                    final dateB = ((b.data() as Map)['date'] as Timestamp).toDate();
                    return dateA.compareTo(dateB); // ascending for upcoming
                  });

                final finishedDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isFinished = data['is_finished'] == true;
                  final isRegistration = data['type'] == 'registration';
                  final eventDate = (data['date'] as Timestamp).toDate();

                  if (isRegistration) {
                    // Registration: finished = date has passed
                    return eventDate.isBefore(now.subtract(const Duration(days: 1)));
                  } else {
                    // Service: finished = explicitly marked finished
                    return isFinished;
                  }
                }).toList()
                  ..sort((a, b) {
                    final dateA = ((a.data() as Map)['date'] as Timestamp).toDate();
                    final dateB = ((b.data() as Map)['date'] as Timestamp).toDate();
                    return dateB.compareTo(dateA); // descending for finished
                  });

                return TabBarView(
                  children: [
                    _EventsList(
                      docs: upcomingDocs,
                      isFinished: false,
                      emptyMessage: 'Tidak ada event mendatang.',
                      onEditFinished: (doc, collection) =>
                          _editFinishedService(context, doc, collection),
                      onShowRegistrants: (doc) => _showRegistrants(context, doc),
                      onDelete: (doc, type, col) =>
                          _deleteEvent(context, doc, type, col),
                    ),
                    _EventsList(
                      docs: finishedDocs,
                      isFinished: true,
                      emptyMessage: 'Belum ada riwayat event selesai.',
                      onEditFinished: (doc, collection) =>
                          _editFinishedService(context, doc, collection),
                      onShowRegistrants: (doc) => _showRegistrants(context, doc),
                      onDelete: (doc, type, col) =>
                          _deleteEvent(context, doc, type, col),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

}

// ─── Events list widget ───────────────────────────────────────────────────────

class _EventsList extends StatelessWidget {
  final List<DocumentSnapshot> docs;
  final bool isFinished;
  final String emptyMessage;
  final Future<void> Function(DocumentSnapshot, String) onEditFinished;
  final void Function(DocumentSnapshot) onShowRegistrants;
  final Future<void> Function(DocumentSnapshot, String, String) onDelete;

  const _EventsList({
    required this.docs,
    required this.isFinished,
    required this.emptyMessage,
    required this.onEditFinished,
    required this.onShowRegistrants,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available_outlined, size: 44, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(emptyMessage, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: docs.length,
      itemBuilder: (context, index) => _EventCard(
        doc: docs[index],
        isFinished: isFinished,
        onEditFinished: onEditFinished,
        onShowRegistrants: onShowRegistrants,
        onDelete: onDelete,
      ),
    );
  }
}

// ─── Event card ───────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final bool isFinished;
  final Future<void> Function(DocumentSnapshot, String) onEditFinished;
  final void Function(DocumentSnapshot) onShowRegistrants;
  final Future<void> Function(DocumentSnapshot, String, String) onDelete;

  static const Color _primary   = Color(0xFF3B5BDB);
  static const Color _cardBg    = Color(0xFFFFFFFF);
  static const Color _border    = Color(0xFFE8ECF0);
  static const Color _textMain  = Color(0xFF1E293B);
  static const Color _textSub   = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _errorText = Color(0xFFDC2626);
  static const Color _successText = Color(0xFF16A34A);
  static const Color _warnText  = Color(0xFFD97706);

  const _EventCard({
    required this.doc,
    required this.isFinished,
    required this.onEditFinished,
    required this.onShowRegistrants,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp).toDate();
    final isRegistration = data['type'] == 'registration';
    final collection = isRegistration ? 'events' : 'service_events';
    final eventType  = data['type'] ?? 'kebaktian';
    final title      = isRegistration ? (data['title'] ?? 'Registrasi') : (data['ministry'] ?? 'Kebaktian');
    final List assignments = data['assignments'] ?? [];
    final int capacity           = data['capacity'] ?? 0;
    final int currentRegistrants = data['currentRegistrants'] ?? 0;
    final Timestamp? deadline    = data['registrationDeadline'];
    final bool isPastDate        = date.isBefore(DateTime.now());

    // Color theme for the event type
    final Color typeColor  = isRegistration ? _successText : _primary;
    final Color typeBg     = isRegistration ? const Color(0xFFF0FDF4) : const Color(0xFFEFF3FF);
    final Color typeBorder = isRegistration ? const Color(0xFFBBF7D0) : const Color(0xFFC7D2FE);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isFinished ? _border : typeBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),

        // ── Date badge ──
        leading: Container(
          width: 48, height: 52,
          decoration: BoxDecoration(
            color: isFinished ? const Color(0xFFF1F5F9) : typeBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMM').format(date).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5,
                  color: isFinished ? _textMuted : typeColor,
                ),
              ),
              Text(
                DateFormat('dd').format(date),
                style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 20,
                  color: isFinished ? _textMuted : typeColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),

        // ── Title row ──
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isFinished ? const Color(0xFFF1F5F9) : typeBg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                isRegistration ? 'REG' : 'IBADAH',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4,
                  color: isFinished ? _textMuted : typeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: isFinished ? _textMuted : _textMain,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // ── Subtitle ──
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            isRegistration
                ? '$currentRegistrants/$capacity terdaftar'
                : '${assignments.length} petugas',
            style: const TextStyle(fontSize: 12, color: _textMuted),
          ),
        ),

        children: [
          const Divider(height: 1, color: _border),

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                _ActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isRegistration
                          ? CreateRegistrationScreen(existingEvent: doc)
                          : CreateServiceScreen(existingService: doc),
                    ),
                  ),
                ),
                _ActionChip(
                  icon: isRegistration ? Icons.people_outline : Icons.assignment_ind_outlined,
                  label: isRegistration ? 'Registran' : 'Petugas',
                  onTap: () {
                    if (isRegistration) {
                      onShowRegistrants(doc);
                    } else {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _AssignmentsSheet(assignments: assignments, title: title),
                      );
                    }
                  },
                ),
                if (!isRegistration && isFinished)
                  _ActionChip(
                    icon: Icons.bar_chart_outlined,
                    label: 'Edit Data',
                    onTap: () => onEditFinished(doc, collection),
                  ),
                _ActionChip(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus',
                  color: _errorText,
                  bg: const Color(0xFFFFF5F5),
                  border: const Color(0xFFFECACA),
                  onTap: () => onDelete(doc, eventType, collection),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: _border),

          // ── Detail section ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: isRegistration
                ? _RegistrationDetails(data: data, date: date, deadline: deadline,
                    capacity: capacity, currentRegistrants: currentRegistrants)
                : _ServiceDetails(assignments: assignments),
          ),

          // ── Offering/attendance summary (finished service only) ──
          if (!isRegistration && isFinished && (data['attendance_count'] != null || data['offering_amount'] != null))
            _FinishedServiceSummary(data: data),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Detail sub-widgets ───────────────────────────────────────────────────────

class _RegistrationDetails extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime date;
  final Timestamp? deadline;
  final int capacity, currentRegistrants;

  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _errorText = Color(0xFFDC2626);

  const _RegistrationDetails({
    required this.data, required this.date, required this.deadline,
    required this.capacity, required this.currentRegistrants,
  });

  @override
  Widget build(BuildContext context) {
    final deadlinePassed = deadline != null && deadline!.toDate().isBefore(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(icon: Icons.calendar_today_outlined, label: 'Tanggal',
            value: DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date)),
        if (deadline != null)
          _InfoRow(
            icon: Icons.timer_outlined, label: 'Deadline',
            value: DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(deadline!.toDate()) +
                (deadlinePassed ? '  (BERAKHIR)' : ''),
            valueColor: deadlinePassed ? _errorText : null,
          ),
        _InfoRow(icon: Icons.group_outlined, label: 'Kapasitas', value: '$capacity orang'),
        _InfoRow(icon: Icons.check_circle_outline, label: 'Terdaftar', value: '$currentRegistrants orang'),
        if (data['details'] != null && (data['details'] as String).isNotEmpty)
          _InfoRow(icon: Icons.description_outlined, label: 'Detail', value: data['details']),
      ],
    );
  }
}

class _ServiceDetails extends StatelessWidget {
  final List assignments;
  const _ServiceDetails({required this.assignments});

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return const Text('Belum ada petugas yang di-assign.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13));
    }
    return Column(
      children: assignments.map<Widget>((a) {
        final status = a['status'] ?? 'pending';
        final Color statusColor = status == 'accepted'
            ? const Color(0xFF16A34A)
            : (status == 'rejected' ? const Color(0xFFDC2626) : const Color(0xFFD97706));
        final IconData statusIcon = status == 'accepted'
            ? Icons.check_circle_outline
            : (status == 'rejected' ? Icons.cancel_outlined : Icons.pending_outlined);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8ECF0), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['volunteerName'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    Text('Tugas: ${a['role']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status == 'accepted' ? 'DITERIMA' : (status == 'rejected' ? 'DITOLAK' : 'MENUNGGU'),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 10),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FinishedServiceSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FinishedServiceSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8ECF0), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.people_outline,
              label: 'Kehadiran',
              value: '${data['attendance_count'] ?? 0} orang',
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE8ECF0)),
          Expanded(
            child: _SummaryItem(
              icon: Icons.volunteer_activism_outlined,
              label: 'Persembahan',
              value: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                  .format(data['offering_amount'] ?? 0),
            ),
          ),
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
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }
}

// ─── Assignments bottom sheet ─────────────────────────────────────────────────

class _AssignmentsSheet extends StatelessWidget {
  final List assignments;
  final String title;
  const _AssignmentsSheet({required this.assignments, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFE8ECF0), borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daftar Petugas',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                        Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      ],
                    )),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE8ECF0)),
              Expanded(
                child: assignments.isEmpty
                    ? const Center(child: Text('Belum ada petugas', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: assignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final a = assignments[i];
                          final status = a['status'] ?? 'pending';
                          final Color sc = status == 'accepted'
                              ? const Color(0xFF16A34A)
                              : (status == 'rejected' ? const Color(0xFFDC2626) : const Color(0xFFD97706));
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: const Color(0xFFE8ECF0), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(backgroundColor: sc.withOpacity(0.12), radius: 18,
                                    child: Text((a['volunteerName'] ?? 'U')[0].toUpperCase(),
                                        style: TextStyle(color: sc, fontWeight: FontWeight.w700))),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['volunteerName'] ?? 'Unknown',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                    Text('Tugas: ${a['role']}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  ],
                                )),
                                Text(status.toUpperCase(),
                                    style: TextStyle(color: sc, fontWeight: FontWeight.w700, fontSize: 11)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Misc shared widgets ──────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color bg;
  final Color border;

  const _ActionChip({
    required this.icon, required this.label, required this.onTap,
    this.color = const Color(0xFF3B5BDB),
    this.bg = const Color(0xFFEFF3FF),
    this.border = const Color(0xFFC7D2FE),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(7),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

class _CreateOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _CreateOptionTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF0), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ]),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  final String text;
  const _DialogSectionLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.7));
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? prefixText;
  const _DialogField({required this.controller, required this.label, this.keyboardType, this.prefixText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        prefixText: prefixText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B5BDB), width: 1.5),
        ),
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  final String name;
  const _ConfirmDeleteDialog({required this.name});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Hapus Registran',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
      content: Text('Hapus $name dari registrasi?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B)))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus'),
        ),
      ],
    );
  }
}