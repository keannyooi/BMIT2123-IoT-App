import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import 'auth_provider.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushNotification = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _pushNotification = prefs.getBool('push_notification') ?? true;
  }

  // ── Confirm Sign Out ───────────────────────────────────────
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
                    (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(80, 40),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  // ── Confirm Delete Account ─────────────────────────────────
  // TODO: permissions denied, either give perms or dummy out this function
  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Account',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
        content: Text(
          'Confirm to delete this account? You will not be able to undo this action.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await context.read<AuthProvider>().deleteAccount();
              if (!mounted) return;
              if (err != null) {
                showErrorSnack(context, err);
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (_) => false,
                );
                showSuccessSnack(
                  context,
                  'Successfully deleted account!',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(130, 40),
            ),
            child: const Text('Confirm Delete'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(130, 40),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // App icon in appbar like design
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.eco,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: auth.loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile Card ────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Name + email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?['name'] ?? 'User',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                profile?['email'] ??
                                    auth.currentUser?.email ??
                                    '',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              if (profile?['bio'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  profile!['bio'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Account Setting ─────────────────────────
                  Text(
                    'Account Setting',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _settingTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EditProfileScreen(profile: profile),
                        ),
                      );
                    },
                  ),
                  _settingTile(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    onTap: () => _showChangePasswordSheet(context),
                  ),
                  const SizedBox(height: 24),

                  // ── Preferences ─────────────────────────────
                  Text(
                    'Preferences',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _toggleTile(
                      icon: Icons.notifications_outlined,
                      label: 'Push Notification',
                      value: _pushNotification,
                      onChanged: (v) async {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() {
                          _pushNotification = v;
                          prefs.setBool('push_notification', v);
                        });
                      }),
                  const SizedBox(height: 32),

                  // ── Delete Account Button ───────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _confirmDeleteAccount,
                      icon: const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                      ),
                      label: const Text('Delete Account'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Sign Out ────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _confirmSignOut,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Setting tile ───────────────────────────────────────────
  Widget _settingTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  // ── Toggle tile ────────────────────────────────────────────
  Widget _toggleTile({
    required IconData icon,
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ── Change Password Bottom Sheet ───────────────────────────
  void _showChangePasswordSheet(BuildContext context) {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool saving = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Change Password',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Inline Error Message
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: GoogleFonts.poppins(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              AppTextField(
                label: 'New Password',
                hint: '••••••••',
                controller: newPassCtrl,
                obscure: obscureNew,
                suffix: IconButton(
                  icon: Icon(
                    obscureNew ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  onPressed: () =>
                      setSheetState(() => obscureNew = !obscureNew),
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Confirm New Password',
                hint: '••••••••',
                controller: confirmPassCtrl,
                obscure: obscureConfirm,
                suffix: IconButton(
                  icon: Icon(
                    obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  onPressed: () =>
                      setSheetState(() => obscureConfirm = !obscureConfirm),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Update Password',
                loading: saving,
                onPressed: () async {
                  setSheetState(() => errorMessage = null);

                  if (newPassCtrl.text != confirmPassCtrl.text) {
                    setSheetState(
                        () => errorMessage = 'Passwords do not match');
                    return;
                  }
                  if (newPassCtrl.text.length < 8) {
                    setSheetState(() => errorMessage =
                        'Password must be at least 8 characters');
                    return;
                  }
                  if (!RegExp(r'[0-9]').hasMatch(newPassCtrl.text)) {
                    setSheetState(() => errorMessage =
                        'Password must include at least 1 number');
                    return;
                  }
                  if (!RegExp(r'[!@#$&*~]').hasMatch(newPassCtrl.text)) {
                    setSheetState(() => errorMessage =
                        'Password must include at least 1 special character');
                    return;
                  }

                  setSheetState(() => saving = true);
                  final err = await context
                      .read<AuthProvider>()
                      .updatePassword(newPassCtrl.text);
                  setSheetState(() => saving = false);

                  if (!ctx.mounted) return;

                  if (err != null) {
                    setSheetState(() => errorMessage = err);
                  } else {
                    Navigator.pop(ctx);
                    showSuccessSnack(
                      context,
                      'Password updated successfully!',
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}