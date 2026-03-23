import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatefulWidget {
  final String orgId;
  const InsightsScreen({super.key, this.orgId = ''});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  // ── Touch state ────────────────────────────────────────────────────────────
  int _touchedAttendanceIndex = -1;
  int _touchedPollIndex = -1;
  int _touchedHoursIndex = -1;

  // ── Loading ────────────────────────────────────────────────────────────────
  bool _loading = true;

  final _db = FirebaseFirestore.instance;

  // ── Working hours ──────────────────────────────────────────────────────────
  TimeOfDay _workStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 18, minute: 0);

  // ── Summary metrics ────────────────────────────────────────────────────────
  double _attendanceRate = 0;
  double _avgHoursPerDay = 0;
  double _pollTurnout = 0;
  double _onTimeRate = 0;
  int _staffCount = 0;

  // ── Attendance donut (percentage points, not fractions) ───────────────────
  double _presentPct = 0;
  double _latePct = 0;
  double _absentPct = 0;

  // ── Bar chart ──────────────────────────────────────────────────────────────
  List<_BarData> _weeklyHours = [];

  // ── Streaks ────────────────────────────────────────────────────────────────
  List<_StreakData> _streaks = [];

  // ── Polls ──────────────────────────────────────────────────────────────────
  List<_PollStat> _polls = [];

  // ── Performance radar scores (0–100) ──────────────────────────────────────
  double _radarAttendance = 0;
  double _radarPunctuality = 0;
  double _radarUpdates = 0;
  double _radarPolls = 0;
  double _radarHours = 0;

  // ── Week helpers ───────────────────────────────────────────────────────────
  late final List<DateTime> _weekDays;
  late final List<String> _weekDates;

  @override
  void initState() {
    super.initState();
    _setupWeek();
    _loadData();
  }

  void _setupWeek() {
    final now = DateTime.now();
    final mon = now.subtract(Duration(days: now.weekday - 1));
    _weekDays = List.generate(5, (i) => mon.add(Duration(days: i)));
    _weekDates = _weekDays.map(_dateStr).toList();
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Master loader ──────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    if (widget.orgId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);

    try {
      await Future.wait([
        _loadOrgHours(),
        _loadAttendanceAndStreaks(),
        _loadPolls(),
      ]);
    } catch (e) {
      debugPrint('InsightsScreen._loadData error: $e');
    }

    setState(() => _loading = false);
  }

  // ── 1. Org working hours ───────────────────────────────────────────────────
  Future<void> _loadOrgHours() async {
    final doc = await _db
        .collection('organizations')
        .doc(widget.orgId)
        .get();
    final data = doc.data();
    if (data == null) return;
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

  // ── 2. Attendance records + member streaks ─────────────────────────────────
  Future<void> _loadAttendanceAndStreaks() async {
    // --- Members ---
    final membersSnap = await _db
        .collection('organizations')
        .doc(widget.orgId)
        .collection('members')
        .where('role', isEqualTo: 'staff')
        .get();

    _staffCount = membersSnap.docs.length;
    if (_staffCount == 0) return;

    // --- Attendance records for each working day ---
    final today = DateTime.now();
    final workStartMinutes = _workStart.hour * 60 + _workStart.minute;
    const lateGraceMinutes = 15;

    int workingDaysElapsed = 0;
    int totalPresent = 0;
    int totalLate = 0;
    int totalClockIns = 0;
    double totalHoursAll = 0;
    int totalHoursCount = 0;

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final barDataTemp = <_BarData>[];

    // Fetch each day's records concurrently
    final dayRecordFutures = _weekDates.map((dateStr) => _db
        .collection('organizations')
        .doc(widget.orgId)
        .collection('attendance')
        .doc(dateStr)
        .collection('records')
        .get());
    final daySnaps = await Future.wait(dayRecordFutures);

    for (int i = 0; i < _weekDates.length; i++) {
      final dayDate = _weekDays[i];
      // Only count elapsed days (Monday through today)
      final dayIsElapsed =
          !dayDate.isAfter(DateTime(today.year, today.month, today.day));
      if (dayIsElapsed) workingDaysElapsed++;

      final records = daySnaps[i].docs.map((d) => d.data()).toList();

      double dayHours = 0;
      int dayHoursCount = 0;

      for (final r in records) {
        if (r['clockedIn'] != true) continue;
        totalPresent++;
        totalClockIns++;

        // Late check
        final ciTs = r['clockInTime'] as Timestamp?;
        if (ciTs != null) {
          final ciTod = TimeOfDay.fromDateTime(ciTs.toDate());
          final ciMin = ciTod.hour * 60 + ciTod.minute;
          if (ciMin > workStartMinutes + lateGraceMinutes) totalLate++;
        }

        // Hours
        final ciTs2 = r['clockInTime'] as Timestamp?;
        final coTs = r['clockOutTime'] as Timestamp?;
        if (ciTs2 != null && coTs != null) {
          final h = coTs
                  .toDate()
                  .difference(ciTs2.toDate())
                  .inMinutes /
              60.0;
          if (h > 0 && h < 24) {
            dayHours += h;
            dayHoursCount++;
            totalHoursAll += h;
            totalHoursCount++;
          }
        }
      }

      // Bar: average hours worked that day across all staff who clocked in
      final avgDay = dayHoursCount > 0
          ? double.parse((dayHours / dayHoursCount).toStringAsFixed(1))
          : 0.0;
      barDataTemp.add(_BarData(day: dayLabels[i], hours: avgDay));
    }

    _weeklyHours = barDataTemp;

    // --- Aggregate metrics ---
    final totalPossible = _staffCount * workingDaysElapsed;

    _attendanceRate =
        totalPossible > 0 ? totalPresent / totalPossible : 0;
    _onTimeRate = totalClockIns > 0
        ? (totalClockIns - totalLate) / totalClockIns
        : 0;
    _avgHoursPerDay =
        totalHoursCount > 0 ? totalHoursAll / totalHoursCount : 0;

    // Donut percentages (out of 100)
    _presentPct = totalPossible > 0
        ? ((totalPresent - totalLate) / totalPossible * 100)
            .clamp(0, 100)
        : 0;
    _latePct = totalPossible > 0
        ? (totalLate / totalPossible * 100).clamp(0, 100)
        : 0;
    _absentPct = (100 - _presentPct - _latePct).clamp(0, 100);

    // --- Streaks from today's updates ---
    final todayStart = DateTime(today.year, today.month, today.day);
    final updatesSnap = await _db
        .collection('organizations')
        .doc(widget.orgId)
        .collection('updates')
        .where('submittedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .get();

    // Build uid -> streak map
    final Map<String, int> streakMap = {};
    int membersSubmittedToday = 0;
    for (final doc in updatesSnap.docs) {
      final d = doc.data();
      final uid = d['uid'] as String?;
      final streak = (d['streak'] as num?)?.toInt() ?? 0;
      if (uid != null && !streakMap.containsKey(uid)) {
        streakMap[uid] = streak;
        membersSubmittedToday++;
      }
    }

    // Build sorted streak list from members
    final rawStreaks = <_StreakData>[];
    for (final memberDoc in membersSnap.docs) {
      final mData = memberDoc.data() as Map<String, dynamic>;
      final name = (mData['name'] ?? '').toString();
      final role = (mData['role'] ?? '').toString();
      final streak = streakMap[memberDoc.id] ?? 0;
      rawStreaks.add(_StreakData(name: name, role: role, streak: streak, pct: 0));
    }
    rawStreaks.sort((a, b) => b.streak.compareTo(a.streak));
    final maxStreak =
        rawStreaks.isNotEmpty ? rawStreaks.first.streak : 1;
    _streaks = rawStreaks.take(4).map((s) => _StreakData(
          name: s.name,
          role: s.role,
          streak: s.streak,
          pct: maxStreak > 0 ? s.streak / maxStreak : 0,
        )).toList();

    // --- Radar scores ---
    _radarAttendance = (_attendanceRate * 100).clamp(0, 100);
    _radarPunctuality = (_onTimeRate * 100).clamp(0, 100);
    // Updates: fraction of staff who submitted today
   _radarUpdates = (_staffCount > 0
        ? membersSubmittedToday / _staffCount * 100
        : 0.0)
    .clamp(0.0, 100.0);
    // Avg hours target = workEnd - workStart
    final targetHours = (_workEnd.hour * 60 + _workEnd.minute -
            (_workStart.hour * 60 + _workStart.minute)) /
        60.0;
    _radarHours =
     (targetHours > 0 ? _avgHoursPerDay / targetHours * 100 : 0.0)
        .clamp(0.0, 100.0);
  }

  // ── 3. Polls ───────────────────────────────────────────────────────────────
  Future<void> _loadPolls() async {
    final snap = await _db
        .collection('organizations')
        .doc(widget.orgId)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    _polls = snap.docs.map((doc) {
      final d = doc.data();
      final total = (d['total'] as num?)?.toInt() ?? 0;
      final members = _staffCount > 0 ? _staffCount : 1;
      return _PollStat(
        question: (d['question'] ?? '') as String,
        votes: total,
        pct: (total / members).clamp(0, 1),
        isActive: d['isActive'] as bool? ?? false,
      );
    }).toList();

    final activePolls = _polls.where((p) => p.isActive).toList();
    if (activePolls.isNotEmpty) {
      _pollTurnout = activePolls
              .map((p) => p.pct)
              .reduce((a, b) => a + b) /
          activePolls.length;
    } else if (_polls.isNotEmpty) {
      _pollTurnout =
          _polls.map((p) => p.pct).reduce((a, b) => a + b) / _polls.length;
    }
    _radarPolls = (_pollTurnout * 100).clamp(0, 100);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.pastelBlueDark))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(24),
                children: [
                  _buildPageHeader(),
                  const SizedBox(height: 20),
                  _buildMetricGrid(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Attendance Breakdown'),
                  const SizedBox(height: 4),
                  Text('Tap slices to explore',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textHint)),
                  const SizedBox(height: 12),
                  _buildAttendanceDonut(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Avg Daily Hours (per staff)'),
                  const SizedBox(height: 4),
                  Text('Tap bars to inspect',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textHint)),
                  const SizedBox(height: 12),
                  _buildWeeklyBarChart(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Update Streaks'),
                  const SizedBox(height: 12),
                  _buildStreakList(),
                  if (_polls.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSectionTitle('Poll Participation'),
                    const SizedBox(height: 4),
                    Text('Tap slices to explore',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textHint)),
                    const SizedBox(height: 12),
                    _buildPollDonut(),
                  ],
                  const SizedBox(height: 28),
                  _buildSectionTitle('Performance Overview'),
                  const SizedBox(height: 12),
                  _buildPerformanceRadar(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Page Header ────────────────────────────────────────────────────────────
  Widget _buildPageHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Insights',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3)),
            Text('This week\'s summary',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: _loadData,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('This Week',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));

  // ── Metric Grid ────────────────────────────────────────────────────────────
  Widget _buildMetricGrid() {
    final weekHours = _weeklyHours.fold(0.0, (s, b) => s + b.hours);

    final metrics = [
      _Metric(
          label: 'Attendance Rate',
          value: '${(_attendanceRate * 100).toInt()}%',
          color: AppColors.mint,
          textColor: AppColors.mintDark,
          icon: Icons.people_outline_rounded),
      _Metric(
          label: 'Avg Hours/Day',
          value: '${_avgHoursPerDay.toStringAsFixed(1)}h',
          color: AppColors.pastelBlue,
          textColor: AppColors.pastelBlueDark,
          icon: Icons.timer_outlined),
      _Metric(
          label: 'Poll Turnout',
          value: '${(_pollTurnout * 100).toInt()}%',
          color: AppColors.lavender,
          textColor: AppColors.lavenderDark,
          icon: Icons.how_to_vote_rounded),
      _Metric(
          label: 'On Time Rate',
          value: '${(_onTimeRate * 100).toInt()}%',
          color: AppColors.peach,
          textColor: AppColors.peachDark,
          icon: Icons.schedule_rounded),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      childAspectRatio: 1.6,
      physics: const NeverScrollableScrollPhysics(),
      children: metrics.map((m) => _MetricCard(metric: m)).toList(),
    );
  }

  // ── Attendance Donut ───────────────────────────────────────────────────────
  Widget _buildAttendanceDonut() {
    final hasData = _presentPct + _latePct + _absentPct > 0;
    final sections = [
      _DonutSection(
          label: 'Present', value: _presentPct, color: AppColors.mintDark),
      _DonutSection(
          label: 'Late', value: _latePct, color: AppColors.pastelBlueDark),
      _DonutSection(
          label: 'Absent', value: _absentPct, color: AppColors.peachDark),
    ];
    final touched = _touchedAttendanceIndex;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: !hasData
          ? _emptyState('No attendance data for this week yet')
          : SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                _touchedAttendanceIndex = -1;
                                return;
                              }
                              _touchedAttendanceIndex = response
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        centerSpaceRadius: 52,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                        sections: List.generate(sections.length, (i) {
                          final isTouched = i == touched;
                          final s = sections[i];
                          return PieChartSectionData(
                            color: s.color,
                            value: s.value,
                            title:
                                isTouched ? '${s.value.toInt()}%' : '',
                            radius: isTouched ? 62 : 50,
                            titleStyle: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            badgeWidget: isTouched
                                ? _PieBadge(
                                    label: s.label, color: s.color)
                                : null,
                            badgePositionPercentageOffset: 1.35,
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _centerLabel(
                            touched >= 0 ? sections[touched] : null,
                            '${(_attendanceRate * 100).toInt()}%',
                            'Attendance'),
                        const SizedBox(height: 20),
                        ...sections.asMap().entries.map((e) =>
                            _LegendItem(
                              label: e.value.label,
                              value: '${e.value.value.toInt()}%',
                              color: e.value.color,
                              isActive:
                                  touched == -1 || touched == e.key,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _centerLabel(_DonutSection? s, String defaultValue,
      String defaultLabel) {
    if (s == null) {
      return Column(children: [
        Text(defaultValue,
            style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        Text(defaultLabel,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textSecondary)),
      ]);
    }
    return Column(children: [
      Text('${s.value.toInt()}%',
          style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: s.color)),
      Text(s.label,
          style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }

  // ── Weekly Hours Bar Chart ─────────────────────────────────────────────────
  Widget _buildWeeklyBarChart() {
    final allZero = _weeklyHours.every((b) => b.hours == 0);
    final maxH = allZero
        ? 10.0
        : _weeklyHours.map((d) => d.hours).reduce((a, b) => a > b ? a : b);
    final touched = _touchedHoursIndex;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (touched >= 0 && !allZero)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: _weeklyHours[touched].day,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pastelBlueDark),
                  ),
                  TextSpan(
                    text: _weeklyHours[touched].hours == 0
                        ? '  No data'
                        : '  ${_weeklyHours[touched].hours}h avg',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary),
                  ),
                ]),
              ),
            ),
          if (allZero)
            _emptyState('No clocked hours recorded this week yet')
          else
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  maxY: maxH + 1,
                  minY: 0,
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.spot == null) {
                          _touchedHoursIndex = -1;
                          return;
                        }
                        _touchedHoursIndex =
                            response.spot!.touchedBarGroupIndex;
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          AppColors.pastelBlueDark,
                      tooltipRoundedRadius: 8,
                      getTooltipItem:
                          (group, groupIndex, rod, rodIndex) {
                        final h = _weeklyHours[groupIndex].hours;
                        return BarTooltipItem(
                          h == 0 ? 'No data' : '${h}h',
                          GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0xFFEEEEEE), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= _weeklyHours.length)
                            return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weeklyHours[i].day,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: i == touched
                                    ? AppColors.pastelBlueDark
                                    : AppColors.textHint,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                  ),
                  barGroups:
                      List.generate(_weeklyHours.length, (i) {
                    final isTouched = i == touched;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _weeklyHours[i].hours,
                          width: 28,
                          borderRadius: BorderRadius.circular(8),
                          color: isTouched
                              ? AppColors.pastelBlueDark
                              : AppColors.pastelBlue,
                          backDrawRodData:
                              BackgroundBarChartRodData(
                            show: true,
                            toY: maxH + 1,
                            color: AppColors.surface,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Update Streaks ─────────────────────────────────────────────────────────
  Widget _buildStreakList() {
    if (_streaks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: _emptyState('No updates submitted today yet'),
      );
    }

    const medals = ['🥇', '🥈', '🥉'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: _streaks.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: i != _streaks.length - 1
                  ? const Border(
                      bottom: BorderSide(
                          color: AppColors.border, width: 0.8))
                  : null,
            ),
            child: Row(children: [
              SizedBox(
                width: 28,
                child: Text(
                  i < 3 ? medals[i] : '${i + 1}',
                  style: GoogleFonts.inter(
                      fontSize: i < 3 ? 18 : 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Text(
                    s.name.isNotEmpty
                        ? s.name
                            .substring(
                                0,
                                s.name.length >= 2
                                    ? 2
                                    : s.name.length)
                            .toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mintDark),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(s.name,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 6),
                      Text(s.role,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textHint)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: s.pct,
                        minHeight: 6,
                        backgroundColor: AppColors.surface,
                        valueColor: AlwaysStoppedAnimation(
                            i == 0
                                ? AppColors.mintDark
                                : AppColors.pastelBlueDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: i == 0
                      ? AppColors.mint
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: i == 0
                          ? AppColors.mintDark.withOpacity(0.3)
                          : AppColors.border),
                ),
                child: Row(children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 13,
                      color: i == 0
                          ? AppColors.mintDark
                          : AppColors.textHint),
                  const SizedBox(width: 3),
                  Text('${s.streak}d',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: i == 0
                              ? AppColors.mintDark
                              : AppColors.textSecondary)),
                ]),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Poll Participation Donut ───────────────────────────────────────────────
  Widget _buildPollDonut() {
    final displayPolls = _polls.take(5).toList();
    final totalVotes =
        displayPolls.fold(0, (sum, p) => sum + p.votes);
    final touched = _touchedPollIndex;

    final colors = [
      AppColors.lavenderDark,
      AppColors.pastelBlueDark,
      AppColors.mintDark,
      AppColors.peachDark,
      const Color(0xFF9C6FDE),
    ];

    final hasData = totalVotes > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: !hasData
          ? _emptyState('No votes recorded yet')
          : SizedBox(
              height: 200,
              child: Row(children: [
                Expanded(
                  flex: 5,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedPollIndex = -1;
                              return;
                            }
                            _touchedPollIndex = response
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      centerSpaceRadius: 52,
                      sectionsSpace: 3,
                      startDegreeOffset: -90,
                      sections: List.generate(
                          displayPolls.length, (i) {
                        final isTouched = i == touched;
                        final p = displayPolls[i];
                        return PieChartSectionData(
                          color: colors[i % colors.length],
                          value: p.votes.toDouble(),
                          title:
                              isTouched ? '${p.votes}' : '',
                          radius: isTouched ? 62 : 50,
                          titleStyle: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      if (touched == -1) ...[
                        Text('$totalVotes',
                            style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        Text('Total Votes',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color:
                                    AppColors.textSecondary)),
                        const SizedBox(height: 16),
                      ] else ...[
                        Text(
                          '${displayPolls[touched].votes} votes',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors[
                                  touched % colors.length]),
                        ),
                        Text(
                          '${(displayPolls[touched].pct * 100).toInt()}% turnout',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color:
                                  AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                      ],
                      ...List.generate(
                          displayPolls.length, (i) {
                        final p = displayPolls[i];
                        final c = colors[i % colors.length];
                        return Padding(
                          padding: const EdgeInsets.only(
                              bottom: 8),
                          child: Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: (touched == -1 ||
                                        touched == i)
                                    ? c
                                    : c.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.question,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: (touched == -1 ||
                                            touched == i)
                                        ? AppColors
                                            .textPrimary
                                        : AppColors.textHint,
                                    fontWeight: touched == i
                                        ? FontWeight.w600
                                        : FontWeight.w400),
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),
              ]),
            ),
    );
  }

  // ── Performance Radar ──────────────────────────────────────────────────────
  Widget _buildPerformanceRadar() {
    final data = [
      _RadarPoint(label: 'Attendance', score: _radarAttendance),
      _RadarPoint(label: 'Punctuality', score: _radarPunctuality),
      _RadarPoint(label: 'Updates', score: _radarUpdates),
      _RadarPoint(label: 'Polls', score: _radarPolls),
      _RadarPoint(label: 'Hours', score: _radarHours),
    ];

    final allZero = data.every((d) => d.score == 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: allZero
          ? _emptyState('Not enough data for overview yet')
          : Column(children: [
              SizedBox(
                height: 220,
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    radarBackgroundColor:
                        AppColors.pastelBlue.withOpacity(0.15),
                    borderData: FlBorderData(show: false),
                    radarBorderData: const BorderSide(
                        color: AppColors.border, width: 1),
                    gridBorderData: const BorderSide(
                        color: AppColors.border, width: 0.8),
                    tickCount: 4,
                    ticksTextStyle: const TextStyle(
                        fontSize: 0,
                        color: Colors.transparent),
                    tickBorderData: const BorderSide(
                        color: AppColors.border, width: 0.5),
                    getTitle: (index, angle) {
                      final d = data[index];
                      return RadarChartTitle(
                        text:
                            '${d.label}\n${d.score.toInt()}%',
                        angle: 0,
                      );
                    },
                    titleTextStyle: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                    titlePositionPercentageOffset: 0.22,
                    dataSets: [
                      RadarDataSet(
                        fillColor: AppColors.pastelBlueDark
                            .withOpacity(0.18),
                        borderColor: AppColors.pastelBlueDark,
                        borderWidth: 2,
                        entryRadius: 4,
                        dataEntries: data
                            .map((d) =>
                                RadarEntry(value: d.score))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: data.map((d) {
                  return Expanded(
                    child: Column(children: [
                      Text('${d.score.toInt()}%',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pastelBlueDark)),
                      Text(d.label,
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center),
                    ]),
                  );
                }).toList(),
              ),
            ]),
    );
  }

  // ── Empty state helper ─────────────────────────────────────────────────────
  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bar_chart_rounded,
              size: 36, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _PieBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PieBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)
        ],
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isActive;
  const _LegendItem(
      {required this.label,
      required this.value,
      required this.color,
      required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.3,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      ),
    );
  }
}

// ── Metric Card ────────────────────────────────────────────────────────────────

class _Metric {
  final String label, value;
  final Color color, textColor;
  final IconData icon;
  const _Metric(
      {required this.label,
      required this.value,
      required this.color,
      required this.textColor,
      required this.icon});
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: metric.color,
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, size: 18, color: metric.textColor),
          const Spacer(),
          Text(metric.value,
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: metric.textColor,
                  height: 1)),
          const SizedBox(height: 2),
          Text(metric.label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: metric.textColor.withOpacity(0.7))),
        ],
      ),
    );
  }
}

// ── Data Models ──────────────────────────────────────────────────────────────

class _BarData {
  final String day;
  final double hours;
  const _BarData({required this.day, required this.hours});
}

class _StreakData {
  final String name, role;
  final int streak;
  final double pct;
  const _StreakData(
      {required this.name,
      required this.role,
      required this.streak,
      required this.pct});
}

class _PollStat {
  final String question;
  final double pct;
  final int votes;
  final bool isActive;
  const _PollStat(
      {required this.question,
      required this.pct,
      required this.votes,
      this.isActive = false});
}

class _DonutSection {
  final String label;
  final double value;
  final Color color;
  const _DonutSection(
      {required this.label, required this.value, required this.color});
}

class _RadarPoint {
  final String label;
  final double score;
  const _RadarPoint({required this.label, required this.score});
}