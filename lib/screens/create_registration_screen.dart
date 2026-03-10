import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateRegistrationScreen extends StatefulWidget {
  final DocumentSnapshot? existingEvent;

  const CreateRegistrationScreen({super.key, this.existingEvent});

  @override
  State<CreateRegistrationScreen> createState() => _CreateRegistrationScreenState();
}

class _CreateRegistrationScreenState extends State<CreateRegistrationScreen> {
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
      var data = widget.existingEvent!.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _detailsController.text = data['details'] ?? '';
      _capacityController.text = (data['capacity'] ?? 0).toString();
      _selectedDate = (data['date'] as Timestamp).toDate();
      if (data['registrationDeadline'] != null) {
        _deadlineDate = (data['registrationDeadline'] as Timestamp).toDate();
      }
    }
  }

  Future<void> _pickDate({bool isDeadline = false}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDeadline ? (_deadlineDate ?? DateTime.now()) : (_selectedDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon pilih tanggal event")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final eventData = {
        'type': 'registration',
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'details': _detailsController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate!),
        'registrationDeadline': _deadlineDate != null ? Timestamp.fromDate(_deadlineDate!) : null,
        'capacity': int.tryParse(_capacityController.text) ?? 0,
        'currentRegistrants': widget.existingEvent != null 
            ? (widget.existingEvent!.data() as Map)['currentRegistrants'] ?? 0 
            : 0,
        'is_finished': false,
      };

      if (widget.existingEvent == null) {
        // Create new
        eventData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('events').add(eventData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registrasi berhasil dibuat!")));
        }
      } else {
        // Update existing
        eventData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('events').doc(widget.existingEvent!.id).update(eventData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registrasi berhasil diperbarui!")));
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingEvent != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Registrasi" : "Buat Registrasi"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Nama Event *",
                border: OutlineInputBorder(),
                hintText: "Contoh: Retreat Pemuda 2026",
              ),
              validator: (val) => val == null || val.isEmpty ? "Wajib diisi" : null,
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              title: Text(_selectedDate == null
                  ? "Tanggal Event *"
                  : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate!)),
              trailing: const Icon(Icons.calendar_today),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _selectedDate == null ? Colors.red : Colors.grey),
              ),
              onTap: () => _pickDate(),
            ),
            const SizedBox(height: 16),

            // Registration Deadline
            ListTile(
              title: Text(_deadlineDate == null
                  ? "Deadline Registrasi (Opsional)"
                  : "Deadline: ${DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_deadlineDate!)}"),
              trailing: const Icon(Icons.timer),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.grey),
              ),
              onTap: () => _pickDate(isDeadline: true),
            ),
            if (_deadlineDate != null)
              TextButton.icon(
                onPressed: () => setState(() => _deadlineDate = null),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text("Hapus Deadline"),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            const SizedBox(height: 16),

            // Capacity
            TextFormField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Kapasitas (jumlah orang) *",
                border: OutlineInputBorder(),
                hintText: "Contoh: 50",
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return "Wajib diisi";
                if (int.tryParse(val) == null) return "Harus berupa angka";
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Short Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Deskripsi Singkat",
                border: OutlineInputBorder(),
                hintText: "Tampil di list event",
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Full Details
            TextFormField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: "Detail Lengkap",
                border: OutlineInputBorder(),
                hintText: "Informasi lengkap untuk peserta",
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isEditing ? "SIMPAN PERUBAHAN" : "BUAT REGISTRASI", 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}