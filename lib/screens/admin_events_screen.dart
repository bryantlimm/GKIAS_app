import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'create_service_screen.dart';
import 'create_registration_screen.dart';

class AdminEventsScreen extends StatelessWidget {
  const AdminEventsScreen({super.key});

  Future<void> _editFinishedService(BuildContext context, DocumentSnapshot doc, String collection) async {
    var data = doc.data() as Map<String, dynamic>;

    TextEditingController attCountCtrl = TextEditingController(text: data['attendance_count']?.toString() ?? '0');
    TextEditingController attNotesCtrl = TextEditingController(text: data['attendance_notes'] ?? '');
    TextEditingController offAmountCtrl = TextEditingController(text: data['offering_amount']?.toString() ?? '0');
    TextEditingController offNotesCtrl = TextEditingController(text: data['offering_notes'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Detail & Edit Ibadah", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['title'] ?? data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(DateFormat('EEEE, d MMM yyyy').format((data['date'] as Timestamp).toDate()), style: const TextStyle(color: Colors.grey)),
              const Divider(height: 24),

              const Text("Kehadiran", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              TextField(
                controller: attCountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Jumlah Kehadiran", border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: attNotesCtrl,
                decoration: const InputDecoration(labelText: "Catatan Kehadiran", border: OutlineInputBorder(), isDense: true),
              ),

              const SizedBox(height: 16),
              const Text("Persembahan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              TextField(
                controller: offAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Total Persembahan (Rp)", border: OutlineInputBorder(), prefixText: "Rp ", isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: offNotesCtrl,
                decoration: const InputDecoration(labelText: "Catatan Persembahan", border: OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              await doc.reference.update({
                'attendance_count': int.tryParse(attCountCtrl.text) ?? 0,
                'attendance_notes': attNotesCtrl.text,
                'offering_amount': int.tryParse(offAmountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                'offering_notes': offNotesCtrl.text,
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data berhasil diperbarui!")));
              }
            },
            child: const Text("Simpan Perubahan"),
          ),
        ],
      ),
    );
  }

  void _showRegistrants(BuildContext context, DocumentSnapshot eventDoc) {
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Daftar Registran",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "${eventDoc['title']}",
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('registrations')
                        .where('eventId', isEqualTo: eventDoc.id)
                        .orderBy('registeredAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("Belum ada registran."));
                      }

                      var registrants = snapshot.data!.docs;

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: registrants.length,
                        itemBuilder: (context, index) {
                          var reg = registrants[index];
                          var regData = reg.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text((regData['name'] ?? 'U')[0].toUpperCase()),
                              ),
                              title: Text(regData['name'] ?? 'Unknown'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Kontak: ${regData['contact'] ?? '-'}"),
                                  if (regData['description'] != null && regData['description'].isNotEmpty)
                                    Text("Keterangan: ${regData['description']}"),
                                  Text(
                                    "Waktu: ${DateFormat('dd MMM yyyy, HH:mm').format((regData['registeredAt'] as Timestamp).toDate())}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  bool confirm = await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Hapus Registran"),
                                          content: Text("Hapus ${regData['name']} dari registrasi?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text("Hapus"),
                                            ),
                                          ],
                                        ),
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
                              onTap: () {
                                if (regData['documentUrl'] != null) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Dokumen Registran"),
                                      content: Image.network(regData['documentUrl']),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Tutup"),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
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
        );
      },
    );
  }

  Future<void> _deleteEvent(BuildContext context, DocumentSnapshot doc, String eventType, String collection) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Hapus Event"),
            content: Text("Apakah Anda yakin ingin menghapus ${eventType == 'kebaktian' ? 'kebaktian' : 'registrasi'} ini?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Hapus"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      if (eventType == 'registration') {
        var registrations = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: doc.id)
            .get();
        for (var reg in registrations.docs) {
          await reg.reference.delete();
        }
      }

      await doc.reference.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event berhasil dihapus")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e")));
      }
    }
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Buat Event Baru",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.church, color: Colors.white),
                  ),
                  title: const Text("Kebaktian"),
                  subtitle: const Text("Jadwal ibadah dengan petugas"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateServiceScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.app_registration, color: Colors.white),
                  ),
                  title: const Text("Registrasi"),
                  subtitle: const Text("Form pendaftaran untuk acara"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateRegistrationScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Events"),
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: Colors.black,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Akan Datang"),
              Tab(text: "Selesai"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateOptions(context),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder(
          // Query BOTH collections
          stream: FirebaseFirestore.instance
              .collection('events')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, eventsSnapshot) {
            return StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('service_events')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, serviceEventsSnapshot) {
                if (eventsSnapshot.connectionState == ConnectionState.waiting ||
                    serviceEventsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Merge both collections
                List<DocumentSnapshot> allDocs = [];

                // Add registrasi events (from events collection, type=registration)
                if (eventsSnapshot.hasData) {
                  allDocs.addAll(eventsSnapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return data['type'] == 'registration';
                  }));
                }

                // Add kebaktian events (from service_events collection)
                if (serviceEventsSnapshot.hasData) {
                  allDocs.addAll(serviceEventsSnapshot.data!.docs.map((doc) {
                    // Mark these as kebaktian type
                    return doc;
                  }));
                }

                // Sort by date
                allDocs.sort((a, b) {
                  DateTime dateA = ((a.data() as Map)['date'] as Timestamp).toDate();
                  DateTime dateB = ((b.data() as Map)['date'] as Timestamp).toDate();
                  return dateB.compareTo(dateA); // Descending
                });

                var now = DateTime.now();
                var upcomingDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  DateTime eventDate = (data['date'] as Timestamp).toDate();
                  bool isFinished = data['is_finished'] ?? false;
                  return !isFinished && eventDate.isAfter(now.subtract(const Duration(days: 1)));
                }).toList();
                upcomingDocs.sort((a, b) {
                  DateTime dateA = ((a.data() as Map)['date'] as Timestamp).toDate();
                  DateTime dateB = ((b.data() as Map)['date'] as Timestamp).toDate();
                  return dateA.compareTo(dateB); // Ascending for upcoming
                });

                var finishedDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  bool isFinished = data['is_finished'] ?? false;
                  return isFinished;
                }).toList();

                return TabBarView(
                  children: [
                    // TAB 1: UPCOMING
                    upcomingDocs.isEmpty
                        ? const Center(child: Text("Belum ada event mendatang."))
                        : ListView.builder(
                            itemCount: upcomingDocs.length,
                            itemBuilder: (context, index) {
                              return _buildEventCard(context, upcomingDocs[index], false);
                            },
                          ),

                    // TAB 2: FINISHED
                    finishedDocs.isEmpty
                        ? const Center(child: Text("Belum ada riwayat event selesai."))
                        : ListView.builder(
                            itemCount: finishedDocs.length,
                            itemBuilder: (context, index) {
                              return _buildEventCard(context, finishedDocs[index], true);
                            },
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

  Widget _buildEventCard(BuildContext context, DocumentSnapshot doc, bool isFinished) {
    var data = doc.data() as Map<String, dynamic>;
    DateTime date = (data['date'] as Timestamp).toDate();
    
    // Determine if this is from events (registrasi) or service_events (kebaktian)
    String collection = data.containsKey('type') && data['type'] == 'registration' ? 'events' : 'service_events';
    String eventType = data['type'] ?? 'kebaktian';
    bool isRegistration = eventType == 'registration';
    
    String title = isRegistration ? (data['title'] ?? 'Registrasi') : (data['ministry'] ?? 'Kebaktian');
    List assignments = data['assignments'] ?? [];
    int capacity = data['capacity'] ?? 0;
    int currentRegistrants = data['currentRegistrants'] ?? 0;
    Timestamp? deadline = data['registrationDeadline'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isFinished ? Colors.grey[50] : null,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isFinished 
                ? (isRegistration ? Colors.green[100] : Colors.grey[300])
                : (isRegistration ? Colors.green[50] : Colors.blue[50]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(DateFormat('MMM').format(date), 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, 
                  color: isFinished 
                      ? (isRegistration ? Colors.green[800] : Colors.grey[800])
                      : (isRegistration ? Colors.green : Colors.blue))),
              Text(DateFormat('dd').format(date), 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, 
                  color: isFinished 
                      ? (isRegistration ? Colors.green[800] : Colors.grey[800])
                      : (isRegistration ? Colors.green : Colors.blue))),
            ],
          ),
        ),
        title: Row(
          children: [
            if (isRegistration)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "REGISTRASI",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isFinished ? Colors.grey : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: isRegistration
            ? Text("$currentRegistrants/$capacity terdaftar • ${data['description'] ?? ''}")
            : Text("${assignments.length} Petugas • ${data['description'] ?? ''}"),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (isRegistration) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CreateRegistrationScreen(existingEvent: doc)),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CreateServiceScreen(existingService: doc)),
                      );
                    }
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit"),
                ),
                const SizedBox(width: 8),
                if (isRegistration)
                  TextButton.icon(
                    onPressed: () => _showRegistrants(context, doc),
                    icon: const Icon(Icons.people, size: 18),
                    label: const Text("Lihat Registran"),
                  )
                else
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => _buildAssignmentsSheet(assignments, title),
                      );
                    },
                    icon: const Icon(Icons.people, size: 18),
                    label: const Text("Lihat Petugas"),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteEvent(context, doc, eventType, collection),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text("Hapus", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRegistration) ...[
                  _buildInfoRow(Icons.event, "Tanggal", DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date)),
                  if (deadline != null)
                    _buildInfoRow(
                      Icons.timer,
                      "Deadline",
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(deadline.toDate()) +
                          (deadline.toDate().isBefore(DateTime.now()) ? " (BERAKHIR)" : ""),
                      deadline.toDate().isBefore(DateTime.now()) ? Colors.red : null,
                    ),
                  _buildInfoRow(Icons.group, "Kapasitas", "$capacity orang"),
                  _buildInfoRow(Icons.check_circle, "Terdaftar", "$currentRegistrants orang"),
                  if (data['details'] != null && data['details'].isNotEmpty)
                    _buildInfoRow(Icons.description, "Detail", data['details']),
                ] else ...[
                  if (assignments.isEmpty)
                    const Text("Belum ada petugas yang di-assign.", 
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                  else
                    ...assignments.map<Widget>((a) {
                      String status = a['status'] ?? 'pending';
                      Color statusColor = status == 'accepted' 
                          ? Colors.green 
                          : (status == 'rejected' ? Colors.red : Colors.orange);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(
                            status == 'accepted' ? Icons.check_circle 
                            : (status == 'rejected' ? Icons.cancel : Icons.pending),
                            size: 16, 
                            color: statusColor
                          ),
                        ),
                        title: Text(a['volunteerName'] ?? 'Unknown', style: const TextStyle(fontSize: 14)),
                        subtitle: Text("Tugas: ${a['role']}", style: const TextStyle(fontSize: 12)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status == 'accepted' ? 'DITERIMA' : (status == 'rejected' ? 'DITOLAK' : 'MENUNGGU'),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsSheet(List assignments, String title) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Petugas: $title",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: assignments.isEmpty
                  ? const Center(child: Text("Belum ada petugas"))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: assignments.length,
                      itemBuilder: (context, index) {
                        var a = assignments[index];
                        String status = a['status'] ?? 'pending';
                        Color statusColor = status == 'accepted' 
                            ? Colors.green 
                            : (status == 'rejected' ? Colors.red : Colors.orange);
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(
                              status == 'accepted' ? Icons.check_circle 
                              : (status == 'rejected' ? Icons.cancel : Icons.pending),
                              color: statusColor,
                            ),
                          ),
                          title: Text(a['volunteerName'] ?? 'Unknown'),
                          subtitle: Text("Tugas: ${a['role']}"),
                          trailing: Text(
                            status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}