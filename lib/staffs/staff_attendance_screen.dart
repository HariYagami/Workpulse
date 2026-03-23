import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:presenceiq/services/org_service.dart';
import 'package:presenceiq/theme/app_theme.dart';
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
  bool _clockedOut = false;
  Timestamp? _clockInTime;
  Timestamp? _clockOutTime;
  bool _loading = true;
  bool _clocking = false;

  // Office location
  double? _officeLat;
  double? _officeLng;
  double _officeRadius = 100;

  // Live location state
  Position? _currentPosition;
  double? _distanceToOffice;
  bool _isWithinRadius = false;
  bool _locationPermissionGranted = false;
  bool _fetchingLocation = false;
  String? _locationError;

  Timer? _locationTimer;
  Timer? _autoClockOutTimer;

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

  // ── Haversine distance (metres) ──────────────────────────────────────────
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _autoClockOutTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 1. Org working hours
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
          _workStart =
              TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
        if (end != null) {
          final p = end.split(':');
          _workEnd =
              TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
      }

      // 2. Office geo-fence
      final locData = await OrgService().getOfficeLocation(widget.org.id);
      if (locData != null) {
        _officeLat = (locData['latitude'] as num).toDouble();
        _officeLng = (locData['longitude'] as num).toDouble();
        _officeRadius =
            (locData['radiusMeters'] as num?)?.toDouble() ?? 100;
      }

      // 3. Batch-fetch week attendance
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

      // 4. Today's state
      final todayData = _weekRecords[_todayStr];
      if (todayData != null) {
        _clockedIn = todayData['clockedIn'] == true;
        _clockedOut = todayData['clockedOut'] == true;
        _clockInTime = todayData['clockInTime'] as Timestamp?;
        _clockOutTime = todayData['clockOutTime'] as Timestamp?;
      }
    } catch (_) {}

    setState(() => _loading = false);

    await _initLocationTracking();
    _scheduleAutoClockOut();
  }

  // ── Location tracking ─────────────────────────────────────────────────────
  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationError = 'Location services are disabled.');
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() {
        _locationPermissionGranted = false;
        _locationError = 'Location permission denied.';
      });
      return;
    }

    setState(() {
      _locationPermissionGranted = true;
      _locationError = null;
    });

    await _fetchLocation();
    _locationTimer?.cancel();
    _locationTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _fetchLocation());
  }

  Future<void> _fetchLocation() async {
    if (_fetchingLocation) return;
    _fetchingLocation = true;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      double? dist;
      bool within = false;
      if (_officeLat != null && _officeLng != null) {
        dist = _haversine(
            pos.latitude, pos.longitude, _officeLat!, _officeLng!);
        within = dist <= _officeRadius;
      }
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _distanceToOffice = dist;
          _isWithinRadius = within;
          _locationError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _locationError = 'Could not fetch location.');
      }
    } finally {
      _fetchingLocation = false;
    }
  }

  // ── Auto clock-out ────────────────────────────────────────────────────────
  void _scheduleAutoClockOut() {
    if (_workEnd == null || _clockedOut) return;
    final now = DateTime.now();
    final endToday = DateTime(
        now.year, now.month, now.day, _workEnd!.hour, _workEnd!.minute);
    if (endToday.isAfter(now)) {
      final delay = endToday.difference(now);
      _autoClockOutTimer?.cancel();
      _autoClockOutTimer =
          Timer(delay, () => _clockOut(auto: true));
    }
  }

  // ── Clock In (transaction-guarded) ────────────────────────────────────────
  Future<void> _clockIn() async {
    if (_uid.isEmpty || _clocking || !_isWithinRadius || _clockedIn) return;
    setState(() => _clocking = true);

    try {
      final user = _auth.currentUser;
      final now = Timestamp.now();
      final ref = _db
          .collection('organizations')
          .doc(widget.org.id)
          .collection('attendance')
          .doc(_todayStr)
          .collection('records')
          .doc(_uid);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          throw Exception('already_clocked_in');
        }
        tx.set(ref, {
          'uid': _uid,
          'name': user?.displayName ?? '',
          'clockedIn': true,
          'clockedOut': false,
          'clockInTime': now,
          'clockInLat': _currentPosition?.latitude,
          'clockInLng': _currentPosition?.longitude,
          'date': _todayStr,
        });
      });

      _weekRecords[_todayStr] = {
        'clockedIn': true,
        'clockedOut': false,
        'clockInTime': now,
      };

      setState(() {
        _clockedIn = true;
        _clockedOut = false;
        _clockInTime = now;
      });

      _scheduleAutoClockOut();
    } on Exception catch (e) {
      if (e.toString().contains('already_clocked_in')) {
        await _loadData();
      }
    } catch (_) {}

    if (mounted) setState(() => _clocking = false);
  }

  // ── Clock Out ─────────────────────────────────────────────────────────────
  Future<void> _clockOut({bool auto = false}) async {
    if (_uid.isEmpty || _clockedOut || !_clockedIn) return;
    try {
      final now = Timestamp.now();
      await _db
          .collection('organizations')
          .doc(widget.org.id)
          .collection('attendance')
          .doc(_todayStr)
          .collection('records')
          .doc(_uid)
          .update({
        'clockedOut': true,
        'clockOutTime': now,
        'autoClockOut': auto,
      });

      _weekRecords[_todayStr]?['clockedOut'] = true;
      _weekRecords[_todayStr]?['clockOutTime'] = now;

      if (mounted) {
        setState(() {
          _clockedOut = true;
          _clockOutTime = now;
        });
      }
    } catch (_) {}
  }

  // ── Time helpers ──────────────────────────────────────────────────────────
  bool get _isWithinWorkingHours {
    if (_workStart == null || _workEnd == null) return false;
    final now = TimeOfDay.now();
    final nowM = now.hour * 60 + now.minute;
    return nowM >= (_workStart!.hour * 60 + _workStart!.minute) &&
        nowM <= (_workEnd!.hour * 60 + _workEnd!.minute);
  }

  bool get _isBeforeWorkingHours {
    if (_workStart == null) return false;
    final now = TimeOfDay.now();
    return (now.hour * 60 + now.minute) 
        < (_workStart!.hour * 60 + _workStart!.minute);
  }

  bool get _isAfterWorkingHours {
    if (_workEnd == null) return false;
    final now = TimeOfDay.now();
    return (now.hour * 60 + now.minute) >
        (_workEnd!.hour * 60 + _workEnd!.minute);
  }

  String _formatTime(TimeOfDay t) {
    final hour =
        t.hour == 0 ? 12 : t.hour > 12 ? t.hour - 12 : t.hour;
    final min = t.minute.toString().padLeft(2, '0');
    return '$hour:$min ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  String _formatTimestamp(Timestamp ts) =>
      _formatTime(TimeOfDay.fromDateTime(ts.toDate()));

  // ── Build ─────────────────────────────────────────────────────────────────
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
                    _buildLocationCard(),
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

  // ── Working hours card ────────────────────────────────────────────────────
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
          Text(
              '${_formatTime(_workStart!)}  –  ${_formatTime(_workEnd!)}',
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

  // ── Live location card ────────────────────────────────────────────────────
  Widget _buildLocationCard() {
    if (!_locationPermissionGranted) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.peach.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.location_off_rounded,
              color: AppColors.peachDark, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _locationError ??
                  'Location permission required to clock in.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.peachDark),
            ),
          ),
          GestureDetector(
            onTap: _initLocationTracking,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.peachDark,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('Retry',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ]),
      );
    }

    if (_officeLat == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.business_rounded,
              color: AppColors.textHint, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Office location not configured by admin.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
        ]),
      );
    }

    if (_currentPosition == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.pastelBlueDark)),
          const SizedBox(width: 12),
          Text('Fetching your location…',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );
    }

    final dist = _distanceToOffice;
    final distLabel = dist == null
        ? '—'
        : dist < 1000
            ? '${dist.toStringAsFixed(0)} m away'
            : '${(dist / 1000).toStringAsFixed(2)} km away';

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: _isWithinRadius
            ? AppColors.mint.withOpacity(0.35)
            : AppColors.peach.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isWithinRadius
              ? AppColors.mintDark.withOpacity(0.4)
              : AppColors.peachDark.withOpacity(0.4),
        ),
      ),
      child: Row(children: [
        Icon(
          _isWithinRadius
              ? Icons.location_on_rounded
              : Icons.location_searching_rounded,
          color: _isWithinRadius
              ? AppColors.mintDark
              : AppColors.peachDark,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isWithinRadius
                      ? 'You are at the office ✓'
                      : 'Outside office radius',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isWithinRadius
                          ? AppColors.mintDark
                          : AppColors.peachDark),
                ),
                Text(distLabel,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _isWithinRadius
                            ? AppColors.mintDark
                            : AppColors.peachDark)),
              ]),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isWithinRadius
                ? AppColors.mintDark
                : AppColors.peachDark,
          ),
        ),
        const SizedBox(width: 4),
        Text('Live',
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _isWithinRadius
                    ? AppColors.mintDark
                    : AppColors.peachDark)),
      ]),
    );
  }

  // ── Clock-in card ─────────────────────────────────────────────────────────
  Widget _buildClockInCard() {
    // Guard 1: Day complete — clocked in AND clocked out
    if (_clockedOut) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          const Icon(Icons.done_all_rounded,
              color: AppColors.textSecondary, size: 40),
          const SizedBox(height: 12),
          Text('Day Complete',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          if (_clockInTime != null)
            Text(
                'In: ${_formatTimestamp(_clockInTime!)}  •  Out: ${_clockOutTime != null ? _formatTimestamp(_clockOutTime!) : '—'}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Attendance marked for today',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mintDark)),
          ),
        ]),
      );
    }

    // Guard 2: Clocked in, waiting for auto clock-out — no button shown
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
          if (_workEnd != null) ...[
            const SizedBox(height: 6),
            Text('Auto clock-out at ${_formatTime(_workEnd!)}',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.mintDark)),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.mintDark.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded,
                    size: 13, color: AppColors.mintDark),
                const SizedBox(width: 6),
                Text('One attendance per day — you\'re all set!',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mintDark)),
              ],
            ),
          ),
        ]),
      );
    }

    // Guard 3: No working hours set
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

    // Guard 4: Before working hours
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

    // Guard 5: After working hours, never clocked in = absent
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

    // Active window — clock-in button gated by location
    final canClockIn =
        _isWithinRadius && _locationPermissionGranted;

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
          decoration: BoxDecoration(
            color:
                canClockIn ? AppColors.mint : AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.fingerprint_rounded,
              color: canClockIn
                  ? AppColors.mintDark
                  : AppColors.textHint,
              size: 32),
        ),
        const SizedBox(height: 14),
        Text('Ready to clock in?',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          canClockIn
              ? 'Working hours active · You are at the office'
              : _officeLat == null
                  ? 'Office location not set by admin'
                  : !_locationPermissionGranted
                      ? 'Location permission required'
                      : 'You must be at the office to clock in',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                (canClockIn && !_clocking) ? _clockIn : null,
            child: _clocking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Clock In'),
          ),
        ),
        if (!canClockIn && _distanceToOffice != null) ...[
          const SizedBox(height: 8),
          Text(
            'Move within ${_officeRadius.toInt()} m of the office. '
            'Currently ${_distanceToOffice!.toStringAsFixed(0)} m away.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ]),
    );
  }

  // ── Weekly history ────────────────────────────────────────────────────────
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
        child: Column(
          children: List.generate(5, (i) {
            final isToday = weekDates[i] == _todayStr;
            final isPast = weekDays[i].isBefore(
                DateTime.now().subtract(const Duration(days: 1)));
            final record = _weekRecords[weekDates[i]];
            final present =
                record != null && record['clockedIn'] == true;
            final didClockOut =
                present && record!['clockedOut'] == true;
            final showAbsent =
                !present && (isPast || isToday);

            String timeLabel = '—';
            if (present && record!['clockInTime'] != null) {
              timeLabel = _formatTimestamp(
                  record['clockInTime'] as Timestamp);
              if (didClockOut &&
                  record['clockOutTime'] != null) {
                timeLabel +=
                    ' – ${_formatTimestamp(record['clockOutTime'] as Timestamp)}';
              }
            }

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.pastelBlue.withOpacity(0.15)
                    : null,
                border: i < 4
                    ? const Border(
                        bottom: BorderSide(
                            color: AppColors.border,
                            width: 0.8))
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
                        ? didClockOut
                            ? AppColors.mint
                            : AppColors.pastelBlue
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
                            ? didClockOut
                                ? AppColors.mintDark
                                : AppColors.pastelBlueDark
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