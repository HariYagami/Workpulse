import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatelessWidget {
  final String orgId;
  const InsightsScreen({super.key, this.orgId = ''});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _buildPageHeader(),
          const SizedBox(height: 20),
          _buildMetricGrid(),
          const SizedBox(height: 24),
          _buildSectionTitle('Weekly Hours'),
          const SizedBox(height: 12),
          _buildWeeklyBars(),
          const SizedBox(height: 24),
          _buildSectionTitle('Update Streaks'),
          const SizedBox(height: 12),
          _buildStreakList(),
          const SizedBox(height: 24),
          _buildSectionTitle('Poll Participation'),
          const SizedBox(height: 12),
          _buildPollParticipation(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
      ],
    );
  }

  Widget _buildSectionTitle(String t) {
    return Text(t,
        style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary));
  }

  Widget _buildMetricGrid() {
    final metrics = [
      _Metric(label: 'Attendance Rate', value: '80%',  color: AppColors.mint,       textColor: AppColors.mintDark,       icon: Icons.people_outline_rounded),
      _Metric(label: 'Avg Hours/Week',  value: '41h',  color: AppColors.pastelBlue, textColor: AppColors.pastelBlueDark, icon: Icons.timer_outlined),
      _Metric(label: 'Poll Turnout',    value: '90%',  color: AppColors.lavender,   textColor: AppColors.lavenderDark,   icon: Icons.how_to_vote_rounded),
      _Metric(label: 'On Time Rate',    value: '87%',  color: AppColors.peach,      textColor: AppColors.peachDark,      icon: Icons.schedule_rounded),
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

  Widget _buildWeeklyBars() {
    final data = [
      _BarData(day: 'Mon', hours: 8.5),
      _BarData(day: 'Tue', hours: 9.0),
      _BarData(day: 'Wed', hours: 7.8),
      _BarData(day: 'Thu', hours: 8.9),
      _BarData(day: 'Fri', hours: 8.2),
    ];
    final maxH = data.map((d) => d.hours).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final frac = d.hours / maxH;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Text('${d.hours}h',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pastelBlueDark)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 80 * frac,
                      color: AppColors.pastelBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(d.day,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStreakList() {
    final streaks = [
      _StreakData(name: 'Rahul T',  role: 'Backend Dev',  streak: 12, pct: 1.0),
      _StreakData(name: 'Priya M',  role: 'Developer',    streak: 8,  pct: 0.67),
      _StreakData(name: 'Arjun K',  role: 'Designer',     streak: 5,  pct: 0.42),
      _StreakData(name: 'Sneha R',  role: 'QA Engineer',  streak: 3,  pct: 0.25),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: streaks.asMap().entries.map((e) {
          final s = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: e.key != streaks.length - 1
                  ? const Border(bottom: BorderSide(color: AppColors.border, width: 0.8))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(s.name.substring(0, 2).toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.mintDark)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.pct,
                          minHeight: 5,
                          backgroundColor: AppColors.surface,
                          valueColor: const AlwaysStoppedAnimation(AppColors.mintDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        size: 14, color: AppColors.mintDark),
                    const SizedBox(width: 3),
                    Text('${s.streak}d',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mintDark)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPollParticipation() {
    final polls = [
      _PollStat(question: 'Work arrangement this Friday?', pct: 0.9,  votes: 9),
      _PollStat(question: 'Team lunch day preference?',    pct: 0.8,  votes: 8),
      _PollStat(question: 'Sprint review time slot?',      pct: 1.0,  votes: 10),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: polls.asMap().entries.map((e) {
          final p = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: e.key != polls.length - 1
                  ? const Border(bottom: BorderSide(color: AppColors.border, width: 0.8))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.question,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                    ),
                    const SizedBox(width: 12),
                    Text('${p.votes}/10',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.pastelBlueDark)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.pct,
                    minHeight: 6,
                    backgroundColor: AppColors.surface,
                    valueColor: const AlwaysStoppedAnimation(AppColors.pastelBlueDark),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Metric {
  final String label, value;
  final Color color, textColor;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.color, required this.textColor, required this.icon});
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, size: 18, color: metric.textColor),
          const Spacer(),
          Text(metric.value,
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: metric.textColor, height: 1)),
          const SizedBox(height: 2),
          Text(metric.label,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: metric.textColor.withOpacity(0.7))),
        ],
      ),
    );
  }
}

class _BarData  { final String day; final double hours; const _BarData({required this.day, required this.hours}); }
class _StreakData { final String name, role; final int streak; final double pct; const _StreakData({required this.name, required this.role, required this.streak, required this.pct}); }
class _PollStat  { final String question; final double pct; final int votes; const _PollStat({required this.question, required this.pct, required this.votes}); }