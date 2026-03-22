import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class UpdatesScreen extends StatelessWidget {
  final bool embedded;
  final String orgId;
  const UpdatesScreen({super.key, this.embedded = false, this.orgId = ''});

  final List<_DailyUpdate> _updates = const [
    _DailyUpdate(
      name: 'Priya M',
      role: 'Developer',
      work: 'Completed the login module and started on the dashboard layout.',
      blockers: 'None',
      tomorrow: 'Admin dashboard UI implementation.',
      time: '6:00 PM',
      streak: 8,
      reviewed: true,
    ),
    _DailyUpdate(
      name: 'Arjun K',
      role: 'Designer',
      work: 'Finished UI mockups for poll screen and onboarding screens.',
      blockers: 'Waiting for brand guidelines from client.',
      tomorrow: 'Start on the staff dashboard designs.',
      time: '5:45 PM',
      streak: 5,
      reviewed: false,
    ),
    _DailyUpdate(
      name: 'Rahul T',
      role: 'Backend Dev',
      work: 'Fixed the attendance API bug. Added role-based access middleware.',
      blockers: 'None',
      tomorrow: 'Work on Firestore security rules.',
      time: '5:30 PM',
      streak: 12,
      reviewed: false,
    ),
    _DailyUpdate(
      name: 'Sneha R',
      role: 'QA Engineer',
      work: 'Tested login and onboarding flows. Raised 3 bugs.',
      blockers: 'Need updated test credentials.',
      tomorrow: 'Regression testing on the attendance module.',
      time: '6:10 PM',
      streak: 3,
      reviewed: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Daily Updates'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            if (embedded) ...[
              Text('Daily Updates',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3)),
              Text('Staff work summaries',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
            ],
            _buildSummaryBanner(),
            const SizedBox(height: 20),
            ..._updates.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _UpdateCard(update: u),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBanner() {
    final reviewed = _updates.where((u) => u.reviewed).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Updates',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.lavenderDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$reviewed/${_updates.length} reviewed',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lavenderDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.lavenderDark.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.lavenderDark, size: 28),
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatefulWidget {
  final _DailyUpdate update;

  const _UpdateCard({required this.update});

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.update.reviewed
                ? AppColors.border
                : AppColors.pastelBlueDark.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.update.name.substring(0, 2).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lavenderDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.update.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.update.role,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 12, color: AppColors.mintDark),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.update.streak}d',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mintDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.update.time,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.update.work,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Blockers', widget.update.blockers,
                  AppColors.peach, AppColors.peachDark),
              const SizedBox(height: 8),
              _buildInfoRow('Tomorrow', widget.update.tomorrow,
                  AppColors.pastelBlue, AppColors.pastelBlueDark),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.pastelBlueDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (!widget.update.reviewed)
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.pastelBlueDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Mark Reviewed',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: AppColors.mintDark),
                      const SizedBox(width: 4),
                      Text(
                        'Reviewed',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mintDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyUpdate {
  final String name;
  final String role;
  final String work;
  final String blockers;
  final String tomorrow;
  final String time;
  final int streak;
  final bool reviewed;

  const _DailyUpdate({
    required this.name,
    required this.role,
    required this.work,
    required this.blockers,
    required this.tomorrow,
    required this.time,
    required this.streak,
    required this.reviewed,
  });
}