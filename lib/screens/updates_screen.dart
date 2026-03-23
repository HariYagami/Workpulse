import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/updates_service.dart';

class UpdatesScreen extends StatelessWidget {
  final bool embedded;
  final String orgId;
  final int memberCount;

  const UpdatesScreen({
    super.key,
    this.embedded = false,
    required this.orgId,
    this.memberCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final service = UpdatesService();
    final currentUid = service.currentUid;

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
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: service.streamTodayUpdates(orgId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final updates = snapshot.data ?? [];
            final reviewed =
                updates.where((u) => u['reviewed'] == true).length;

            return ListView(
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
                _buildSummaryBanner(reviewed, updates.length),
                const SizedBox(height: 20),
                if (updates.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded,
                              size: 44, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          Text('No updates submitted yet today',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ...updates.map((u) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UpdateCard(
                          update: u,
                          orgId: orgId,
                          currentUid: currentUid,
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(int reviewed, int total) {
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
                Text("Today's Updates",
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.lavenderDark,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('$reviewed/$total reviewed',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lavenderDark)),
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

// ─── Update Card ──────────────────────────────────────────────────────────────

class _UpdateCard extends StatefulWidget {
  final Map<String, dynamic> update;
  final String orgId;
  final String currentUid;

  const _UpdateCard({
    required this.update,
    required this.orgId,
    required this.currentUid,
  });

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  bool _expanded = false;
  bool _marking = false;
  final _service = UpdatesService();

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final uid = (u['uid'] ?? '') as String;
    final isMe = uid == widget.currentUid;
    final displayName = (u['name'] ?? '?') as String;
    final name = isMe ? 'You' : displayName;
    final role = (u['role'] ?? '') as String;
    final work = (u['work'] ?? '') as String;
    final blockers = (u['blockers'] ?? 'None') as String;
    final tomorrow = (u['tomorrow'] ?? '') as String;
    final streak = (u['streak'] ?? 0) as int;
    final reviewed = (u['reviewed'] ?? false) as bool;
    final ts = u['submittedAt'];
    final time = ts != null
        ? TimeOfDay.fromDateTime((ts as dynamic).toDate()).format(context)
        : '';

    // Avatar always uses the real name, not "You"
    final initials = displayName.isNotEmpty
        ? (displayName.length >= 2
                ? displayName.substring(0, 2)
                : displayName)
            .toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: reviewed
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
                      initials,
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
                      Row(
                        children: [
                          Text(name,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.mintDark.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text('you',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mintDark)),
                            ),
                          ],
                        ],
                      ),
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
                          Text('${streak}d',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mintDark)),
                        ],
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
            const SizedBox(height: 12),
            Text(work,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.55),
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis),
            if (_expanded) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Blockers', blockers,
                  AppColors.peach, AppColors.peachDark),
              const SizedBox(height: 8),
              _buildInfoRow('Tomorrow', tomorrow,
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
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (!reviewed)
                  GestureDetector(
                    onTap: _marking
                        ? null
                        : () async {
                            setState(() => _marking = true);
                            await _service.markReviewed(
                                widget.orgId, u['id'] as String);
                            if (mounted) setState(() => _marking = false);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _marking
                            ? AppColors.pastelBlueDark.withOpacity(0.5)
                            : AppColors.pastelBlueDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _marking
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Mark Reviewed',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: AppColors.mintDark),
                      const SizedBox(width: 4),
                      Text('Reviewed',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.mintDark,
                              fontWeight: FontWeight.w500)),
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
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 12, color: textColor, height: 1.4)),
          ),
        ],
      ),
    );
  }
}