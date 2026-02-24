import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateServiceScreen extends StatefulWidget {
  // NEW: Accept an optional existing service document
  final DocumentSnapshot? existingService;
  
  const CreateServiceScreen({super.key, this.existingService});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedMinistry; 
  bool _isSubmitting = false;

  List<Map<String, String>> _assignments = [];

  // NEW: Initialize the form with existing data if we are in "Edit Mode"
  @override
  void initState() {
    super.initState();
    if (widget.existingService != null) {
      var data = widget.existingService!.data() as Map<String, dynamic>;
      
      _selectedDate = (data['date'] as Timestamp).toDate();
      _selectedMinistry = data['ministry'];
      _descriptionController.text = data['description'] ?? '';
      
      // Load existing assignments safely
      if (data['assignments'] != null) {
        _assignments = List<Map<String, dynamic>>.from(data['assignments'])
            .map((e) => {
                  'role': e['role'].toString(),
                  'volunteerId': e['volunteerId'].toString(),
                  'volunteerName': e['volunteerName'].toString(),
                })
            .toList();
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow slight past dates for editing
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addAssignmentRow() {
    setState(() {
      _assignments.add({'role': '', 'volunteerId': '', 'volunteerName': ''});
    });
  }

  void _showVolunteerSelector(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Pilih Pelayan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', whereIn: ['volunteer', 'admin']) 
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      var volunteers = snapshot.data!.docs;
                      if (volunteers.isEmpty) return const Center(child: Text("Belum ada volunteer yang terdaftar."));

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: volunteers.length,
                        itemBuilder: (context, i) {
                          var v = volunteers[i];
                          var data = v.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(child: Text((data['name'] ?? 'U')[0])),
                            title: Text(data['name'] ?? 'No Name'),
                            subtitle: Text(data['ministries'] != null ? data['ministries'].join(", ") : "-"),
                            onTap: () {
                              setState(() {
                                _assignments[index]['volunteerId'] = v.id;
                                _assignments[index]['volunteerName'] = data['name'];
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
        );
      },
    );
  }

  Future<void> _submitService() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon pilih tanggal.")));
      return;
    }
    if (_selectedMinistry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon pilih jenis kebaktian.")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Prepare the data payload
      final serviceData = {
        'date': Timestamp.fromDate(_selectedDate!),
        'ministry': _selectedMinistry, 
        'description': _descriptionController.text,
        'assignments': _assignments, 
      };

      // NEW: Check if we are Updating or Creating
      if (widget.existingService == null) {
        // CREATE MODE
        serviceData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('service_events').add(serviceData);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jadwal berhasil dibuat!")));
      } else {
        // UPDATE MODE
        serviceData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('service_events').doc(widget.existingService!.id).update(serviceData);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jadwal berhasil diperbarui!")));
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
    // NEW: Dynamic UI text based on mode
    final isEditing = widget.existingService != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Edit Jadwal Kebaktian" : "Buat Jadwal Kebaktian")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: Text(_selectedDate == null 
                ? "Pilih Tanggal" 
                : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate!)),
              trailing: const Icon(Icons.calendar_today),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.grey)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('schedules').orderBy('order').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                // NEW: Ensure the loaded ministry actually exists in the dropdown options, otherwise reset to null
                final ministryDocs = snapshot.data!.docs;
                final ministryNames = ministryDocs.map((doc) => doc['name'] as String).toList();
                if (_selectedMinistry != null && !ministryNames.contains(_selectedMinistry)) {
                  _selectedMinistry = null;
                }

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Jenis Kebaktian"),
                  value: _selectedMinistry,
                  items: ministryDocs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc['name'],
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedMinistry = val),
                );
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Keterangan / Tema"),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Daftar Petugas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _addAssignmentRow, 
                  icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                  tooltip: "Tambah Petugas",
                ),
              ],
            ),
            
            ..._assignments.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, String> assignment = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: assignment['role'],
                          decoration: const InputDecoration(labelText: "Role (e.g. WL)", isDense: true),
                          onChanged: (val) => _assignments[index]['role'] = val,
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () => _showVolunteerSelector(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              assignment['volunteerName']!.isEmpty 
                                  ? "Pilih Orang..." 
                                  : assignment['volunteerName']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _assignments.removeAt(index)),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitService,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(isEditing ? "SIMPAN PERUBAHAN" : "SIMPAN JADWAL", style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}