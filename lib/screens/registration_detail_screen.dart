// registration_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class RegistrationDetailScreen extends StatefulWidget {
  final DocumentSnapshot event;

  const RegistrationDetailScreen({super.key, required this.event});

  @override
  State<RegistrationDetailScreen> createState() => _RegistrationDetailScreenState();
}

class _RegistrationDetailScreenState extends State<RegistrationDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _contactController     = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedImage;
  bool _isSubmitting = false;
  bool _isLoading    = true;
  List<DocumentSnapshot> _myRegistrations = [];

  // ── Brand colors ──────────────────────────────────────────────────────────
  static const Color _primary      = Color(0xFF3B5BDB);
  static const Color _bg           = Color(0xFFF0F4F8);
  static const Color _cardBg       = Color(0xFFFFFFFF);
  static const Color _border       = Color(0xFFE2E8F0);
  static const Color _textMain     = Color(0xFF1E293B);
  static const Color _textMuted    = Color(0xFF94A3B8);
  static const Color _textSub      = Color(0xFF64748B);
  static const Color _successBg    = Color(0xFFF0FDF4);
  static const Color _successBorder = Color(0xFFBBF7D0);
  static const Color _successText  = Color(0xFF16A34A);
  static const Color _errorBg      = Color(0xFFFFF5F5);
  static const Color _errorBorder  = Color(0xFFFECACA);
  static const Color _errorText    = Color(0xFFDC2626);
  static const Color _warnBg       = Color(0xFFFFFBEB);
  static const Color _warnBorder   = Color(0xFFFDE68A);
  static const Color _warnText     = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkExistingRegistrations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      setState(() => _nameController.text = data['name'] ?? '');
    }
  }

  Future<void> _checkExistingRegistrations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final regs = await FirebaseFirestore.instance
        .collection('registrations')
        .where('eventId', isEqualTo: widget.event.id)
        .where('registeredBy', isEqualTo: user.uid)
        .get();
    setState(() {
      _myRegistrations = regs.docs;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024,
    );
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  // ── Submit registration ───────────────────────────────────────────────────
  // Uses a Firestore transaction so the capacity check + write + increment
  // are atomic. This prevents race conditions where two users both pass the
  // capacity check simultaneously and exceed the quota.
  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventData = widget.event.data() as Map<String, dynamic>;

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: eventData['title'],
        date: (eventData['date'] as Timestamp).toDate(),
        name: _nameController.text,
        contact: _contactController.text,
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isSubmitting = true);

    try {
      // Upload image first (outside transaction — Storage isn't transactional)
      String? imageUrl;
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('registration_docs')
            .child('${widget.event.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Atomic transaction: re-read capacity, write registration, increment count
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final eventRef = widget.event.reference;
        final freshEvent = await transaction.get(eventRef);
        final fresh = freshEvent.data() as Map<String, dynamic>;

        final int capacity = fresh['capacity'] ?? 0;
        final int current  = fresh['currentRegistrants'] ?? 0;

        if (current >= capacity) {
          // Throw so the transaction aborts and we catch it below
          throw Exception('FULL');
        }

        final regRef = FirebaseFirestore.instance.collection('registrations').doc();

        transaction.set(regRef, {
          'eventId':      widget.event.id,
          'eventTitle':   fresh['title'],
          'registeredBy': user.uid,
          'userId':       user.uid,
          'name':         _nameController.text.trim(),
          'contact':      _contactController.text.trim(),
          'description':  _descriptionController.text.trim(),
          'documentUrl':  imageUrl,
          'registeredAt': FieldValue.serverTimestamp(),
        });

        // ← This is the line that was commented out before — now restored
        transaction.update(eventRef, {
          'currentRegistrants': FieldValue.increment(1),
        });
      });

      if (mounted) {
        _showToast('Registrasi berhasil!', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('FULL')
            ? 'Maaf, kuota registrasi sudah penuh.'
            : 'Gagal mendaftar. Silakan coba lagi.';
        _showToast(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Cancel registration ───────────────────────────────────────────────────
  Future<void> _cancelRegistration(DocumentSnapshot reg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Batalkan Registrasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
        content: const Text('Apakah Anda yakin ingin membatalkan registrasi ini?',
            style: TextStyle(fontSize: 14, color: _textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak', style: TextStyle(color: _textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorText, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final regData = reg.data() as Map<String, dynamic>;
      if (regData['documentUrl'] != null) {
        try {
          await FirebaseStorage.instance.refFromURL(regData['documentUrl']).delete();
        } catch (_) {}
      }
      await reg.reference.delete();
      await widget.event.reference.update({
        'currentRegistrants': FieldValue.increment(-1),
      });
      setState(() => _myRegistrations.removeWhere((r) => r.id == reg.id));
      if (mounted) _showToast('Registrasi dibatalkan.', isError: false);
    } catch (e) {
      if (mounted) _showToast('Gagal membatalkan.', isError: true);
    }
  }

  void _showToast(String message, {required bool isError}) {
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    final eventData  = widget.event.data() as Map<String, dynamic>;
    final eventDate  = (eventData['date'] as Timestamp).toDate();
    final deadline   = eventData['registrationDeadline'] != null
        ? (eventData['registrationDeadline'] as Timestamp).toDate()
        : null;
    final isDeadlinePassed = deadline != null && deadline.isBefore(DateTime.now());
    final isEventPassed    = eventDate.isBefore(DateTime.now());
    final int capacity     = eventData['capacity'] ?? 0;
    final int current      = eventData['currentRegistrants'] ?? 0;
    final bool isFull      = current >= capacity;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Detail Registrasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
        backgroundColor: _cardBg,
        foregroundColor: _textMain,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Event info card ─────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge row
                  Row(
                    children: [
                      _Badge(label: 'REGISTRASI', color: _primary),
                      const Spacer(),
                      _CapacityBadge(current: current, capacity: capacity, isFull: isFull),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(eventData['title'],
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _textMain)),
                  const SizedBox(height: 14),

                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Tanggal',
                    value: DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(eventDate),
                  ),
                  if (deadline != null)
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Deadline',
                      value: DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(deadline) +
                          (isDeadlinePassed ? '  (BERAKHIR)' : ''),
                      valueColor: isDeadlinePassed ? _errorText : null,
                    ),

                  if (eventData['details'] != null && (eventData['details'] as String).isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: _border),
                    ),
                    Text(eventData['details'],
                        style: const TextStyle(fontSize: 14, color: _textSub, height: 1.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── My existing registrations ───────────────────────────────
            if (_myRegistrations.isNotEmpty) ...[
              const _SectionLabel(text: 'Registrasi Anda'),
              const SizedBox(height: 10),
              ..._myRegistrations.map((reg) {
                final regData = reg.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _successBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _successBorder, width: 1.5),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: _successText,
                      radius: 18,
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ),
                    title: Text(regData['name'],
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _textMain)),
                    subtitle: Text('Kontak: ${regData['contact']}',
                        style: const TextStyle(fontSize: 12, color: _textSub)),
                    trailing: isEventPassed
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Selesai',
                                style: TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w600)),
                          )
                        : GestureDetector(
                            onTap: () => _cancelRegistration(reg),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _errorBg,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: _errorBorder, width: 1.5),
                              ),
                              child: const Text('Batalkan',
                                  style: TextStyle(fontSize: 12, color: _errorText, fontWeight: FontWeight.w700)),
                            ),
                          ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // ── Status messages (closed / full / passed) ────────────────
            if (isEventPassed)
              _StatusBanner(message: 'Event ini sudah berlalu.', color: _textMuted, bg: const Color(0xFFF1F5F9), border: _border)
            else if (isDeadlinePassed)
              _StatusBanner(message: 'Pendaftaran sudah ditutup.', color: _errorText, bg: _errorBg, border: _errorBorder)
            else if (isFull)
              _StatusBanner(message: 'Kuota sudah penuh.', color: _warnText, bg: _warnBg, border: _warnBorder),

            // ── Registration form ───────────────────────────────────────
            if (!isEventPassed && !isDeadlinePassed && !isFull) ...[
              const _SectionLabel(text: 'Form Pendaftaran'),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border, width: 1.5),
                ),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FormField(
                        controller: _nameController,
                        label: 'Nama Lengkap',
                        hint: 'Nama kamu',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      _FormField(
                        controller: _contactController,
                        label: 'Nomor Kontak (WA/HP)',
                        hint: 'Contoh: 08123456789',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),
                      _FormField(
                        controller: _descriptionController,
                        label: 'Keterangan Tambahan (Opsional)',
                        hint: 'Contoh: Mendaftar untuk adik saya',
                        icon: Icons.notes_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Image upload
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.upload_file_outlined, color: _textMuted, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _selectedImage != null ? 'Ganti Dokumen' : 'Upload Dokumen (Opsional)',
                                style: const TextStyle(color: _textSub, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_selectedImage != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _selectedImage = null),
                          icon: const Icon(Icons.clear, size: 15, color: _errorText),
                          label: const Text('Hapus Gambar', style: TextStyle(color: _errorText, fontSize: 13)),
                        ),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            disabledBackgroundColor: const Color(0xFF93A3C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text('Kirim Pendaftaran',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}

class _CapacityBadge extends StatelessWidget {
  final int current, capacity;
  final bool isFull;
  const _CapacityBadge({required this.current, required this.capacity, required this.isFull});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFull ? const Color(0xFFFFF5F5) : const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFull ? const Color(0xFFFECACA) : const Color(0xFFC7D2FE),
          width: 1.5,
        ),
      ),
      child: Text(
        isFull ? 'PENUH  $current/$capacity' : '$current / $capacity orang',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: isFull ? const Color(0xFFDC2626) : const Color(0xFF3B5BDB),
        ),
      ),
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
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.8),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color, bg, border;
  const _StatusBanner({required this.message, required this.color, required this.bg, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.7),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3B5BDB), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title, name, contact;
  final DateTime date;
  const _ConfirmDialog({required this.title, required this.date, required this.name, required this.contact});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Konfirmasi Pendaftaran',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfirmRow(label: 'Event', value: title),
          _ConfirmRow(
            label: 'Tanggal',
            value: DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date),
          ),
          _ConfirmRow(label: 'Nama', value: name),
          _ConfirmRow(label: 'Kontak', value: contact),
          const SizedBox(height: 6),
          const Text('Lanjutkan pendaftaran?',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B5BDB),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Daftar', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label, value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text('$label:', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }
}