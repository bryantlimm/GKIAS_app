import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateServiceScreen extends StatefulWidget {
  final DocumentSnapshot? existingService;

  const CreateServiceScreen({super.key, this.existingService});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  // ── Brand colors ────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF3B5BDB);
  static const Color _bg        = Color(0xFFF0F4F8);
  static const Color _cardBg    = Color(0xFFFFFFFF);
  static const Color _border    = Color(0xFFE8ECF0);
  static const Color _textMain  = Color(0xFF1E293B);
  static const Color _textSub   = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _errorText = Color(0xFFDC2626);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedMinistry;
  bool _isSubmitting = false;
  List<Map<String, String>> _assignments = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingService != null) {
      final data = widget.existingService!.data() as Map<String, dynamic>;
      _selectedDate = (data['date'] as Timestamp).toDate();
      _selectedMinistry = data['ministry'];
      _descriptionController.text = data['description'] ?? '';
      if (data['assignments'] != null) {
        try {
          _assignments = (data['assignments'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map((e) => {
                    'role': e['role']?.toString() ?? '',
                    'volunteerId': e['volunteerId']?.toString() ?? '',
                    'volunteerName': e['volunteerName']?.toString() ?? '',
                    'status': e['status']?.toString() ?? 'pending',
                  })
              .toList();
        } catch (_) {
          _assignments = [];
        }
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _addAssignmentRow() {
    setState(() => _assignments
        .add({'role': '', 'volunteerId': '', 'volunteerName': '', 'status': 'pending'}));
  }

  void _showVolunteerSelector(int index) {
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
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.people_alt_outlined, color: _primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Pilih Pelayan",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', whereIn: ['volunteer', 'admin'])
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(color: _primary));
                        }
                        final volunteers = snapshot.data!.docs;
                        if (volunteers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                const Text("Belum ada pelayan terdaftar.",
                                    style: TextStyle(color: _textMuted)),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: volunteers.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 72, color: _border),
                          itemBuilder: (context, i) {
                            final v = volunteers[i];
                            final data = v.data() as Map<String, dynamic>;
                            final String name = data['name'] ?? 'No Name';
                            final List ministries = data['ministries'] ?? [];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: _primary.withOpacity(0.12),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: _primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _textMain)),
                              subtitle: Text(
                                ministries.isNotEmpty
                                    ? ministries.join(", ")
                                    : "Belum ada bidang",
                                style: const TextStyle(
                                    fontSize: 12, color: _textSub),
                              ),
                              onTap: () {
                                setState(() {
                                  _assignments[index]['volunteerId'] = v.id;
                                  _assignments[index]['volunteerName'] = name;
                                });
                                Navigator.pop(context);
                              },
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

  Future<void> _submitService() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack("Mohon pilih tanggal.");
      return;
    }
    if (_selectedMinistry == null) {
      _showSnack("Mohon pilih jenis kebaktian.");
      return;
    }
    for (int i = 0; i < _assignments.length; i++) {
      if (_assignments[i]['volunteerId']!.isEmpty) {
        _showSnack("Petugas #${i + 1} belum memilih nama orang.");
        return;
      }
      if (_assignments[i]['role']!.isEmpty) {
        _showSnack("Petugas #${i + 1} belum mengisi role.");
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final assignmentsWithStatus = _assignments.map((a) => <String, dynamic>{
            'role': a['role'] ?? '',
            'volunteerId': a['volunteerId'] ?? '',
            'volunteerName': a['volunteerName'] ?? '',
            'status': a['status'] ?? 'pending',
          }).toList();

      final acceptedVolunteerIds = assignmentsWithStatus
          .where((a) => (a['status'] as String?) == 'accepted')
          .map((a) => a['volunteerId'] as String)
          .toList();

      final serviceData = <String, dynamic>{
        'date': Timestamp.fromDate(_selectedDate!),
        'ministry': _selectedMinistry,
        'description': _descriptionController.text,
        'assignments': assignmentsWithStatus,
        'acceptedVolunteerIds': acceptedVolunteerIds,
      };

      if (widget.existingService == null) {
        serviceData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('service_events')
            .add(serviceData);
        if (mounted) _showSnack("Jadwal berhasil dibuat!", success: true);
      } else {
        serviceData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('service_events')
            .doc(widget.existingService!.id)
            .update(serviceData);
        if (mounted) _showSnack("Jadwal berhasil diperbarui!", success: true);
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
      backgroundColor: success ? const Color(0xFF16A34A) : _errorText,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingService != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          isEditing ? "Edit Jadwal Kebaktian" : "Buat Jadwal Kebaktian",
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
            // ── Date picker ────────────────────────────────────────────
            _sectionLabel("Tanggal Kebaktian"),
            const SizedBox(height: 6),
            _tappableField(
              onTap: _pickDate,
              icon: Icons.calendar_today_outlined,
              text: _selectedDate == null
                  ? "Pilih tanggal..."
                  : DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                      .format(_selectedDate!),
              placeholder: _selectedDate == null,
            ),
            const SizedBox(height: 20),

            // ── Ministry dropdown ──────────────────────────────────────
            _sectionLabel("Jenis Kebaktian"),
            const SizedBox(height: 6),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schedules')
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator(color: _primary);
                }
                final ministryDocs = snapshot.data!.docs;
                final ministryNames =
                    ministryDocs.map((doc) => doc['name'] as String).toList();
                if (_selectedMinistry != null &&
                    !ministryNames.contains(_selectedMinistry)) {
                  _selectedMinistry = null;
                }
                return _styledDropdown(
                  value: _selectedMinistry,
                  hint: "Pilih jenis kebaktian...",
                  items: ministryDocs.map((doc) {
                    final name = doc['name'] as String;
                    return DropdownMenuItem<String>(
                        value: name, child: Text(name));
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _selectedMinistry = val),
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Description ────────────────────────────────────────────
            _sectionLabel("Keterangan / Tema"),
            const SizedBox(height: 6),
            _styledTextField(
              controller: _descriptionController,
              hint: "Contoh: Tema Natal 2025",
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // ── Assignments ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel("Daftar Petugas"),
                GestureDetector(
                  onTap: _addAssignmentRow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 16, color: _primary),
                        SizedBox(width: 4),
                        Text(
                          "Tambah",
                          style: TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_assignments.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: const Center(
                  child: Text(
                    "Belum ada petugas ditambahkan.",
                    style: TextStyle(color: _textMuted, fontSize: 13),
                  ),
                ),
              ),

            ..._assignments.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, String> assignment = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Index bubble
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Role field
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: assignment['role'],
                        style: const TextStyle(
                            fontSize: 14, color: _textMain),
                        decoration: InputDecoration(
                          labelText: "Role",
                          labelStyle:
                              const TextStyle(fontSize: 12, color: _textSub),
                          hintText: "cth: WL",
                          hintStyle: const TextStyle(
                              fontSize: 12, color: _textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: _bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: _primary, width: 1.5),
                          ),
                        ),
                        onChanged: (val) =>
                            _assignments[index]['role'] = val,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Volunteer picker
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: () => _showVolunteerSelector(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  assignment['volunteerName']!.isEmpty
                                      ? "Pilih pelayan..."
                                      : assignment['volunteerName']!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: assignment['volunteerName']!.isEmpty
                                        ? _textMuted
                                        : _textMain,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: _textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFDC2626), size: 20),
                      onPressed: () =>
                          setState(() => _assignments.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 28),

            // ── Submit ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitService,
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
                        isEditing ? "Simpan Perubahan" : "Simpan Jadwal",
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: placeholder ? _textMuted : _primary),
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

  Widget _styledDropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
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
      ),
    );
  }
}