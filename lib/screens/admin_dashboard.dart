import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:presenceiq/screens/organization/invite_members_screen.dart';
import 'package:presenceiq/screens/organization/my_organizations_screen.dart';
import 'package:presenceiq/screens/organization/set_office_location_screen.dart';
import 'package:presenceiq/services/auth_service.dart';
import 'package:presenceiq/services/org_service.dart';
import 'package:presenceiq/services/updates_service.dart';
import '../theme/app_theme.dart';
import '../models/organization_model.dart';
import 'login_screen.dart';
import 'polls_screen.dart';
import 'attendance_screen.dart';
import 'updates_screen.dart';
import 'insights_screen.dart';

class AdminDashboard extends StatefulWidget {
  final OrganizationModel org;
  const AdminDashboard({super.key, required this.org});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _HomeTab(org: widget.org),
      PollsScreen(embedded: true, orgId: widget.org.id),
      AttendanceScreen(embedded: true, orgId: widget.org.id),
      UpdatesScreen(embedded: true, orgId: widget.org.id),
      InsightsScreen(orgId: widget.org.id),
    ];
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
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
            activeColor: AppColors.pastelBlueDark,
            tabBackgroundColor: AppColors.pastelBlue,
            gap: 6,
            tabBorderRadius: 14,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            haptic: true,
            textStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.pastelBlueDark,
            ),
            tabs: const [
              GButton(
                  icon: Icons.dashboard_rounded,
                  text: 'Home',
                  iconSize: 22),
              GButton(
                  icon: Icons.how_to_vote_rounded,
                  text: 'Polls',
                  iconSize: 22),
              GButton(
                  icon: Icons.schedule_rounded,
                  text: 'Attendance',
                  iconSize: 22),
              GButton(
                  icon: Icons.edit_note_rounded,
                  text: 'Updates',
                  iconSize: 22),
              GButton(
                  icon: Icons.bar_chart_rounded,
                  text: 'Insights',
                  iconSize: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final OrganizationModel org;
  const _HomeTab({required this.org});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _db = FirebaseFirestore.instance;
  final _updatesService = UpdatesService();
  bool _locationSet = false;

  // ── Derived from Firestore streams ────────────────────────────────────────
  // Today's date string e.g. "2025-01-15"
  String get _todayStr {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _checkLocationSet();
  }

  Future<void> _checkLocationSet() async {
    final loc = await OrgService().getOfficeLocation(widget.org.id);
    if (mounted) setState(() => _locationSet = loc != null);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  // ── Stream: today's attendance records for all staff ─────────────────────
  Stream<List<Map<String, dynamic>>> get _todayAttendanceStream {
    return _db
        .collection('organizations')
        .doc(widget.org.id)
        .collection('attendance')
        .doc(_todayStr)
        .collection('records')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Stream: staff members ─────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> get _staffStream {
    return _db
        .collection('organizations')
        .doc(widget.org.id)
        .collection('members')
        .where('role', isEqualTo: 'staff')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Stream: today's updates ───────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> get _todayUpdatesStream {
    return _updatesService.streamTodayUpdates(widget.org.id);
  }

  // ── Stream: active polls count ────────────────────────────────────────────
  Stream<int> get _activePollsStream {
    return _db
        .collection('organizations')
        .doc(widget.org.id)
        .collection('polls')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          if (!_locationSet)
            SliverToBoxAdapter(child: _buildLocationBanner(context)),
          SliverToBoxAdapter(child: _buildStatsRow()),
          SliverToBoxAdapter(
              child: _sectionTitle('Today\'s Attendance')),
          SliverToBoxAdapter(child: _buildAttendanceList()),
          SliverToBoxAdapter(child: _sectionTitle('Recent Updates')),
          SliverToBoxAdapter(child: _buildUpdatesList()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ── Stats Row — real data ─────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _staffStream,
        builder: (context, staffSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _todayAttendanceStream,
            builder: (context, attSnap) {
              return StreamBuilder<int>(
                stream: _activePollsStream,
                builder: (context, pollSnap) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _todayUpdatesStream,
                    builder: (context, updSnap) {
                      final totalStaff =
                          staffSnap.data?.length ?? 0;
                      final clockedIn = (attSnap.data ?? [])
                          .where((r) => r['clockedIn'] == true)
                          .length;
                      final activePolls = pollSnap.data ?? 0;
                      final totalUpdates =
                          updSnap.data?.length ?? 0;
                      final reviewedUpdates = (updSnap.data ?? [])
                          .where((u) => u['reviewed'] == true)
                          .length;

                      return Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Clocked In',
                              value: '$clockedIn/$totalStaff',
                              color: AppColors.mint,
                              textColor: AppColors.mintDark,
                              icon: Icons
                                  .check_circle_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Active Polls',
                              value: '$activePolls',
                              color: AppColors.pastelBlue,
                              textColor: AppColors.pastelBlueDark,
                              icon: Icons.how_to_vote_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Updates',
                              value:
                                  '$reviewedUpdates/$totalUpdates',
                              color: AppColors.lavender,
                              textColor: AppColors.lavenderDark,
                              icon: Icons.edit_note_rounded,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ── Attendance list — real data ───────────────────────────────────────────
  Widget _buildAttendanceList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _staffStream,
        builder: (context, staffSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _todayAttendanceStream,
            builder: (context, attSnap) {
              if (staffSnap.connectionState ==
                      ConnectionState.waiting ||
                  attSnap.connectionState ==
                      ConnectionState.waiting) {
                return Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.pastelBlueDark),
                  ),
                );
              }

              final staffList = staffSnap.data ?? [];
              final attendanceMap = {
                for (final r in (attSnap.data ?? [])) r['id']: r
              };

              if (staffList.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text('No staff members yet.',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textHint)),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: staffList.asMap().entries.map((e) {
                    final i = e.key;
                    final staff = e.value;
                    final uid = staff['id'] as String;
                    final name =
                        (staff['name'] as String?) ?? 'Unknown';
                    final role =
                        (staff['role'] as String?) ?? 'Staff';
                    final record = attendanceMap[uid];
                    final clocked =
                        record?['clockedIn'] == true;
                    final clockedOut =
                        record?['clockedOut'] == true;

                    String timeLabel = '—';
                    if (clocked && record?['clockInTime'] != null) {
                      final ts =
                          record!['clockInTime'] as Timestamp;
                      final tod = TimeOfDay.fromDateTime(
                          ts.toDate());
                      final h = tod.hour == 0
                          ? 12
                          : tod.hour > 12
                              ? tod.hour - 12
                              : tod.hour;
                      final m = tod.minute
                          .toString()
                          .padLeft(2, '0');
                      final period =
                          tod.hour < 12 ? 'AM' : 'PM';
                      timeLabel = '$h:$m $period';
                    }

                    return _AttendanceTile(
                      name: name,
                      role: role,
                      clocked: clocked,
                      clockedOut: clockedOut,
                      time: timeLabel,
                      showBorder: i != staffList.length - 1,
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Updates list — real data ──────────────────────────────────────────────
  Widget _buildUpdatesList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _todayUpdatesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.pastelBlueDark),
              ),
            );
          }

          final updates = snap.data ?? [];

          if (updates.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text('No updates submitted yet today.',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textHint)),
              ),
            );
          }

          // Show latest 3 updates on home tab
          final shown = updates.take(3).toList();

          return Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: shown.asMap().entries.map((e) {
                final i = e.key;
                final u = e.value;
                final name =
                    (u['name'] as String?) ?? 'Unknown';
                final work = (u['work'] as String?) ?? '';
                final reviewed =
                    (u['reviewed'] as bool?) ?? false;
                final ts = u['submittedAt'];
                String time = '';
                if (ts != null) {
                  final tod = TimeOfDay.fromDateTime(
                      (ts as Timestamp).toDate());
                  final h = tod.hour == 0
                      ? 12
                      : tod.hour > 12
                          ? tod.hour - 12
                          : tod.hour;
                  final m = tod.minute
                      .toString()
                      .padLeft(2, '0');
                  final period =
                      tod.hour < 12 ? 'AM' : 'PM';
                  time = '$h:$m $period';
                }

                return _UpdateTile(
                  name: name,
                  update: work,
                  time: time,
                  reviewed: reviewed,
                  showBorder: i != shown.length - 1,
                  orgId: widget.org.id,
                  updateId: (u['id'] as String?) ?? '',
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // ── Location banner ───────────────────────────────────────────────────────
  Widget _buildLocationBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: GestureDetector(
        onTap: () => _openSetLocation(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.peach,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.peachDark.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_off_rounded,
                  size: 20, color: AppColors.peachDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Office location not set',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.peachDark,
                      ),
                    ),
                    Text(
                      'Tap to set location for GPS-based attendance.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.peachDark),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.peachDark),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSetLocation(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SetOfficeLocationScreen(orgId: widget.org.id),
      ),
    );
    _checkLocationSet();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Log out?',
          style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        content: Text(
          'You\'ll be signed out of your admin account.',
          style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5),
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          const LoginScreen(),
                      transitionsBuilder:
                          (_, anim, __, child) =>
                              FadeTransition(
                                  opacity: anim, child: child),
                      transitionDuration:
                          const Duration(milliseconds: 400),
                    ),
                    (route) => false,
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFCEBEB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text('Log out',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFA32D2D))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final displayName = firebaseUser?.displayName ?? 'Admin';
    final initials = _initials(displayName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const MyOrganizationsScreen()),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.pastelBlue,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(widget.org.initials,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    AppColors.pastelBlueDark)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(widget.org.name,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    const Icon(Icons.unfold_more_rounded,
                        size: 16, color: AppColors.textHint),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          InviteMembersScreen(org: widget.org)),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_rounded,
                          size: 14,
                          color: AppColors.pastelBlueDark),
                      const SizedBox(width: 5),
                      Text('Invite',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pastelBlueDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openSetLocation(context),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _locationSet
                        ? AppColors.mint
                        : AppColors.peach,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: _locationSet
                        ? AppColors.mintDark
                        : AppColors.peachDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showLogoutDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded,
                      size: 16, color: Color(0xFFA32D2D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_greeting()},',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.pastelBlue,
                backgroundImage: firebaseUser?.photoURL != null
                    ? NetworkImage(firebaseUser!.photoURL!)
                    : null,
                child: firebaseUser?.photoURL == null
                    ? Text(initials,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.pastelBlueDark))
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Text(title,
          style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REAL DATA WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceTile extends StatelessWidget {
  final String name;
  final String role;
  final String time;
  final bool clocked;
  final bool clockedOut;
  final bool showBorder;

  const _AttendanceTile({
    required this.name,
    required this.role,
    required this.clocked,
    required this.clockedOut,
    required this.time,
    required this.showBorder,
  });

  @override
  Widget build(BuildContext context) {
    // Three states: present+done (green), present+active (blue), absent (grey)
    Color chipColor;
    Color chipText;
    String chipLabel;

    if (clocked && clockedOut) {
      chipColor = AppColors.mint;
      chipText = AppColors.mintDark;
      chipLabel = 'Done';
    } else if (clocked) {
      chipColor = AppColors.pastelBlue;
      chipText = AppColors.pastelBlueDark;
      chipLabel = 'Clocked In';
    } else {
      chipColor = AppColors.surface;
      chipText = AppColors.textHint;
      chipLabel = 'Absent';
    }

    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(
                    color: AppColors.border, width: 0.8))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: clocked ? AppColors.mint : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: clocked
                        ? AppColors.mintDark
                        : AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                Text(role,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  chipLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: chipText),
                ),
              ),
              const SizedBox(height: 4),
              Text(time,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdateTile extends StatefulWidget {
  final String name;
  final String update;
  final String time;
  final bool reviewed;
  final bool showBorder;
  final String orgId;
  final String updateId;

  const _UpdateTile({
    required this.name,
    required this.update,
    required this.time,
    required this.reviewed,
    required this.showBorder,
    required this.orgId,
    required this.updateId,
  });

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  bool _marking = false;
  final _service = UpdatesService();

  @override
  Widget build(BuildContext context) {
    final initials = widget.name.length >= 2
        ? widget.name.substring(0, 2).toUpperCase()
        : widget.name.toUpperCase();

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: widget.showBorder
            ? const Border(
                bottom: BorderSide(
                    color: AppColors.border, width: 0.8))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lavenderDark),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(widget.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  Text(widget.time,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textHint)),
                ]),
                const SizedBox(height: 4),
                Text(widget.update,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (!widget.reviewed) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: (_marking ||
                            widget.updateId.isEmpty)
                        ? null
                        : () async {
                            setState(() => _marking = true);
                            await _service.markReviewed(
                                widget.orgId, widget.updateId);
                            if (mounted) {
                              setState(() => _marking = false);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _marking
                            ? AppColors.pastelBlueDark
                                .withOpacity(0.5)
                            : AppColors.pastelBlueDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _marking
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Text('Mark Reviewed',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                    ),
                  ),
                ] else
                  Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 13, color: AppColors.mintDark),
                    const SizedBox(width: 4),
                    Text('Reviewed',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.mintDark,
                            fontWeight: FontWeight.w500)),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CARD — unchanged
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color, textColor;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(height: 10),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textColor.withOpacity(0.7))),
        ],
      ),
    );
  }
}