import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:presenceiq/models/organization_model.dart';
import 'package:presenceiq/providers/org_provider.dart';
import 'package:presenceiq/services/auth_service.dart';
import 'package:presenceiq/services/org_service.dart';
import 'package:presenceiq/staffs/staff_dashboard.dart';
import 'package:presenceiq/theme/app_theme.dart';
import '../login_screen.dart';

class JoinOrgScreen extends ConsumerStatefulWidget {
  const JoinOrgScreen({super.key});

  @override
  ConsumerState<JoinOrgScreen> createState() => _JoinOrgScreenState();
}

class _JoinOrgScreenState extends ConsumerState<JoinOrgScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  // Sign out and go back to login
  Future<void> _handleBack() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _joinOrg() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter an invite code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Step 1: Validate code → get org
      final org = await OrgService().getOrgByCode(code);
      if (org == null) {
        setState(() {
          _error = 'Invalid invite code. Please check and try again.';
          _loading = false;
        });
        return;
      }

      // Step 2: Already a member? Skip join, go straight to dashboard
      final role = await OrgService().getUserRole(org.id);
      if (role != null) {
        ref.invalidate(staffOrgProvider);
        if (mounted) _goToDashboard(org);
        return;
      }

      // Step 3: Join org
      await OrgService().joinOrgByCode(code);

      ref.invalidate(staffOrgProvider);
      if (mounted) _goToDashboard(org);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('already a member')) {
        final org = await OrgService().getOrgByCode(code);
        if (org != null && mounted) {
          ref.invalidate(staffOrgProvider);
          _goToDashboard(org);
        }
        return;
      }
      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  // Pass org directly → StaffDashboard skips provider, no loop
  void _goToDashboard(OrganizationModel org) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => StaffDashboard(initialOrg: org),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded,
              size: 18, color: Color(0xFFA32D2D)),
          tooltip: 'Sign out',
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.pastelBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.vpn_key_rounded,
                    size: 36, color: AppColors.pastelBlueDark),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter Invite Code',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ask your admin for the invite code\nto join your organization.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _codeCtrl,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'XX-XXXX',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 6,
                    color: AppColors.textHint,
                  ),
                  filled: true,
                  fillColor: AppColors.pastelBlue.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.pastelBlueDark, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFF09595), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 20),
                ),
                onChanged: (v) {
                  if (v.length == 2 && !v.contains('-')) {
                    _codeCtrl.text = '$v-';
                    _codeCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _codeCtrl.text.length));
                  }
                  if (_error != null) setState(() => _error = null);
                },
                onFieldSubmitted: (_) => _joinOrg(),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF09595)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: Color(0xFFA32D2D)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFA32D2D)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _joinOrg,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Join Organization'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Don\'t have a code? Contact your admin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}