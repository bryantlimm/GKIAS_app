// forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  // ── Brand colors ────────────────────────────────────────────────────────────
  static const Color _primary      = Color(0xFF3B5BDB);
  static const Color _bg           = Color(0xFFF0F4F8);
  static const Color _cardBg       = Color(0xFFFFFFFF);
  static const Color _border       = Color(0xFFE2E8F0);
  static const Color _textMain     = Color(0xFF1E293B);
  static const Color _textMuted    = Color(0xFF94A3B8);
  static const Color _errorBg      = Color(0xFFFFF5F5);
  static const Color _errorBorder  = Color(0xFFFECACA);
  static const Color _errorText    = Color(0xFFDC2626);
  static const Color _successBg    = Color(0xFFF0FDF4);
  static const Color _successBorder = Color(0xFFBBF7D0);
  static const Color _successText  = Color(0xFF16A34A);

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email tidak boleh kosong.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _emailSent = true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'Email ini tidak terdaftar.';
            break;
          case 'invalid-email':
            _errorMessage = 'Format email tidak valid.';
            break;
          default:
            _errorMessage = e.message ?? 'Gagal mengirim email. Silakan coba lagi.';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // ── Back button ──────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border, width: 1.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Color(0xFF64748B)),
                            SizedBox(width: 5),
                            Text('Kembali', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Branding ─────────────────────────────────────────
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lupa Password',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _textMain, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'GKI Bungur Bakal Jemaat Alam Sutera',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),

                  // ── Card ─────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4)),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: _emailSent ? _buildSuccessState() : _buildFormState(),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form state ───────────────────────────────────────────────────────────────
  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          'Masukkan email kamu dan kami akan mengirimkan link untuk mereset password.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
        ),
        const SizedBox(height: 20),

        // ── Error ──────────────────────────────────────────────────────
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _errorBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _errorBorder, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: _errorText, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMessage!, style: const TextStyle(color: _errorText, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Email field ────────────────────────────────────────────────
        _FieldLabel(label: 'Email'),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: 'contoh@email.com',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF94A3B8), size: 18),
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
          ),
        ),
        const SizedBox(height: 24),

        // ── Submit button ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendResetEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: const Color(0xFF93A3C7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Kirim Link Reset', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // ── Success state ────────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _successBg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _successBorder, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: _successText, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email terkirim!', style: TextStyle(color: _successText, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Link reset password telah dikirim ke ${_emailController.text.trim()}. Cek inbox atau folder spam kamu.',
                      style: const TextStyle(color: _successText, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Kembali ke Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: Color(0xFF64748B), letterSpacing: 0.8,
        ),
      ),
    );
  }
}