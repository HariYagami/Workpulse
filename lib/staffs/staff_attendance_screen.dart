import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/organization_model.dart';

class StaffAttendanceScreen extends StatefulWidget {
  final OrganizationModel org;
  const StaffAttendanceScreen({super.key, required this.org});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  TimeOfDay? _workStart;
  TimeOfDay? _workEnd;
  bool _clockedIn = false;
  Timestamp? _clockInTime;
  bool _loading = true;
  bool _clocking = false;

  // ← NEW: store all week records locally — no more per-row FutureBuilders
  final Map<String, Map<String, dynamic>?> _weekRecords = {};

  String get _uid => _auth.currentUser?.uid ?? '';

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _todayStr => _dateStr(DateTime.now());

  List<DateTime> get _weekDays {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(5, (i) => monday.add(Duration(days: i)));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // ── 1. Load org working hours ─────────────────────────────────────────
      final orgDoc = await _db
          .collection('organizations')
          .doc(widget.org.id)
          .get();
      final data = orgDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        final start = data['workingStart'] as String?;
        final end = data['workingEnd'] as String?;
        if (start != null) {
          final p = start.split(':');
          _workStart = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
        if (end != null) {
          final p = end.split(':');
          _workEnd = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
      }

      // ── 2. Batch fetch all 5 week days in parallel ────────────────────────
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

      // ── 3. Set today's clock-in state from fetched data ───────────────────
      final todayData = _weekRecords[_todayStr];
      if (todayData != null) {
        _clockedIn = todayData['clockedIn'] == true;
        _clockInTime = todayData['clockInTime'] as Timestamp?;
      }
    } catch (_) {}

    setState(() => _loading = false);
  }

  bool get _isWithinWorkingHours {
    if (_workStart == null || _workEnd == null) return false;
    final now = TimeOfDay.now();
    final nowM = now.hour * 60 + now.minute;
    final startM = _workStart!.hour * 60 + _workStart!.minute;
    final endM = _workEnd!.hour * 60 + _workEnd!.minute;
    return nowM >= startM && nowM <= endM;
  }

  bool get _isBeforeWorkingHours {
    if (_workStart == null) return false;
    final now = TimeOfDay.now();
    return (now.hour * 60 + now.minute) < (_workStart!.hour * 60 + _workStart!.minute);
  }

  bool get _isAfterWorkingHours {
    if (_workEnd == null) return false;
    final now = TimeOfDay.now();
    return (now.hour * 60 + now.minute) >
        (_workEnd!.hour * 60 + _workEnd!.minute);
  }

  Future<void> _clockIn() async {
    if (_uid.isEmpty || _clocking) return;
    setState(() => _clocking = true);
    try {
      final user = _auth.currentUser;
      final now = Timestamp.now();
      await _db
          .collection('organizations')
          .doc(widget.org.id)
          .collection('attendance')
          .doc(_todayStr)
          .collection('records')
          .doc(_uid)
          .set({
        'uid': _uid,
        'name': user?.displayName ?? '',
        'clockedIn': true,
        'clockInTime': now,
        'date': _todayStr,
      });

      // ← Update local cache so weekly history reflects immediately
      _weekRecords[_todayStr] = {
        'clockedIn': true,
        'clockInTime': now,
      };

      setState(() {
        _clockedIn = true;
        _clockInTime = now;
      });
    } catch (_) {}
    setState(() => _clocking = false);
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour == 0 ? 12 : t.hour > 12 ? t.hour - 12 : t.hour;
    final min = t.minute.toString().padLeft(2, '0');
    return '$hour:$min ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  String _formatTimestamp(Timestamp ts) =>
      _formatTime(TimeOfDay.fromDateTime(ts.toDate()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.mintDark))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Attendance',
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3)),
                    Text('Mark your attendance for today',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    _buildWorkingHoursCard(),
                    const SizedBox(height: 16),
                    _buildClockInCard(),
                    const SizedBox(height: 28),
                    _buildWeeklyHistory(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildWorkingHoursCard() {
    if (_workStart == null || _workEnd == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.peach.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.peachDark, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Working hours haven\'t been set by your admin yet.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.peachDark)),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pastelBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Today's Working Hours",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.pastelBlueDark)),
          const SizedBox(height: 4),
          Text('${_formatTime(_workStart!)}  –  ${_formatTime(_workEnd!)}',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.pastelBlueDark)),
        ]),
        const Spacer(),
        const Icon(Icons.access_time_rounded,
            color: AppColors.pastelBlueDark, size: 28),
      ]),
    );
  }

  Widget _buildClockInCard() {
    if (_clockedIn) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.mintDark, size: 44),
          const SizedBox(height: 12),
          Text("You're Clocked In!",
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mintDark)),
          const SizedBox(height: 4),
          if (_clockInTime != null)
            Text('Clocked in at ${_formatTimestamp(_clockInTime!)}',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.mintDark)),
        ]),
      );
    }

    if (_workStart == null || _workEnd == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          const Icon(Icons.hourglass_empty_rounded,
              color: AppColors.textHint, size: 36),
          const SizedBox(height: 12),
          Text('Waiting for admin to set working hours',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary)),
        ]),
      );
    }

    if (_isBeforeWorkingHours) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          const Icon(Icons.schedule_rounded,
              color: AppColors.textHint, size: 36),
          const SizedBox(height: 12),
          Text("Work hasn't started yet",
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Clock-in opens at ${_formatTime(_workStart!)}',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );
    }

    if (_isAfterWorkingHours) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.peach.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          const Icon(Icons.lock_clock_rounded,
              color: AppColors.peachDark, size: 36),
          const SizedBox(height: 12),
          Text('Working hours have ended',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.peachDark)),
          const SizedBox(height: 6),
          Text('You are marked absent for today',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.peachDark)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fingerprint_rounded,
              color: AppColors.mintDark, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Ready to clock in?',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Working hours are active now',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _clocking ? null : _clockIn,
            child: _clocking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Clock In'),
          ),
        ),
      ]),
    );
  }

  Widget _buildWeeklyHistory() {
    final weekDays = _weekDays;
    final weekDates = weekDays.map((d) => _dateStr(d)).toList();
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('This Week',
          style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        // ← No more FutureBuilder — reads from local _weekRecords map
        child: Column(
          children: List.generate(5, (i) {
            final isToday = weekDates[i] == _todayStr;
            final isPast = weekDays[i]
                .isBefore(DateTime.now().subtract(const Duration(days: 1)));
            final record = _weekRecords[weekDates[i]];
            final present = record != null && record['clockedIn'] == true;
            final showAbsent = !present && (isPast || isToday);

            String timeLabel = '—';
            if (present && record!['clockInTime'] != null) {
              timeLabel = _formatTimestamp(record['clockInTime'] as Timestamp);
            }

            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.pastelBlue.withOpacity(0.15)
                    : null,
                border: i < 4
                    ? const Border(
                        bottom: BorderSide(
                            color: AppColors.border, width: 0.8))
                    : null,
              ),
              child: Row(children: [
                Text(dayLabels[i],
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isToday
                            ? AppColors.pastelBlueDark
                            : AppColors.textPrimary)),
                if (isToday) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.pastelBlueDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Today',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: present
                        ? AppColors.mint
                        : showAbsent
                            ? AppColors.peach.withOpacity(0.45)
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    present
                        ? timeLabel
                        : showAbsent
                            ? 'Absent'
                            : '—',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: present
                            ? AppColors.mintDark
                            : showAbsent
                                ? AppColors.peachDark
                                : AppColors.textHint),
                  ),
                ),
              ]),
            );
          }),
        ),
      ),
    ]);
  }
}