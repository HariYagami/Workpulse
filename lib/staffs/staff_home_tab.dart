import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/organization_model.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';            // ← new: for navigation after logout

class StaffHomeTab extends StatefulWidget {
  final OrganizationModel org;
  const StaffHomeTab({super.key, required this.org});

  @override
  State<StaffHomeTab> createState() => _StaffHomeTabState();
}

class _StaffHomeTabState extends State<StaffHomeTab> {
  final _auth = AuthService();
  bool _isClockedIn = false;
  DateTime? _clockInTime;
  bool _clockLoading = false;

  Future<void> _toggleClock() async {
    setState(() => _clockLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      if (_isClockedIn) {
        _isClockedIn = false;
        _clockInTime = null;
      } else {
        _isClockedIn = true;
        _clockInTime = DateTime.now();
      }
      _clockLoading = false;
    });
  }

  String _elapsed() {
    if (_clockInTime == null) return '';
    final diff = DateTime.now().difference(_clockInTime!);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    return '$h h $m m';
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  // ── Logout: confirm → sign out → LoginScreen ──────────────────────────────
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: Text(
          'You\'ll need to sign in again to access your workspace.',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Cancel
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 10),
          // Sign out
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCEBEB),
                foregroundColor: const Color(0xFFA32D2D),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text('Sign out',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFA32D2D))),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (_) => false, // clear entire back stack
        );
      }
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildClockCard()),
          SliverToBoxAdapter(child: _buildQuickStats()),
          SliverToBoxAdapter(child: _buildSectionTitle('Your Organization')),
          SliverToBoxAdapter(child: _buildOrgCard()),
          SliverToBoxAdapter(child: _buildSectionTitle('This Week')),
          SliverToBoxAdapter(child: _buildWeekStrip()),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  // ── Changed: logout button added to top-right ─────────────────────────────
  Widget _buildHeader() {
    final photoUrl  = _auth.currentUserPhotoUrl;
    final firstName = _auth.currentUserFirstName;
    final initial   = firstName[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 4), // right reduced for icon
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.pastelBlue,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(initial,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pastelBlueDark))
                : null,
          ),
          const SizedBox(width: 12),
          // Greeting + name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(firstName,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    )),
              ],
            ),
          ),
          // Staff badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.mintDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 5),
                Text('Staff',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mintDark,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Logout button ────────────────────────────────────────────
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 17,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ── End of changed section ─────────────────────────────────────────────────

  Widget _buildClockCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isClockedIn ? AppColors.mint : AppColors.pastelBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isClockedIn ? 'You\'re clocked in' : 'Not clocked in',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _isClockedIn
                          ? AppColors.mintDark
                          : AppColors.pastelBlueDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isClockedIn
                        ? 'Time elapsed: ${_elapsed()}'
                        : 'Tap to start your day',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _isClockedIn
                          ? AppColors.mintDark.withOpacity(0.7)
                          : AppColors.pastelBlueDark.withOpacity(0.7),
                    ),
                  ),
                  if (_clockInTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Since ${_clockInTime!.hour.toString().padLeft(2, '0')}:${_clockInTime!.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.mintDark.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _clockLoading ? null : _toggleClock,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _isClockedIn
                      ? AppColors.mintDark
                      : AppColors.pastelBlueDark,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _clockLoading
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Icon(
                        _isClockedIn
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'This week',
              value: '38.5h',
              icon: Icons.timer_outlined,
              color: AppColors.lavender,
              textColor: AppColors.lavenderDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              label: 'Update streak',
              value: '5 days 🔥',
              icon: Icons.local_fire_department_rounded,
              color: AppColors.peach,
              textColor: AppColors.peachDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              label: 'Polls voted',
              value: '3/4',
              icon: Icons.how_to_vote_rounded,
              color: AppColors.mint,
              textColor: AppColors.mintDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
      child: Text(title,
          style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
    );
  }

  Widget _buildOrgCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.pastelBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  widget.org.initials,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pastelBlueDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.org.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(
                    widget.org.description.isNotEmpty
                        ? widget.org.description
                        : 'Your workspace',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.org.memberCount} members',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mintDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStrip() {
    final days  = ['M', 'T', 'W', 'T', 'F'];
    final hours = [8.5, 9.0, 8.0, 8.5, 0.0];
    final today = DateTime.now().weekday - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: List.generate(5, (i) {
            final isToday = i == today;
            final h = hours[i];
            final done = h > 0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Text(days[i],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? AppColors.pastelBlueDark
                              : AppColors.textHint,
                        )),
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.pastelBlue
                            : done
                                ? AppColors.mint
                                : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: isToday
                            ? Border.all(
                                color: AppColors.pastelBlueDark, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: done
                            ? Icon(Icons.check_rounded,
                                size: 16,
                                color: isToday
                                    ? AppColors.pastelBlueDark
                                    : AppColors.mintDark)
                            : Text('—',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textHint)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      done ? '${h}h' : '—',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: done
                            ? AppColors.textSecondary
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, textColor;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: textColor.withOpacity(0.7))),
        ],
      ),
    );
  }
}