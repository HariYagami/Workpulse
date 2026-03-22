import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/organization_model.dart';
import '../services/auth_service.dart';

// ─── Firestore-backed Poll model ────────────────────────────────────────────

class PollData {
  final String id;
  final String question;
  final String deadline;
  final List<String> options;
  final List<int> votes;
  final int total;
  final bool isActive;
  final String? myVote;

  const PollData({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.total,
    required this.deadline,
    required this.isActive,
    this.myVote,
  });

  factory PollData.fromFirestore(
    DocumentSnapshot doc,
    String currentUserId,
  ) {
    final d = doc.data() as Map<String, dynamic>;
    final options = List<String>.from(d['options'] ?? []);
    final votes = List<int>.from(
        (d['votes'] as List?)?.map((v) => (v as num).toInt()) ??
            List.filled(options.length, 0));
    final voterMap = Map<String, dynamic>.from(d['voterMap'] ?? {});
    return PollData(
      id: doc.id,
      question: d['question'] ?? '',
      options: options,
      votes: votes,
      total: (d['total'] as num?)?.toInt() ?? 0,
      deadline: d['deadline'] ?? '',
      isActive: d['isActive'] ?? true,
      myVote: voterMap[currentUserId] as String?,
    );
  }
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class StaffPollsScreen extends StatefulWidget {
  final OrganizationModel org;
  const StaffPollsScreen({super.key, required this.org});

  @override
  State<StaffPollsScreen> createState() => _StaffPollsScreenState();
}

class _StaffPollsScreenState extends State<StaffPollsScreen> {
  final _auth = AuthService();
  final _db   = FirebaseFirestore.instance;

  final Set<String> _votingInProgress = {};

  Stream<List<PollData>> get _pollsStream {
    final uid = _auth.currentFirebaseUser?.uid ?? '';
    return _db
        .collection('organizations')
        .doc(widget.org.id)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PollData.fromFirestore(doc, uid))
            .toList());
  }

  Future<void> _vote(String pollId, String option) async {
    if (_votingInProgress.contains(pollId)) return;
    final uid = _auth.currentFirebaseUser?.uid;
    if (uid == null) return;

    setState(() => _votingInProgress.add(pollId));

    try {
      final pollRef = _db
          .collection('organizations')
          .doc(widget.org.id)
          .collection('polls')
          .doc(pollId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(pollRef);
        if (!snap.exists) return;

        final data     = snap.data()!;
        final options  = List<String>.from(data['options'] ?? []);
        final votes    = List<int>.from(
            (data['votes'] as List?)?.map((v) => (v as num).toInt()) ??
                List.filled(options.length, 0));
        final voterMap = Map<String, dynamic>.from(data['voterMap'] ?? {});

        if (voterMap.containsKey(uid)) return;

        final optIdx = options.indexOf(option);
        if (optIdx == -1) return;

        votes[optIdx]++;
        voterMap[uid] = option;

        tx.update(pollRef, {
          'votes':    votes,
          'voterMap': voterMap,
          'total':    FieldValue.increment(1),
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit vote: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _votingInProgress.remove(pollId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<PollData>>(
        stream: _pollsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.pastelBlueDark,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 44, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text('Could not load polls',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.textSecondary)),
                    Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
            );
          }

          final polls  = snapshot.data ?? [];
          final active = polls.where((p) => p.isActive).toList();
          final closed = polls.where((p) => !p.isActive).toList();

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildVotedStatus(active),
              const SizedBox(height: 20),
              if (active.isNotEmpty) ...[
                _sectionTitle('Active Polls (${active.length})'),
                const SizedBox(height: 12),
                ...active.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PollCard(
                        poll: p,
                        votingInProgress: _votingInProgress.contains(p.id),
                        onVote: (opt) => _vote(p.id, opt),
                      ),
                    )),
              ],
              if (active.isEmpty) _buildEmptyActive(),
              if (closed.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionTitle('Closed Polls'),
                const SizedBox(height: 12),
                ...closed.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PollCard(
                        poll: p,
                        votingInProgress: false,
                        onVote: (_) {},
                      ),
                    )),
              ],
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final photoUrl  = _auth.currentUserPhotoUrl;
    final firstName = _auth.currentUserFirstName;
    final initial   = firstName[0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.pastelBlue,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
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
              Text('Hi, $firstName 👋',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3)),
              Text(widget.org.name,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Text('Polls',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildVotedStatus(List<PollData> active) {
    final voted   = active.where((p) => p.myVote != null).length;
    final pending = active.where((p) => p.myVote == null).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pending > 0 ? AppColors.peach : AppColors.mint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            pending > 0
                ? Icons.pending_actions_rounded
                : Icons.check_circle_rounded,
            size: 22,
            color: pending > 0 ? AppColors.peachDark : AppColors.mintDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending > 0
                      ? '$pending poll${pending > 1 ? 's' : ''} waiting for your vote'
                      : 'All caught up! You\'ve voted on everything.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pending > 0
                        ? AppColors.peachDark
                        : AppColors.mintDark,
                  ),
                ),
                Text(
                  '$voted voted · ${active.length} total active',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: (pending > 0
                            ? AppColors.peachDark
                            : AppColors.mintDark)
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActive() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Icons.how_to_vote_outlined,
                size: 44, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No active polls right now',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary)),
            Text("Your admin hasn't created any yet",
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));
}

// ─── Poll Card ───────────────────────────────────────────────────────────────

class _PollCard extends StatelessWidget {
  final PollData poll;
  final bool votingInProgress;
  final ValueChanged<String> onVote;

  const _PollCard({
    required this.poll,
    required this.votingInProgress,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final hasVoted = poll.myVote != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !hasVoted && poll.isActive
              ? AppColors.pastelBlueDark.withOpacity(0.35)
              : AppColors.border,
          width: !hasVoted && poll.isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: poll.isActive ? AppColors.mint : AppColors.surface,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  poll.isActive ? 'Active' : 'Closed',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: poll.isActive
                        ? AppColors.mintDark
                        : AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hasVoted)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlue,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_rounded,
                          size: 10, color: AppColors.pastelBlueDark),
                      const SizedBox(width: 3),
                      Text('Voted',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pastelBlueDark)),
                    ],
                  ),
                ),
              const Spacer(),
              Text(poll.deadline,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 12),
          Text(poll.question,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          ...poll.options.asMap().entries.map((e) {
            final i         = e.key;
            final option    = e.value;
            final isMyVote  = poll.myVote == option;
            final pct       =
                poll.total > 0 ? poll.votes[i] / poll.total : 0.0;
            final isLeading = hasVoted &&
                poll.total > 0 &&
                poll.votes[i] ==
                    poll.votes.reduce((a, b) => a > b ? a : b);

            if (!hasVoted && poll.isActive) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: votingInProgress ? null : () => onVote(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: votingInProgress
                          ? AppColors.surface.withOpacity(0.5)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: votingInProgress
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pastelBlueDark,
                              ),
                            ),
                          )
                        : Text(option,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (isMyVote)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.check_circle_rounded,
                              size: 13, color: AppColors.pastelBlueDark),
                        ),
                      Text(option,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isMyVote || isLeading
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isMyVote
                                ? AppColors.pastelBlueDark
                                : isLeading
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                          )),
                      const Spacer(),
                      Text('${(pct * 100).round()}% · ${poll.votes[i]}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.surface,
                      valueColor: AlwaysStoppedAnimation(
                        isMyVote
                            ? AppColors.pastelBlueDark
                            : isLeading
                                ? AppColors.mintDark
                                : AppColors.border,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Text('${poll.total} votes',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }
}