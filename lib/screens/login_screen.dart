import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:presenceiq/screens/organization/my_organizations_screen.dart';
import 'package:presenceiq/staffs/staff_dashboard.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _staffLoading = false;
  bool _adminLoading = false;
  String? _errorMessage;

  // ─── Staff: Google Sign-In → isAdmin: false → StaffDashboard ─────────────
  Future<void> _handleStaffSignIn() async {
    setState(() {
      _staffLoading = true;
      _errorMessage = null;
    });
    try {
      final user = await AuthService().signInAsStaff();
      if (user == null) {
        setState(() => _staffLoading = false);
        return;
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const StaffDashboard(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ));
      }
    } catch (e) {
      setState(() {
        _staffLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ─── Admin: Google Sign-In → isAdmin: true → MyOrganizationsScreen ────────
 Future<void> _handleAdminSignIn() async {
  setState(() {
    _adminLoading = true;
    _errorMessage = null;
  });
  try {
    final user = await AuthService().signInAsAdmin(); // UserModel? now
    if (user == null) {
      setState(() => _adminLoading = false);
      return;
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MyOrganizationsScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
    }
  } catch (e) {
    setState(() {
      _adminLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildHeader(),
              const Spacer(flex: 2),
              _buildWelcomeText(),
              const SizedBox(height: 36),
              _buildRoleCards(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorBanner(),
              ],
              const Spacer(flex: 3),
              _buildFooter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.pastelBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 14, top: 18,
                child: Container(
                  width: 11, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlueDark.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: 30, top: 24,
                child: Container(
                  width: 11, height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlueDark.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: 46, top: 15,
                child: Container(
                  width: 11, height: 39,
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlueDark,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'WorkPulse',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who are you?',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how you want to sign in.\nThis sets your role in the workspace.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCards() {
    return Column(
      children: [
        // ── Staff card ──────────────────────────────────────────────────
        _RoleCard(
          icon: Icons.person_rounded,
          label: 'Staff Member',
          description: 'Clock in, vote on polls, submit daily updates',
          accentColor: AppColors.mint,
          accentDark: AppColors.mintDark,
          loading: _staffLoading,
          disabled: _adminLoading,
          onTap: _handleStaffSignIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GoogleIcon(),
              const SizedBox(width: 10),
              Text(
                'Sign in with Google',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mintDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Admin card ──────────────────────────────────────────────────
        _RoleCard(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Admin',
          description: 'Manage organizations, view all staff data & insights',
          accentColor: AppColors.pastelBlue,
          accentDark: AppColors.pastelBlueDark,
          loading: _adminLoading,
          disabled: _staffLoading,
          onTap: _handleAdminSignIn,
          // Admin also uses Google — different account from staff
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GoogleIcon(),
              const SizedBox(width: 10),
              Text(
                'Sign in as Admin',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pastelBlueDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF09595)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFA32D2D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFFA32D2D)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close_rounded,
                size: 16, color: Color(0xFFA32D2D)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'By signing in, you agree to your company\'s\naccess policy managed by your admin.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.textHint,
        height: 1.6,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role Card
// ─────────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color accentColor;
  final Color accentDark;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;
  final Widget child;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.accentColor,
    required this.accentDark,
    required this.loading,
    required this.disabled,
    required this.onTap,
    required this.child,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.loading;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _pressCtrl.reverse(),
      onTapUp: isDisabled ? null : (_) => _pressCtrl.forward(),
      onTapCancel: () => _pressCtrl.forward(),
      onTap: isDisabled ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (_, child) =>
            Transform.scale(scale: _pressCtrl.value, child: child),
        child: AnimatedOpacity(
          opacity: isDisabled && !widget.loading ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.loading
                    ? widget.accentDark
                    : AppColors.border,
                width: widget.loading ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon,
                          size: 18, color: widget.accentDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.description,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 14),
                widget.loading
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(
                                widget.accentDark),
                          ),
                        ),
                      )
                    : widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Google Icon ──────────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    p.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -1.57, 3.14, true, p);
    p.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        1.57, 1.57, true, p);
    p.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.14, 1.57, true, p);
    p.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -1.57, 1.57, true, p);
    p.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.55, p);
    p.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(cx, cy - r * 0.2, r, r * 0.4), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}