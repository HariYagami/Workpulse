import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/organization_model.dart';

class AttendanceScreen extends StatefulWidget {
  final bool embedded;
  final String orgId;
  const AttendanceScreen({super.key, this.embedded = false, this.orgId = ''});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _db = FirebaseFirestore.instance;

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  bool _loadingHours = true;

  late final List<DateTime> _weekDays;
  late final List<String> _weekDateStrings;

  @override
  void initState() {
    super.initState();
    _setupWeekDays();
    _loadWorkingHours();
  }

  void _setupWeekDays() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    _weekDays = List.generate(5, (i) => monday.add(Duration(days: i)));
    _weekDateStrings = _weekDays.map((d) => _dateStr(d)).toList();
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadWorkingHours() async {
    if (widget.orgId.isEmpty) {
      setState(() => _loadingHours = false);
      return;
    }
    try {
      final doc = await _db.collection('organizations').doc(widget.orgId).get();
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        final start = data['workingStart'] as String?;
        final end = data['workingEnd'] as String?;
        if (start != null) {
          final p = start.split(':');
          _startTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
        if (end != null) {
          final p = end.split(':');
          _endTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
        }
      }
    } catch (_) {}
    setState(() => _loadingHours = false);
  }

  Future<void> _saveWorkingHours() async {
    if (widget.orgId.isEmpty) return;
    await _db.collection('organizations').doc(widget.orgId).update({
      'workingStart':
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'workingEnd':
          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
    });
  }

  String _formatTime(TimeOfDay t) {
    final hour =
        t.hour == 0 ? 12 : t.hour > 12 ? t.hour - 12 : t.hour;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  void _showWorkingHoursSheet() {
    TimeOfDay tempStart = _startTime;
    TimeOfDay tempEnd = _endTime;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Working Hours',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ]),
              const SizedBox(height: 24),
              _TimePickerRow(
                label: 'Start Time',
                time: tempStart,
                onTap: () async {
                  final p = await showTimePicker(
                      context: context, initialTime: tempStart);
                  if (p != null) setSheet(() => tempStart = p);
                },
              ),
              const SizedBox(height: 14),
              _TimePickerRow(
                label: 'End Time',
                time: tempEnd,
                onTap: () async {
                  final p = await showTimePicker(
                      context: context, initialTime: tempEnd);
                  if (p != null) setSheet(() => tempEnd = p);
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _startTime = tempStart;
                      _endTime = tempEnd;
                    });
                    await _saveWorkingHours();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Working Hours'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orgId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: Text('No organization selected.')),
      );
    }

    final weekFilter = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_rounded,
            size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('This Week',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary)),
      ]),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Attendance'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: weekFilter)
              ],
            ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('organizations')
              .doc(widget.orgId)
              .collection('members')
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting ||
                _loadingHours) {
              return const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.pastelBlueDark));
            }

            final members = (snap.data?.docs ?? [])
                .map((d) => OrgMember.fromFirestore(d))
                .where((m) => m.role == 'staff')
                .toList();

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.embedded) ...[
                  Row(children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attendance',
                              style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3)),
                          Text('Weekly hours per staff',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ]),
                    const Spacer(),
                    weekFilter,
                  ]),
                  const SizedBox(height: 20),
                ],
                _buildWorkingHoursCard(),
                const SizedBox(height: 20),
                _buildSummaryRow(members),
                const SizedBox(height: 24),
                _buildDayHeaders(),
                const SizedBox(height: 12),
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('No staff members yet.',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textHint)),
                    ),
                  )
                else
                  ...members.map((m) => _MemberAttendanceCard(
                        member: m,
                        orgId: widget.orgId,
                        weekDateStrings: _weekDateStrings,
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkingHoursCard() {
    return GestureDetector(
      onTap: _showWorkingHoursSheet,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pastelBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time_rounded,
                color: AppColors.pastelBlueDark, size: 20),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Working Hours',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(
                '${_formatTime(_startTime)}  –  ${_formatTime(_endTime)}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('Edit',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
        ]),
      ),
    );
  }

  Widget _buildSummaryRow(List<OrgMember> members) {
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Staff Members',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.mintDark)),
            const SizedBox(height: 4),
            Text('${members.length}',
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mintDark)),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.pastelBlue,
              borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Start Time',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.pastelBlueDark)),
            const SizedBox(height: 4),
            Text(_formatTime(_startTime),
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pastelBlueDark)),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('End Time',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.peachDark)),
            const SizedBox(height: 4),
            Text(_formatTime(_endTime),
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.peachDark)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildDayHeaders() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    return Row(children: [
      const SizedBox(width: 130),
      ...days.map((d) => Expanded(
            child: Center(
              child: Text(d,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint)),
            ),
          )),
    ]);
  }
}

// ─── Member Attendance Card ───────────────────────────────────────────────────

class _MemberAttendanceCard extends StatelessWidget {
  final OrgMember member;
  final String orgId;
  final List<String> weekDateStrings;

  const _MemberAttendanceCard({
    required this.member,
    required this.orgId,
    required this.weekDateStrings,
  });

  Future<List<Map<String, dynamic>?>> _fetchWeekAttendance() async {
    final db = FirebaseFirestore.instance;
    final results = <Map<String, dynamic>?>[];
    for (final dateStr in weekDateStrings) {
      try {
        final doc = await db
            .collection('organizations')
            .doc(orgId)
            .collection('attendance')
            .doc(dateStr)
            .collection('records')
            .doc(member.uid)
            .get();
        results.add(doc.exists ? doc.data() : null);
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }

  String _clockInLabel(Map<String, dynamic> data) {
    final ts = data['clockInTime'] as Timestamp?;
    if (ts == null) return '✓';
    final dt = ts.toDate();
    final tod = TimeOfDay.fromDateTime(dt);
    final hour =
        tod.hour == 0 ? 12 : tod.hour > 12 ? tod.hour - 12 : tod.hour;
    final min = tod.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: _fetchWeekAttendance(),
      builder: (context, snap) {
        final attendance =
            snap.data ?? List<Map<String, dynamic>?>.filled(5, null);
        final isLoading =
            snap.connectionState == ConnectionState.waiting;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(member.initials,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mintDark)),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                      Text(member.role,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              ...List.generate(5, (i) {
                final a = attendance[i];
                final present = a?['clockedIn'] == true;
                final label =
                    isLoading ? '…' : (present ? _clockInLabel(a!) : '—');

                return Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLoading
                            ? AppColors.surface
                            : present
                                ? AppColors.mint
                                : AppColors.peach.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isLoading
                              ? AppColors.textHint
                              : present
                                  ? AppColors.mintDark
                                  : AppColors.peachDark,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Time Picker Row ──────────────────────────────────────────────────────────

class _TimePickerRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerRow({
    required this.label,
    required this.time,
    required this.onTap,
  });

  String _fmt(TimeOfDay t) {
    final hour =
        t.hour == 0 ? 12 : t.hour > 12 ? t.hour - 12 : t.hour;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          const Spacer(),
          Text(_fmt(time),
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.pastelBlueDark)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textHint, size: 18),
        ]),
      ),
    );
  }
}