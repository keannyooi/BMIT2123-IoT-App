import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import 'auth_provider.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final err = await context.read<AuthProvider>().register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      showErrorSnack(context, err);
    } else {
      showSuccessSnack(context, 'Account created successfully! You may now log in with your credentials.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // ── App Icon ──────────────────────────────────
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.accent,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: AppColors.primary,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ─────────────────────────────────────
                Text(
                  'Create Account',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Register an account to pair your Smart Medicine Cabinet to your phone!',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // ── Username Field ────────────────────────────
                AppTextField(
                  label: 'Username *',
                  hint: 'Name',
                  controller: _nameCtrl,
                  prefix: const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (v.trim().length < 2) {
                      return 'Name too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Email Field ───────────────────────────────
                AppTextField(
                  label: 'Email *',
                  hint: 'name@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefix: const Icon(
                    Icons.email_outlined,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password Field ────────────────────────────
                AppTextField(
                  label: 'Password *',
                  hint: '••••••••',
                  controller: _passCtrl,
                  obscure: _obscurePass,
                  prefix: const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    if (v.length < 8) {
                      return 'Password must be at least 8 characters, including 1 number and 1 special character';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(v)) {
                      return 'Password must include at least 1 number';
                    }
                    if (!RegExp(r'[!@#$&*~]').hasMatch(v)) {
                      return 'Password must include at least 1 special character';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Confirm Password Field ────────────────────
                AppTextField(
                  label: 'Confirm Password *',
                  hint: '••••••••',
                  controller: _confirmCtrl,
                  obscure: _obscureConfirm,
                  prefix: const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (v != _passCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // ── Create Account Button ─────────────────────
                AppButton(
                  label: 'Create Account',
                  onPressed: _register,
                  loading: _loading,
                ),
                const SizedBox(height: 20),

                // ── Login Link ────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      ),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}