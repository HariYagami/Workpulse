import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:presenceiq/models/organization_model.dart';
import 'package:presenceiq/providers/org_provider.dart';
import 'package:presenceiq/services/org_service.dart';
import 'package:presenceiq/theme/app_theme.dart';


class InviteMembersScreen extends ConsumerStatefulWidget {
  final OrganizationModel org;

  const InviteMembersScreen({super.key, required this.org});

  @override
  ConsumerState<InviteMembersScreen> createState() =>
      _InviteMembersScreenState();
}

class _InviteMembersScreenState extends ConsumerState<InviteMembersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _regenerating = false;
  late String _currentCode;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.org.inviteCode;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _regenerateCode() async {
    setState(() => _regenerating = true);
    try {
      final code =
          await OrgService().regenerateCode(widget.org.id);
      setState(() => _currentCode = code);
    } finally {
      setState(() => _regenerating = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _currentCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code copied!',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.mintDark,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _shareCode() {
    // Replace with share_plus package: Share.share(...)
    _copyCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Invite — ${widget.org.name}',
            overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
          labelColor: AppColors.pastelBlueDark,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.pastelBlueDark,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'Invite Code'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInviteTab(),
          _buildMembersTab(),
        ],
      ),
    );
  }

  // ─── Invite Tab ───────────────────────────────────────────────────────────

  Widget _buildInviteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildCodeCard(),
          const SizedBox(height: 20),
          _buildHowItWorks(),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.pastelBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.vpn_key_rounded,
                size: 26, color: AppColors.pastelBlueDark),
          ),
          const SizedBox(height: 16),
          Text(
            'Share this code',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Anyone with this code can join ${widget.org.name}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // The big code display
          GestureDetector(
            onTap: _copyCode,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.pastelBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentCode,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      color: AppColors.pastelBlueDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.pastelBlueDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: _regenerating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.pastelBlueDark))
                      : const Icon(Icons.refresh_rounded,
                          size: 16, color: AppColors.pastelBlueDark),
                  label: Text('New Code',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.pastelBlueDark)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(
                        color: AppColors.pastelBlueDark),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _regenerating ? null : _regenerateCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _shareCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Deep link
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'presenceiq.app/join/$_currentCode',
                  style: GoogleFonts.sourceCodePro(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(
                      text:
                          'presenceiq.app/join/$_currentCode')),
                  child: const Icon(Icons.copy_rounded,
                      size: 14, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      ['Share the code', 'Send the 6-digit code or link to your staff via WhatsApp, email, or any messaging app.'],
      ['Staff opens app', 'They download PresenceIQ, sign in with their Google account.'],
      ['Staff enters code', 'They tap "Join with Invite Code", enter the code, and they\'re instantly added.'],
      ['You see them here', 'Their name appears in the Members tab. They can now clock in, vote, and submit updates.'],
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.pastelBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.pastelBlueDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value[0],
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary)),
                          Text(e.value[1],
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── Members Tab ──────────────────────────────────────────────────────────

  Widget _buildMembersTab() {
    final membersAsync =
        ref.watch(orgMembersProvider(widget.org.id));

    return membersAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (members) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildMemberStats(members),
          const SizedBox(height: 20),
          ...members.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemberTile(
                  member: m,
                  canRemove: !m.isAdmin,
                  onRemove: () => _confirmRemove(m),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMemberStats(List<OrgMember> members) {
    final admins = members.where((m) => m.isAdmin).length;
    final staff = members.where((m) => !m.isAdmin).length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$staff',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mintDark)),
                Text('Staff',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mintDark)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pastelBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$admins',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pastelBlueDark)),
                Text('Admin',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.pastelBlueDark)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${members.length}',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lavenderDark)),
                Text('Total',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.lavenderDark)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmRemove(OrgMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Remove ${member.name}?',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          'They will lose access to all data in ${widget.org.name}. This cannot be undone.',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await OrgService()
                  .removeMember(widget.org.id, member.uid);
            },
            child: Text('Remove',
                style: GoogleFonts.inter(
                    color: const Color(0xFFA32D2D),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Member Tile ──────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final OrgMember member;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: member.isAdmin
                  ? AppColors.pastelBlue
                  : AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                member.initials,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: member.isAdmin
                      ? AppColors.pastelBlueDark
                      : AppColors.mintDark,
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
                  member.name.isNotEmpty ? member.name : member.email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  member.email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: member.isAdmin
                      ? AppColors.pastelBlue
                      : AppColors.mint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  member.isAdmin ? 'Admin' : 'Staff',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: member.isAdmin
                        ? AppColors.pastelBlueDark
                        : AppColors.mintDark,
                  ),
                ),
              ),
              if (canRemove) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onRemove,
                  child: Text(
                    'Remove',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFA32D2D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}