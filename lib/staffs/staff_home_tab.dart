import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/organization_model.dart';
import '../services/auth_service.dart';
import '../services/updates_service.dart';
import '../screens/login_screen.dart';

class StaffHomeTab extends StatefulWidget {
  final OrganizationModel org;
  const StaffHomeTab({super.key, required this.org});

  @override
  State<StaffHomeTab> createState() => _StaffHomeTabState();
}

class _StaffHomeTabState extends State<StaffHomeTab> {
  final _auth = AuthService();
  final _db = FirebaseFirestore.instance;
  final _updatesService = UpdatesService();

  // ── Today's attendance state (loaded from Firestore) ──────────────────────
  bool _clockedIn = false;
  bool _clockedOut = false;
  Timestamp? _clockInTime;

  // ── Elapsed timer ─────────────────────────────────────────────────────────
  Timer? _elapsedTimer;

  // ── Loading state ─────────────────────────────────────────────────────────
  bool _loading = true;

  // ── Week attendance records: dateStr → record ─────────────────────────────
  final Map<String, Map<String, dynamic>?> _weekRecords = {};

  String get _uid => _auth.currentFirebaseUser?.uid ?? '';

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _todayStr => _dateStr(DateTime.now());

  List<DateTime> get _weekDays {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(5, (i) => monday.add(Duration(days: i)));
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  // ── Load today + week attendance from Firestore ───────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final weekDates = _weekDays.map((d) => _dateStr(d)).toList();
      final futures = weekDates.map((date) => _db
          .collection('organizations')
          .doc(widget.org.id)
          .collection('attendance')
          .doc(date)
          .collection('records')
          .doc(_uid)
          .get());
      final results = await Future.wait(futures);
      for (int i = 0; i < weekDates.length; i++) {
        final doc = results[i];
        _weekRecords[weekDates[i]] =
            doc.exists ? doc.data() as Map<String, dynamic> : null;
      }

      // Today's state
      final todayData = _weekRecords[_todayStr];
      if (todayData != null) {
        _clockedIn = todayData['clockedIn'] == true;
        _clockedOut = todayData['clockedOut'] == true;
        _clockInTime = todayData['clockInTime'] as Timestamp?;
      }

      // Start elapsed ticker if clocked in and not yet out
      if (_clockedIn && !_clockedOut) {
        _startElapsedTimer();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer =
        Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  // ── Elapsed time string ───────────────────────────────────────────────────
  String _elapsed() {
    if (_clockInTime == null) return '';
    final diff =
        DateTime.now().difference(_clockInTime!.toDate());
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    return '$h h $m m';
  }

  // ── Stream: polls voted vs total active ───────────────────────────────────
  Stream<Map<String, int>> get _pollStatsStream {
    return _db
        .collection('organizations')
        .doc(widget.org.id)
        .collection('polls')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final total = snap.docs.length;
      final voted = snap.docs.where((doc) {
        final voterMap = Map<String, dynamic>.from(
            (doc.data()['voterMap'] as Map?) ?? {});
        return voterMap.containsKey(_uid);
      }).length;
      return {'voted': voted, 'total': total};
    });
  }

  // ── Stream: today's update streak ────────────────────────────────────────
  Stream<int> get _streakStream {
    if (_uid.isEmpty) return Stream.value(0);
    return _db
        .collection('organizations')
        .doc(widget.org.id)
        .collection('updates')
        .doc(_todayStr)
        .collection('entries')
        .doc(_uid)
        .snapshots()
        .map((doc) =>
            doc.exists ? ((doc.data()?['streak'] ?? 0) as int) : 0);
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: Text(
          'You\'ll need to sign in again to access your workspace.',
          style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5),
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 10),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 13),
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
          (_) => false,
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.mintDark),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildClockCard()),
            SliverToBoxAdapter(child: _buildQuickStats()),
            SliverToBoxAdapter(
                child: _buildSectionTitle('Your Organization')),
            SliverToBoxAdapter(child: _buildOrgCard()),
            SliverToBoxAdapter(
                child: _buildSectionTitle('This Week')),
            SliverToBoxAdapter(child: _buildWeekStrip()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final photoUrl = _auth.currentUserPhotoUrl;
    final firstName = _auth.currentUserFirstName;
    final initial = firstName[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.pastelBlue,
            backgroundImage: photoUrl != null
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null
                ? Text(initial,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pastelBlueDark))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary)),
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
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
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
              child: const Icon(Icons.logout_rounded,
                  size: 17, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Clock card — real Firestore state ────────────────────────────────────
  Widget _buildClockCard() {
    // Day complete — clocked in and out
    if (_clockedOut) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day complete!',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Your attendance is marked for today.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    if (_clockInTime != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Clocked in at ${_fmtTimestamp(_clockInTime!)}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textHint),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.done_all_rounded,
                    color: AppColors.mintDark, size: 26),
              ),
            ],
          ),
        ),
      );
    }

    // Clocked in — show elapsed
    if (_clockedIn) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You\'re clocked in',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mintDark)),
                    const SizedBox(height: 4),
                    Text(
                      'Time elapsed: ${_elapsed()}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color:
                              AppColors.mintDark.withOpacity(0.7)),
                    ),
                    if (_clockInTime != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Since ${_fmtTimestamp(_clockInTime!)}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mintDark
                                .withOpacity(0.6)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.mintDark,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.lock_clock_rounded,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
      );
    }

    // Not clocked in — redirect hint (clock-in is on Attendance tab)
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.pastelBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not clocked in',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pastelBlueDark)),
                  const SizedBox(height: 4),
                  Text(
                    'Go to Attendance tab to clock in.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.pastelBlueDark
                            .withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.pastelBlueDark,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.fingerprint_rounded,
                  color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick stats — real Firestore streams ──────────────────────────────────
  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<Map<String, int>>(
        stream: _pollStatsStream,
        builder: (context, pollSnap) {
          return StreamBuilder<int>(
            stream: _streakStream,
            builder: (context, streakSnap) {
              // Polls voted chip
              final pollData =
                  pollSnap.data ?? {'voted': 0, 'total': 0};
              final voted = pollData['voted'] ?? 0;
              final total = pollData['total'] ?? 0;
              final pollLabel =
                  total == 0 ? 'No polls' : '$voted/$total';

              // Streak chip
              final streak = streakSnap.data ?? 0;
              final streakLabel =
                  streak == 0 ? '0 days' : '$streak days 🔥';

              // Days present this week
              final weekDates =
                  _weekDays.map((d) => _dateStr(d)).toList();
              int daysPresent = 0;
              for (final date in weekDates) {
                if (_weekRecords[date]?['clockedIn'] == true) {
                  daysPresent++;
                }
              }

              return Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'Days this week',
                      value: '$daysPresent/5',
                      icon: Icons.calendar_today_rounded,
                      color: AppColors.lavender,
                      textColor: AppColors.lavenderDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      label: 'Update streak',
                      value: streakLabel,
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.peach,
                      textColor: AppColors.peachDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      label: 'Polls voted',
                      value: pollLabel,
                      icon: Icons.how_to_vote_rounded,
                      color: AppColors.mint,
                      textColor: AppColors.mintDark,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Section title ─────────────────────────────────────────────────────────
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

  // ── Org card — unchanged (uses widget.org model) ──────────────────────────
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
                        fontSize: 12,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
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

  // ── Week strip — real Firestore data ──────────────────────────────────────
  Widget _buildWeekStrip() {
    const dayLabels = ['M', 'T', 'W', 'T', 'F'];
    final weekDays = _weekDays;
    final weekDates = weekDays.map((d) => _dateStr(d)).toList();
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon … 4=Fri

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
            final isToday = i == todayIndex;
            final record = _weekRecords[weekDates[i]];
            final present =
                record != null && record['clockedIn'] == true;
            final clockedOut =
                present && record!['clockedOut'] == true;

            // Show clock-in time under the dot when present
            String subLabel = '—';
            if (present && record!['clockInTime'] != null) {
              final ts =
                  record['clockInTime'] as Timestamp;
              final tod =
                  TimeOfDay.fromDateTime(ts.toDate());
              final h = tod.hour == 0
                  ? 12
                  : tod.hour > 12
                      ? tod.hour - 12
                      : tod.hour;
              final m =
                  tod.minute.toString().padLeft(2, '0');
              subLabel = '$h:$m';
            }

            // Cell colour logic
            Color cellColor;
            Color iconColor;
            if (isToday && present) {
              cellColor = AppColors.mint;
              iconColor = AppColors.mintDark;
            } else if (isToday) {
              cellColor = AppColors.pastelBlue;
              iconColor = AppColors.pastelBlueDark;
            } else if (present && clockedOut) {
              cellColor = AppColors.mint;
              iconColor = AppColors.mintDark;
            } else if (present) {
              cellColor = AppColors.pastelBlue;
              iconColor = AppColors.pastelBlueDark;
            } else {
              cellColor = AppColors.surface;
              iconColor = AppColors.textHint;
            }

            return Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Text(dayLabels[i],
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
                        color: cellColor,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: isToday
                            ? Border.all(
                                color:
                                    AppColors.pastelBlueDark,
                                width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: present
                            ? Icon(
                                clockedOut
                                    ? Icons.done_all_rounded
                                    : Icons.check_rounded,
                                size: 16,
                                color: iconColor)
                            : Text('—',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color:
                                        AppColors.textHint)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: present
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

  // ── Timestamp formatter ───────────────────────────────────────────────────
  String _fmtTimestamp(Timestamp ts) {
    final tod = TimeOfDay.fromDateTime(ts.toDate());
    final h = tod.hour == 0
        ? 12
        : tod.hour > 12
            ? tod.hour - 12
            : tod.hour;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

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
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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