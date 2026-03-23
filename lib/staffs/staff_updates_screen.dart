import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/organization_model.dart';
import '../services/updates_service.dart';

class StaffUpdatesScreen extends StatefulWidget {
  final OrganizationModel org;

  const StaffUpdatesScreen({
    super.key,
    required this.org,
  });

  @override
  State<StaffUpdatesScreen> createState() => _StaffUpdatesScreenState();
}

class _StaffUpdatesScreenState extends State<StaffUpdatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = UpdatesService();

  final _workCtrl = TextEditingController();
  final _blockersCtrl = TextEditingController();
  final _tomorrowCtrl = TextEditingController();

  bool _submitted = false;
  bool _submitting = false;
  bool _loadingState = true;
  int _myStreak = 0;
  String _staffName = '';
  String _staffRole = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    // Fetch name and role from Firestore users collection
    final details = await _service.getCurrentUserDetails();
    _staffName = details['name'] ?? '';
    _staffRole = details['role'] ?? '';

    // Check if already submitted today
    final existing = await _service.getMyTodayUpdate(widget.org.id);
    if (existing != null) {
      _workCtrl.text = existing['work'] ?? '';
      _blockersCtrl.text = existing['blockers'] ?? '';
      _tomorrowCtrl.text = existing['tomorrow'] ?? '';
      _myStreak = (existing['streak'] ?? 0) as int;
      // Use saved name/role if local fetch returned empty
      if (_staffName.isEmpty) _staffName = existing['name'] ?? '';
      if (_staffRole.isEmpty) _staffRole = existing['role'] ?? '';
      setState(() => _submitted = true);
    }
    setState(() => _loadingState = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _workCtrl.dispose();
    _blockersCtrl.dispose();
    _tomorrowCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    if (_workCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await _service.submitUpdate(
        orgId: widget.org.id,
        work: _workCtrl.text.trim(),
        blockers: _blockersCtrl.text.trim().isEmpty
            ? 'None'
            : _blockersCtrl.text.trim(),
        tomorrow: _tomorrowCtrl.text.trim(),
        name: _staffName,
        role: _staffRole,
      );
      setState(() {
        _submitted = true;
        _submitting = false;
      });
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingState) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            labelStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
            labelColor: AppColors.mintDark,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.mintDark,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: 'My Update'),
              Tab(text: 'Team Updates'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyUpdateTab(),
                _buildTeamUpdatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily Updates',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  )),
              Text(widget.org.name,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const Spacer(),
          _buildStreakBadge(),
        ],
      ),
    );
  }

  Widget _buildStreakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.peach,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 14, color: AppColors.peachDark),
          const SizedBox(width: 4),
          Text('$_myStreak-day streak',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.peachDark,
              )),
        ],
      ),
    );
  }

  // ─── My Update Tab ──────────────────────────────────────────────────────────

  Widget _buildMyUpdateTab() {
    if (_submitted) return _buildSubmittedState();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTodayBanner(),
          const SizedBox(height: 22),
          _buildFormField(
            label: 'What did you work on today?',
            hint: 'Describe your work, tasks completed, progress made...',
            controller: _workCtrl,
            maxLines: 4,
            required: true,
            color: AppColors.mint,
            icon: Icons.task_alt_rounded,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Any blockers?',
            hint: 'Anything slowing you down? Or type "None"',
            controller: _blockersCtrl,
            maxLines: 2,
            required: false,
            color: AppColors.peach,
            icon: Icons.block_rounded,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Plan for tomorrow',
            hint: 'What will you work on next?',
            controller: _tomorrowCtrl,
            maxLines: 2,
            required: false,
            color: AppColors.pastelBlue,
            icon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                  _submitting ? 'Submitting...' : 'Submit Today\'s Update'),
              onPressed: _submitting ? null : _submitUpdate,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Updates are visible to your admin and team.',
              style:
                  GoogleFonts.inter(fontSize: 12, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayBanner() {
    final now = DateTime.now();
    final dayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayStr =
        '${dayNames[now.weekday - 1]}, ${now.day} ${monthNames[now.month - 1]}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_calendar_rounded,
              size: 20, color: AppColors.lavenderDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's standup",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lavenderDark,
                    )),
                Text(dayStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.lavenderDark.withOpacity(0.7),
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lavenderDark.withOpacity(0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text('Not submitted',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lavenderDark,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required int maxLines,
    required bool required,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, size: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            if (required) ...[
              const SizedBox(width: 4),
              Text('*',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.peachDark)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildSubmittedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 40, color: AppColors.mintDark),
            ),
            const SizedBox(height: 20),
            Text('Update submitted!',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 8),
            Text(
              'Your admin and teammates can now see your update for today.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => setState(() => _submitted = false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Edit update',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Team Updates Tab ───────────────────────────────────────────────────────

  Widget _buildTeamUpdatesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamTodayUpdates(widget.org.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final updates = snapshot.data ?? [];
        if (updates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 44, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text('No updates yet today',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            _buildTeamSummary(updates.length),
            const SizedBox(height: 16),
            ...updates.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TeamUpdateCard(
                    update: u,
                    currentUid: _service.currentUid,
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildTeamSummary(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_rounded,
              size: 18, color: AppColors.mintDark),
          const SizedBox(width: 10),
          Text(
            '$count of ${widget.org.memberCount} teammates submitted today',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mintDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Team Update Card ─────────────────────────────────────────────────────────

class _TeamUpdateCard extends StatefulWidget {
  final Map<String, dynamic> update;
  final String currentUid;
  const _TeamUpdateCard({required this.update, required this.currentUid});

  @override
  State<_TeamUpdateCard> createState() => _TeamUpdateCardState();
}

class _TeamUpdateCardState extends State<_TeamUpdateCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final uid = (u['uid'] ?? '') as String;
    final isMe = uid == widget.currentUid;
    final name = isMe ? 'You' : (u['name'] ?? '?') as String;
    final displayName = (u['name'] ?? '?') as String;
    final role = (u['role'] ?? '') as String;
    final work = (u['work'] ?? '') as String;
    final blockers = (u['blockers'] ?? 'None') as String;
    final tomorrow = (u['tomorrow'] ?? '') as String;
    final streak = (u['streak'] ?? 0) as int;
    final ts = u['submittedAt'];
    final time = ts != null
        ? TimeOfDay.fromDateTime((ts as dynamic).toDate()).format(context)
        : '';

    // Avatar initials: always use actual name, not "You"
    final initials = displayName.isNotEmpty
        ? (displayName.length >= 2
            ? displayName.substring(0, 2)
            : displayName)
            .toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? AppColors.mint.withOpacity(0.15) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? AppColors.mintDark.withOpacity(0.3)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.mint : AppColors.lavender,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isMe
                            ? AppColors.mintDark
                            : AppColors.lavenderDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
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
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            size: 11, color: AppColors.peachDark),
                        const SizedBox(width: 2),
                        Text('${streak}d',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.peachDark)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(time,
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(work,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5),
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis),
            if (_expanded) ...[
              const SizedBox(height: 10),
              _infoChip('Blockers', blockers, AppColors.peach,
                  AppColors.peachDark),
              const SizedBox(height: 6),
              _infoChip('Tomorrow', tomorrow, AppColors.pastelBlue,
                  AppColors.pastelBlueDark),
            ],
            const SizedBox(height: 8),
            Text(
              _expanded ? 'Show less' : 'Show more',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.pastelBlueDark,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value, Color bg, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: bg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(9)),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 12, color: textColor),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}