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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  File? _selectedImage;
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<DocumentSnapshot> _myRegistrations = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkExistingRegistrations();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
        });
      }
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check capacity
    var eventData = widget.event.data() as Map<String, dynamic>;
    int capacity = eventData['capacity'] ?? 0;
    int current = eventData['currentRegistrants'] ?? 0;

    if (current >= capacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maaf, kuota registrasi sudah penuh"), backgroundColor: Colors.red),
      );
      return;
    }

    // Show confirmation
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Konfirmasi Registrasi"),
            content: Text(
              "Anda akan mendaftar untuk:\n\n"
              "${eventData['title']}\n"
              "Tanggal: ${DateFormat('EEEE, d MMMM yyyy', 'id_ID').format((eventData['date'] as Timestamp).toDate())}\n\n"
              "Nama: ${_nameController.text}\n"
              "Kontak: ${_contactController.text}\n\n"
              "Lanjutkan?",
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Daftar")),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;
      
      // Upload image if selected
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('registration_docs')
            .child('${widget.event.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      // Create registration
      await FirebaseFirestore.instance.collection('registrations').add({
        'eventId': widget.event.id,
        'eventTitle': eventData['title'],
        'registeredBy': user.uid,
        'userId': user.uid,
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'description': _descriptionController.text.trim(),
        'documentUrl': imageUrl,
        'registeredAt': FieldValue.serverTimestamp(),
      });

      // Update event count
      // await widget.event.reference.update({
      //   'currentRegistrants': FieldValue.increment(1),
      // });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registrasi berhasil!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Return true to refresh
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancelRegistration(DocumentSnapshot reg) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Batalkan Registrasi"),
            content: const Text("Apakah Anda yakin ingin membatalkan registrasi ini?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Tidak")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Ya, Batalkan"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      // Delete document from storage if exists
      var regData = reg.data() as Map<String, dynamic>;
      if (regData['documentUrl'] != null) {
        try {
          await FirebaseStorage.instance.refFromURL(regData['documentUrl']).delete();
        } catch (e) {
          // Ignore if already deleted
        }
      }

      await reg.reference.delete();
      
      // Decrement count
      await widget.event.reference.update({
        'currentRegistrants': FieldValue.increment(-1),
      });

      setState(() {
        _myRegistrations.removeWhere((r) => r.id == reg.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registrasi dibatalkan")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    var eventData = widget.event.data() as Map<String, dynamic>;
    DateTime eventDate = (eventData['date'] as Timestamp).toDate();
    DateTime? deadline = eventData['registrationDeadline'] != null 
        ? (eventData['registrationDeadline'] as Timestamp).toDate() 
        : null;
    bool isDeadlinePassed = deadline != null && deadline.isBefore(DateTime.now());
    bool isEventPassed = eventDate.isBefore(DateTime.now());
    int capacity = eventData['capacity'] ?? 0;
    int current = eventData['currentRegistrants'] ?? 0;
    bool isFull = current >= capacity;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Registrasi"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Info Card
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "REGISTRASI",
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      eventData['title'],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.calendar_today, "Tanggal", 
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(eventDate)),
                    if (deadline != null)
                      _buildInfoRow(Icons.timer, "Deadline", 
                        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(deadline) +
                        (isDeadlinePassed ? " (BERAKHIR)" : ""),
                        isDeadlinePassed ? Colors.red : null),
                    // _buildInfoRow(Icons.group, "Kapasitas", "$current / $capacity orang"), // bikin error pusing guweh
                    if (isFull)
                      const Text(
                        "KUOTA PENUH",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    const Divider(height: 24),
                    if (eventData['details'] != null && eventData['details'].isNotEmpty)
                      Text(eventData['details']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // My Existing Registrations
            if (_myRegistrations.isNotEmpty) ...[
              const Text(
                "Registrasi Anda:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._myRegistrations.map((reg) {
                var regData = reg.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(regData['name']),
                    subtitle: Text("Kontak: ${regData['contact']}"),
                    trailing: isEventPassed
                        ? const Text("Selesai", style: TextStyle(color: Colors.grey))
                        : TextButton.icon(
                            onPressed: () => _cancelRegistration(reg),
                            icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                            label: const Text("Batal", style: TextStyle(color: Colors.red)),
                          ),
                  ),
                );
              }).toList(),
              const Divider(height: 32),
            ],

            // Registration Form (if not passed deadline and not full)
            if (!isEventPassed && !isDeadlinePassed && !isFull) ...[
              const Text(
                "Form Registrasi:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Nama Lengkap *",
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: "Nomor Kontak (WA/HP) *",
                        border: OutlineInputBorder(),
                        hintText: "Contoh: 08123456789",
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) => val == null || val.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: "Keterangan Tambahan (Opsional)",
                        border: OutlineInputBorder(),
                        hintText: "Contoh: Mendaftar untuk adik saya",
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Document Upload
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_selectedImage != null ? "Ganti Dokumen" : "Upload Dokumen (Opsional)"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _selectedImage = null),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text("Hapus Gambar"),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("KIRIM REGISTRASI", style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isEventPassed) ...[
              const Center(
                child: Text(
                  "Event sudah berlalu",
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ] else if (isDeadlinePassed) ...[
              const Center(
                child: Text(
                  "Registrasi sudah ditutup",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ] else if (isFull) ...[
              const Center(
                child: Text(
                  "Kuota sudah penuh",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}