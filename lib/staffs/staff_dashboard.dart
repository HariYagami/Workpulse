import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:presenceiq/providers/org_provider.dart';
import 'package:presenceiq/screens/organization/join_org_screen.dart';
import '../theme/app_theme.dart';
import '../models/organization_model.dart';
import 'staff_home_tab.dart';
import 'staff_attendance_screen.dart';
import 'staff_polls_screen.dart';
import 'staff_updates_screen.dart';

final staffOrgProvider = FutureProvider<OrganizationModel?>((ref) async {
  final orgs = await ref.watch(myOrgsProvider.future);
  return orgs.isEmpty ? null : orgs.first;
});

class StaffDashboard extends ConsumerWidget {
  final OrganizationModel? initialOrg;
  const StaffDashboard({super.key, this.initialOrg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Came from JoinOrgScreen — skip provider, go straight to shell
    if (initialOrg != null) {
      return _StaffDashboardShell(org: initialOrg!);
    }

    final orgAsync = ref.watch(staffOrgProvider);

    return orgAsync.when(
      loading: () => _loadingScaffold(),
      error: (_, __) => _loadingScaffold(),
      data: (org) {
        if (org == null) {
          // New user — no org yet, send to JoinOrgScreen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const JoinOrgScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 300),
                ),
                (route) => false,
              );
            }
          });
          return _loadingScaffold();
        }
        // Existing member — go straight to shell
        return _StaffDashboardShell(org: org);
      },
    );
  }

  Scaffold _loadingScaffold() => const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.pastelBlueDark,
          ),
        ),
      );
}

class _StaffDashboardShell extends StatefulWidget {
  final OrganizationModel org;
  const _StaffDashboardShell({required this.org});

  @override
  State<_StaffDashboardShell> createState() => _StaffDashboardShellState();
}

class _StaffDashboardShellState extends State<_StaffDashboardShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      StaffHomeTab(org: widget.org),
      StaffAttendanceScreen(org: widget.org),
      StaffPollsScreen(org: widget.org),
      StaffUpdatesScreen(org: widget.org),
    ];
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  void _onTabChanged(int index) {
    if (index == _selectedIndex) return;
    _fadeController.forward(from: 0);
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: GNav(
            selectedIndex: _selectedIndex,
            onTabChange: _onTabChanged,
            backgroundColor: AppColors.white,
            color: AppColors.textSecondary,
            activeColor: AppColors.mintDark,
            tabBackgroundColor: AppColors.mint,
            gap: 6,
            tabBorderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeInOutCubic,
            haptic: true,
            textStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mintDark,
            ),
            tabs: const [
              GButton(icon: Icons.home_rounded,        text: 'Home',       iconSize: 22),
              GButton(icon: Icons.schedule_rounded,    text: 'Attendance', iconSize: 22),
              GButton(icon: Icons.how_to_vote_rounded, text: 'Polls',      iconSize: 22),
              GButton(icon: Icons.edit_note_rounded,   text: 'Updates',    iconSize: 22),
            ],
          ),
        ),
      ),
    );
  }
}