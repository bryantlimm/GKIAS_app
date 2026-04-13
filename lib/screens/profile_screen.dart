// profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color _primary      = Color(0xFF3B5BDB);
  static const Color _border       = Color(0xFFE8ECF0);
  static const Color _textMain     = Color(0xFF1E293B);
  static const Color _textSub      = Color(0xFF64748B);
  static const Color _textMuted    = Color(0xFF94A3B8);
  static const Color _errorText    = Color(0xFFDC2626);
  static const Color _errorBg      = Color(0xFFFFF5F5);
  static const Color _errorBorder  = Color(0xFFFECACA);
  static const Color _successText  = Color(0xFF16A34A);

  String _getInitials(String? name, String? email) {
    if (name != null && name.isNotEmpty) return name[0].toUpperCase();
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return 'U';
  }

  // ── Edit Name Sheet ───────────────────────────────────────────────────────
  void _showEditNameSheet(BuildContext context, String currentName) {
    final nameController = TextEditingController(text: currentName);
    bool isSubmitting = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('Ubah Nama',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textMain)),
                  const SizedBox(height: 4),
                  const Text('Masukkan nama baru Anda:',
                      style: TextStyle(fontSize: 13, color: _textSub)),
                  const SizedBox(height: 16),

                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _errorBg, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _errorBorder, width: 1.5),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded, color: _errorText, size: 15),
                        const SizedBox(width: 8),
                        Expanded(child: Text(errorMessage!,
                            style: const TextStyle(color: _errorText, fontSize: 13, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 14, color: _textMain),
                    decoration: InputDecoration(
                      hintText: 'Nama lengkap',
                      hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: _textMuted, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) {
                          setModalState(() => errorMessage = 'Nama tidak boleh kosong.');
                          return;
                        }
                        if (newName == currentName) {
                          Navigator.pop(context);
                          return;
                        }

                        setModalState(() { isSubmitting = true; errorMessage = null; });

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await Future.wait([
                              user.updateDisplayName(newName),
                              FirebaseFirestore.instance.collection('users').doc(user.uid)
                                  .update({'name': newName}),
                            ]);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Nama berhasil diubah!'),
                              backgroundColor: _successText,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } catch (e) {
                          setModalState(() {
                            isSubmitting = false;
                            errorMessage = 'Gagal mengubah nama. Silakan coba lagi.';
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary, foregroundColor: Colors.white,
                        elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        disabledBackgroundColor: const Color(0xFF93A3C7),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Remove Ministry Dialog ────────────────────────────────────────────────
  void _showRemoveMinistryDialog(BuildContext context, String ministry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Pelayanan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
        content: Text(
          'Hapus "$ministry" dari bidang pelayanan Anda?',
          style: const TextStyle(fontSize: 14, color: _textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: _textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorText, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'ministries': FieldValue.arrayRemove([ministry]),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('"$ministry" berhasil dihapus dari pelayanan.'),
                      backgroundColor: _successText,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Gagal menghapus pelayanan. Silakan coba lagi.'),
                    backgroundColor: _errorText,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Volunteer request sheet ───────────────────────────────────────────────
  void _showVolunteerRequestSheet(BuildContext context) {
    String? selectedMinistry;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('Daftar Pelayanan',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textMain)),
                  const SizedBox(height: 4),
                  const Text('Pilih bidang pelayanan yang ingin Anda ikuti:',
                      style: TextStyle(fontSize: 13, color: _textSub)),
                  const SizedBox(height: 16),

                  StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('schedules').orderBy('order').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator(color: _primary);
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(color: _border, width: 1.5)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
                              borderSide: const BorderSide(color: _primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        hint: const Text('Pilih Pelayanan...', style: TextStyle(color: _textMuted)),
                        value: selectedMinistry,
                        items: snapshot.data!.docs.map((doc) =>
                            DropdownMenuItem(value: doc['name'] as String, child: Text(doc['name']))).toList(),
                        onChanged: (v) => setModalState(() => selectedMinistry = v),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting || selectedMinistry == null ? null : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            title: const Text('Konfirmasi',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
                            content: Text('Daftar untuk pelayanan $selectedMinistry?',
                                style: const TextStyle(fontSize: 14, color: _textSub)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Batal', style: TextStyle(color: _textSub))),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _primary,
                                    foregroundColor: Colors.white, elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Ya, Daftar'),
                              ),
                            ],
                          ),
                        ) ?? false;

                        if (!confirm) return;
                        setModalState(() => isSubmitting = true);

                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          try {
                            final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                            final actualName = userDoc.data()?['name'] ?? user.displayName ?? 'Jemaat';
                            await FirebaseFirestore.instance.collection('volunteer_requests').add({
                              'userId': user.uid,
                              'userName': actualName,
                              'userEmail': user.email,
                              'ministry': selectedMinistry,
                              'status': 'pending',
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Permintaan pelayanan berhasil dikirim!'),
                                backgroundColor: _successText,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Gagal mengirim: $e'),
                                backgroundColor: _errorText,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary, foregroundColor: Colors.white,
                        elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Kirim Permintaan',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Keluar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textMain)),
        content: const Text('Apakah Anda yakin ingin keluar?',
            style: TextStyle(fontSize: 14, color: _textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: _textSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _errorText,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    await NotificationService.removeToken();
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Akun',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _errorText)),
        content: const Text(
          'Akun Anda beserta semua data terkait akan dihapus permanen dan tidak dapat dipulihkan. '
          'Apakah Anda yakin?',
          style: TextStyle(fontSize: 14, color: _textSub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: _textSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _errorText,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
        .httpsCallable('deleteUserAccount');
      await callable.call();
    } catch (e) {
      // ignore — account may already be deleted
    } finally {
      try {
        await NotificationService.removeToken();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
    }

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      color: const Color(0xFFF0F4F8),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primary));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Gagal memuat profil'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final name        = userData['name'] ?? 'User';
          final email       = userData['email'] ?? user?.email ?? '';
          final role        = userData['role'] ?? 'regular';
          final ministries  = (userData['ministries'] as List?) ?? [];
          final createdAt   = userData['createdAt'] as Timestamp?;

          final roleDisplay = role == 'admin' ? 'Administrator'
              : (role == 'volunteer' ? 'Pelayan' : 'Jemaat');

          return SingleChildScrollView(
            child: Column(children: [

              // ── Profile header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                color: _primary,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Column(children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(_getInitials(name, email),
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w800, fontSize: 32)),
                      ),
                      const SizedBox(height: 14),
                      // ── Tappable name with edit icon ──────────────────
                      GestureDetector(
                        onTap: () => _showEditNameSheet(context, name),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white,
                                fontSize: 20, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(roleDisplay,
                            style: const TextStyle(color: Colors.white, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
              ),

              // ── Account info card ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── Header row with edit name button ────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Informasi Akun',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textMain)),
                        GestureDetector(
                          onTap: () => _showEditNameSheet(context, name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF3FF),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 13, color: _primary),
                                SizedBox(width: 5),
                                Text('Ubah Nama', style: TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w700, color: _primary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE8ECF0)),
                    _InfoRow(icon: Icons.person_outline_rounded, label: 'Nama', value: name),
                    const SizedBox(height: 14),
                    _InfoRow(icon: Icons.email_outlined, label: 'Email', value: email),
                    if (createdAt != null) ...[
                      const SizedBox(height: 14),
                      _InfoRow(icon: Icons.calendar_today_outlined, label: 'Bergabung Sejak',
                          value: DateFormat('dd MMMM yyyy', 'id_ID').format(createdAt.toDate())),
                    ],

                    // ── Ministries with remove chips ────────────────────
                    if (ministries.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.church_outlined, size: 18, color: _textMuted),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Bidang Pelayanan',
                              style: TextStyle(fontSize: 11, color: _textMuted,
                                  fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ministries.map((ministry) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF3FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(ministry.toString(),
                                        style: const TextStyle(fontSize: 12,
                                            fontWeight: FontWeight.w600, color: _primary)),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _showRemoveMinistryDialog(context, ministry.toString()),
                                      child: const Icon(Icons.close_rounded, size: 14, color: _primary),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ])),
                      ]),
                    ],
                  ]),
                ),
              ),

              // ── Action buttons ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(children: [

                  if (role != 'admin') ...[
                    _ActionButton(
                      icon: Icons.volunteer_activism_outlined,
                      label: 'Daftar Pelayanan',
                      color: _primary,
                      bg: const Color(0xFFEFF3FF),
                      border: const Color(0xFFC7D2FE),
                      onTap: () => _showVolunteerRequestSheet(context),
                    ),
                    const SizedBox(height: 10),
                  ],

                  _ActionButton(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    color: _errorText,
                    bg: _errorBg,
                    border: _errorBorder,
                    onTap: () => _handleLogout(context),
                  ),
                  const SizedBox(height: 10),

                  if (role != 'admin')
                    _ActionButton(
                      icon: Icons.delete_forever_outlined,
                      label: 'Hapus Akun',
                      color: _errorText,
                      bg: _errorBg,
                      border: _errorBorder,
                      onTap: () => _handleDeleteAccount(context),
                      isDestructive: true,
                    ),
                ]),
              ),

            ]),
          );
        },
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B))),
      ])),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg, border;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon, required this.label,
    required this.color, required this.bg, required this.border,
    required this.onTap, this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.5)),
        ]),
      ),
    );
  }
}