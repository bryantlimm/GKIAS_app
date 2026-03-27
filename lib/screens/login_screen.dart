// login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import 'main_screen.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // ── Brand colors (matching web dashboard) ──────────────────────────────────
  static const Color _primary    = Color(0xFF3B5BDB);
  static const Color _primaryDark = Color(0xFF2F4AC7);
  static const Color _bg         = Color(0xFFF0F4F8);
  static const Color _cardBg     = Color(0xFFFFFFFF);
  static const Color _border     = Color(0xFFE2E8F0);
  static const Color _textMain   = Color(0xFF1E293B);
  static const Color _textMuted  = Color(0xFF94A3B8);
  static const Color _errorBg    = Color(0xFFFFF5F5);
  static const Color _errorBorder = Color(0xFFFECACA);
  static const Color _errorText  = Color(0xFFDC2626);

  Future<void> _login() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await NotificationService.saveToken();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            _errorMessage = 'Email atau password salah. Silakan coba lagi.';
            break;
          default:
            _errorMessage = e.message ?? 'Login gagal. Silakan coba lagi.';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

                  // ── Logo / branding ─────────────────────────────────────
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Masuk',
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: _textMain, letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'GKI Bungur Bakal Jemaat Alam Sutera',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),

                  // ── Card ────────────────────────────────────────────────
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Error message ──────────────────────────────
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

                        // ── Email field ────────────────────────────────
                        _FieldLabel(label: 'Email'),
                        _StyledTextField(
                          controller: _emailController,
                          hint: 'contoh@email.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // ── Password field ─────────────────────────────
                        _FieldLabel(label: 'Password'),
                        _StyledTextField(
                          controller: _passwordController,
                          hint: '••••••••',
                          prefixIcon: Icons.key_outlined,
                          obscureText: _obscurePassword,
                          suffixIcon: _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        const SizedBox(height: 28),

                        // ── Login button ───────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
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
                                : const Text('Masuk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Sign up link ─────────────────────────────────────
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Belum punya akun? ', style: TextStyle(color: _textMuted, fontSize: 14)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUpScreen()),
                        ),
                        child: const Text(
                          'Daftar di sini',
                          style: TextStyle(color: _primary, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

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

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 18),
        suffixIcon: suffixIcon != null
            ? GestureDetector(
                onTap: onSuffixTap,
                child: Icon(suffixIcon, color: const Color(0xFF94A3B8), size: 18),
              )
            : null,
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
    );
  }
}