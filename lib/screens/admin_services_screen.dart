import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'create_service_screen.dart';

class AdminServicesScreen extends StatelessWidget {
  const AdminServicesScreen({super.key});

  // --- FUNCTION: ADMIN EDIT FINISHED SERVICE ---
  Future<void> _editFinishedService(BuildContext context, DocumentSnapshot doc) async {
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
              Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              // Update the document with new data
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Jadwal Kebaktian"),
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateServiceScreen()),
            );
          },
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<QuerySnapshot>(
          // Fetch ALL descending so we get a single source of truth
          stream: FirebaseFirestore.instance
              .collection('service_events')
              .orderBy('date', descending: true) 
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text("Gagal memuat data."));
            
            var allDocs = snapshot.data!.docs;

            // Split and Sort the data in memory
            var upcomingDocs = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['is_finished'] != true).toList();
            // Sort upcoming ascending (nearest events first)
            upcomingDocs.sort((a, b) => (a.data() as Map)['date'].compareTo((b.data() as Map)['date']));

            var finishedDocs = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['is_finished'] == true).toList();
            // Finished is already sorted descending (newest finished first) by the stream!

            return TabBarView(
              children: [
                // ================= TAB 1: UPCOMING =================
                upcomingDocs.isEmpty 
                  ? const Center(child: Text("Belum ada jadwal ibadah mendatang."))
                  : ListView.builder(
                      itemCount: upcomingDocs.length,
                      itemBuilder: (context, index) {
                        var doc = upcomingDocs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        DateTime date = (data['date'] as Timestamp).toDate();
                        List assignments = data['assignments'] ?? [];

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(DateFormat('MMM').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                                  Text(DateFormat('dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                                ],
                              ),
                            ),
                            title: Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${assignments.length} Petugas • ${data['description'] ?? ''}"),
                            trailing: const Icon(Icons.edit, color: Colors.blueGrey),
                            onTap: () {
                              // Open Edit Mode
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CreateServiceScreen(existingService: doc)),
                              );
                            },
                          ),
                        );
                      },
                    ),

                // ================= TAB 2: FINISHED =================
                finishedDocs.isEmpty 
                  ? const Center(child: Text("Belum ada riwayat ibadah selesai."))
                  : ListView.builder(
                      itemCount: finishedDocs.length,
                      itemBuilder: (context, index) {
                        var doc = finishedDocs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        DateTime date = (data['date'] as Timestamp).toDate();

                        return Card(
                          color: Colors.grey[50],
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(DateFormat('MMM').format(date), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[800])),
                                  Text(DateFormat('dd').format(date), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey[800])),
                                ],
                              ),
                            ),
                            title: Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Kehadiran: ${data['attendance_count'] ?? 0} jiwa"),
                                Text("Persembahan: Rp ${NumberFormat('#,###', 'id_ID').format(data['offering_amount'] ?? 0)}"),
                              ],
                            ),
                            trailing: const Icon(Icons.fact_check, color: Colors.green),
                            onTap: () => _editFinishedService(context, doc), // Open Admin Edit Popup
                          ),
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