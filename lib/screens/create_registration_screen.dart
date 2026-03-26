import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateRegistrationScreen extends StatefulWidget {
  final DocumentSnapshot? existingEvent;

  const CreateRegistrationScreen({super.key, this.existingEvent});

  @override
  State<CreateRegistrationScreen> createState() =>
      _CreateRegistrationScreenState();
}

class _CreateRegistrationScreenState extends State<CreateRegistrationScreen> {
  // ── Brand colors ────────────────────────────────────────────────────────
  static const Color _primary      = Color(0xFF3B5BDB);
  static const Color _bg           = Color(0xFFF0F4F8);
  static const Color _cardBg       = Color(0xFFFFFFFF);
  static const Color _border       = Color(0xFFE8ECF0);
  static const Color _textMain     = Color(0xFF1E293B);
  static const Color _textSub      = Color(0xFF64748B);
  static const Color _textMuted    = Color(0xFF94A3B8);
  static const Color _successColor = Color(0xFF16A34A);
  static const Color _errorText    = Color(0xFFDC2626);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  DateTime? _selectedDate;
  DateTime? _deadlineDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingEvent != null) {
      final data = widget.existingEvent!.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _detailsController.text = data['details'] ?? '';
      _capacityController.text = (data['capacity'] ?? 0).toString();
      _selectedDate = (data['date'] as Timestamp).toDate();
      if (data['registrationDeadline'] != null) {
        _deadlineDate =
            (data['registrationDeadline'] as Timestamp).toDate();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _detailsController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({bool isDeadline = false}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDeadline
          ? (_deadlineDate ?? DateTime.now())
          : (_selectedDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isDeadline) {
          _deadlineDate = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack("Mohon pilih tanggal event.");
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final eventData = <String, dynamic>{
        'type': 'registration',
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'details': _detailsController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate!),
        'registrationDeadline': _deadlineDate != null
            ? Timestamp.fromDate(_deadlineDate!)
            : null,
        'capacity': int.tryParse(_capacityController.text) ?? 0,
        'currentRegistrants': widget.existingEvent != null
            ? (widget.existingEvent!.data() as Map)['currentRegistrants'] ?? 0
            : 0,
        'is_finished': false,
      };

      if (widget.existingEvent == null) {
        eventData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('events').add(eventData);
        if (mounted) _showSnack("Registrasi berhasil dibuat!", success: true);
      } else {
        eventData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.existingEvent!.id)
            .update(eventData);
        if (mounted)
          _showSnack("Registrasi berhasil diperbarui!", success: true);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? _successColor : _errorText,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingEvent != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Registrasi" : "Buat Registrasi",
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _textMain,
          ),
        ),
        backgroundColor: _cardBg,
        foregroundColor: _textMain,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Title ──────────────────────────────────────────────────
            _sectionLabel("Nama Event"),
            const SizedBox(height: 6),
            _styledTextField(
              controller: _titleController,
              hint: "Contoh: Retreat Pemuda 2026",
              validator: (val) =>
                  val == null || val.isEmpty ? "Wajib diisi" : null,
            ),
            const SizedBox(height: 20),

            // ── Event date ─────────────────────────────────────────────
            _sectionLabel("Tanggal Event"),
            const SizedBox(height: 6),
            _tappableField(
              onTap: () => _pickDate(),
              icon: Icons.calendar_today_outlined,
              text: _selectedDate == null
                  ? "Pilih tanggal event..."
                  : DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                      .format(_selectedDate!),
              placeholder: _selectedDate == null,
              hasError: _selectedDate == null,
            ),
            const SizedBox(height: 20),

            // ── Deadline ───────────────────────────────────────────────
            _sectionLabel("Deadline Registrasi"),
            const SizedBox(height: 6),
            _tappableField(
              onTap: () => _pickDate(isDeadline: true),
              icon: Icons.timer_outlined,
              text: _deadlineDate == null
                  ? "Opsional — pilih deadline..."
                  : DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                      .format(_deadlineDate!),
              placeholder: _deadlineDate == null,
            ),
            if (_deadlineDate != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => setState(() => _deadlineDate = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _errorText.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear, size: 13, color: _errorText),
                        SizedBox(width: 4),
                        Text(
                          "Hapus deadline",
                          style: TextStyle(
                            fontSize: 12,
                            color: _errorText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Capacity ───────────────────────────────────────────────
            _sectionLabel("Kapasitas"),
            const SizedBox(height: 6),
            _styledTextField(
              controller: _capacityController,
              hint: "Contoh: 50",
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return "Wajib diisi";
                if (int.tryParse(val) == null) return "Harus berupa angka";
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Short description ──────────────────────────────────────
            _sectionLabel("Deskripsi Singkat"),
            const SizedBox(height: 6),
            _styledTextField(
              controller: _descriptionController,
              hint: "Tampil di list event",
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ── Full details ───────────────────────────────────────────
            _sectionLabel("Detail Lengkap"),
            const SizedBox(height: 6),
            _styledTextField(
              controller: _detailsController,
              hint: "Informasi lengkap untuk peserta",
              maxLines: 5,
            ),
            const SizedBox(height: 28),

            // ── Submit ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        isEditing ? "Simpan Perubahan" : "Buat Registrasi",
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textSub,
          letterSpacing: 0.3,
        ),
      );

  Widget _tappableField({
    required VoidCallback onTap,
    required IconData icon,
    required String text,
    bool placeholder = false,
    bool hasError = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasError ? _errorText.withOpacity(0.5) : _border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: placeholder ? _textMuted : _primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: placeholder ? _textMuted : _textMain,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _textMuted),
          ],
        ),
      ),
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _textMain),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
        filled: true,
        fillColor: _cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _errorText),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _errorText, width: 1.5),
        ),
      ),
    );
  }
}