import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StaffVolunteerScreen extends StatelessWidget {
  const StaffVolunteerScreen({super.key});

  // --- 1. FUNCTION: CANCEL SERVICE ---
  Future<void> _cancelService(BuildContext context, String eventId, List currentAssignments, int myIndex) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Batalkan Pelayanan?"),
        content: const Text("Apakah Anda yakin ingin membatalkan jadwal pelayanan ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Tidak", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Batalkan"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && context.mounted) {
      List updatedAssignments = List.from(currentAssignments);
      updatedAssignments[myIndex]['status'] = 'cancelled';
      await FirebaseFirestore.instance.collection('service_events').doc(eventId).update({
        'assignments': updatedAssignments,
      });
    }
  }

  // --- 2. FUNCTION: UPDATE ATTENDANCE ---
  Future<void> _showAttendanceDialog(BuildContext context, String docId, Map<String, dynamic> currentData) async {
    TextEditingController countCtrl = TextEditingController(text: currentData['attendance_count']?.toString() ?? '');
    TextEditingController notesCtrl = TextEditingController(text: currentData['attendance_notes'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Input Kehadiran"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Jumlah Kehadiran", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Keterangan (Opsional)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('service_events').doc(docId).update({
                'attendance_count': int.tryParse(countCtrl.text) ?? 0,
                'attendance_notes': notesCtrl.text,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- 3. FUNCTION: UPDATE OFFERING ---
  Future<void> _showOfferingDialog(BuildContext context, String docId, Map<String, dynamic> currentData) async {
    TextEditingController amountCtrl = TextEditingController(text: currentData['offering_amount']?.toString() ?? '');
    TextEditingController notesCtrl = TextEditingController(text: currentData['offering_notes'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Input Persembahan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Persembahan (Rp)", border: OutlineInputBorder(), prefixText: "Rp "),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Keterangan (Opsional)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('service_events').doc(docId).update({
                'offering_amount': int.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                'offering_notes': notesCtrl.text,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- 4. FUNCTION: MARK AS FINISHED ---
  Future<void> _finishService(BuildContext context, String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Selesaikan Ibadah?"),
        content: const Text("Data kehadiran dan persembahan akan dikunci dan ibadah dipindahkan ke riwayat Selesai."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Selesai"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('service_events').doc(docId).update({
        'is_finished': true,
      });
    }
  }

  // --- 5. NEW FUNCTION: SHOW FINISHED DETAILS ---
  void _showFinishedDetailsDialog(BuildContext context, Map<String, dynamic> data, DateTime date) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Detail Ibadah Selesai", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date), style: const TextStyle(color: Colors.blue)),
                const Divider(height: 24),
                
                // Kehadiran Section
                Row(
                  children: [
                    const Icon(Icons.people, size: 20, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    const Text("Kehadiran:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Text("${data['attendance_count'] ?? 0} jiwa", style: const TextStyle(fontSize: 16)),
                if (data['attendance_notes'] != null && data['attendance_notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text("Catatan: ${data['attendance_notes']}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ),
                
                const SizedBox(height: 20),
                
                // Persembahan Section
                Row(
                  children: [
                    const Icon(Icons.monetization_on, size: 20, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    const Text("Persembahan:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Rp ${NumberFormat('#,###', 'id_ID').format(data['offering_amount'] ?? 0)}", style: const TextStyle(fontSize: 16)),
                if (data['offering_notes'] != null && data['offering_notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text("Catatan: ${data['offering_notes']}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Silakan login.")));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Jadwal Pelayanan Saya"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [Tab(text: "Akan Datang"), Tab(text: "Selesai")],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('service_events').orderBy('date', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            var allDocs = snapshot.data?.docs ?? [];
            
            var myServices = allDocs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              List assignments = data['assignments'] ?? [];
              return assignments.any((a) => a['volunteerId'] == currentUser.uid && a['status'] == 'accepted');
            }).toList();

            var upcomingServices = myServices.where((doc) => (doc.data() as Map<String, dynamic>)['is_finished'] != true).toList();
            upcomingServices.sort((a, b) => (a.data() as Map)['date'].compareTo((b.data() as Map)['date'])); 
            
            var finishedServices = myServices.where((doc) => (doc.data() as Map<String, dynamic>)['is_finished'] == true).toList();

            return TabBarView(
              children: [
                // ================= TAB 1: UPCOMING =================
                upcomingServices.isEmpty
                    ? const Center(child: Text("Belum ada jadwal pelayanan yang akan datang."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: upcomingServices.length,
                        itemBuilder: (context, index) {
                          var doc = upcomingServices[index];
                          var data = doc.data() as Map<String, dynamic>;
                          DateTime date = (data['date'] as Timestamp).toDate();
                          List assignments = data['assignments'] ?? [];
                          int myIndex = assignments.indexWhere((a) => a['volunteerId'] == currentUser.uid && a['status'] == 'accepted');
                          
                          bool hasAttendance = data.containsKey('attendance_count');
                          bool hasOffering = data.containsKey('offering_amount');

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text("Tugas: ${assignments[myIndex]['role']}", style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text("Waktu: ${DateFormat('HH:mm').format(date)} WIB"),
                                  const Divider(height: 24),
                                  
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: Icon(hasAttendance ? Icons.check_circle : Icons.people, size: 18, color: hasAttendance ? Colors.green : Colors.blue),
                                        label: Text(hasAttendance ? "Kehadiran: ${data['attendance_count']}" : "+ Kehadiran"),
                                        onPressed: () => _showAttendanceDialog(context, doc.id, data),
                                      ),
                                      OutlinedButton.icon(
                                        icon: Icon(hasOffering ? Icons.check_circle : Icons.monetization_on, size: 18, color: hasOffering ? Colors.green : Colors.blue),
                                        label: Text(hasOffering ? "Persembahan: Diisi" : "+ Persembahan"),
                                        onPressed: () => _showOfferingDialog(context, doc.id, data),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                        icon: const Icon(Icons.done_all, size: 18),
                                        label: const Text("Ibadah Selesai"),
                                        onPressed: () => _finishService(context, doc.id),
                                      ),
                                    ],
                                  ),
                                  
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _cancelService(context, doc.id, assignments, myIndex),
                                      child: const Text("Batalkan Jadwal", style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // ================= TAB 2: FINISHED =================
                finishedServices.isEmpty
                    ? const Center(child: Text("Belum ada riwayat pelayanan yang selesai."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: finishedServices.length,
                        itemBuilder: (context, index) {
                          var doc = finishedServices[index];
                          var data = doc.data() as Map<String, dynamic>;
                          DateTime date = (data['date'] as Timestamp).toDate();

                          return Card(
                            elevation: 1,
                            color: Colors.grey[50],
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            // NEW: Wrap the contents in an InkWell to make it clickable
                            child: InkWell(
                              onTap: () => _showFinishedDetailsDialog(context, data, date),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(data['ministry'] ?? 'Kebaktian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                                        Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      children: [
                                        const Icon(Icons.people, size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 8),
                                        Text("Kehadiran: ${data['attendance_count'] ?? '0'} jiwa"),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.monetization_on, size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 8),
                                        Text("Persembahan: Rp ${NumberFormat('#,###', 'id_ID').format(data['offering_amount'] ?? 0)}"),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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