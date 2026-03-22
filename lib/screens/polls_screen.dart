import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PollsScreen extends StatefulWidget {
  final bool embedded;
  final String orgId;
  const PollsScreen({super.key, this.embedded = false, this.orgId = ''});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final _db = FirebaseFirestore.instance;
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(text: 'Option 1'),
    TextEditingController(text: 'Option 2'),
  ];

  // Cache member profiles: uid → {name, photoUrl}
  Map<String, Map<String, dynamic>> _memberCache = {};

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (widget.orgId.isEmpty) return;
    final snap = await _db
        .collection('organizations')
        .doc(widget.orgId)
        .collection('members')
        .get();
    final cache = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      cache[doc.id] = {
        'name': d['name'] ?? 'Unknown',
        'email': d['email'] ?? '',
        'photoUrl': d['photoUrl'],
      };
    }
    if (mounted) setState(() => _memberCache = cache);
  }

  Stream<List<_PollItem>> get _pollsStream {
    return _db
        .collection('organizations')
        .doc(widget.orgId)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              final options = List<String>.from(d['options'] ?? []);
              final votes = List<int>.from(
                  (d['votes'] as List?)?.map((v) => (v as num).toInt()) ??
                      List.filled(options.length, 0));
              final voterMap =
                  Map<String, String>.from(d['voterMap'] ?? {});
              return _PollItem(
                id: doc.id,
                question: d['question'] ?? '',
                options: options,
                votes: votes,
                total: (d['total'] as num?)?.toInt() ?? 0,
                deadline: d['deadline'] ?? '',
                isActive: d['isActive'] ?? true,
                voterMap: voterMap,
              );
            }).toList());
  }

  Future<void> _togglePollStatus(String pollId, bool currentStatus) async {
    await _db
        .collection('organizations')
        .doc(widget.orgId)
        .collection('polls')
        .doc(pollId)
        .update({'isActive': !currentStatus});
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Polls'),
              backgroundColor: AppColors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [_newPollButton(context)],
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.embedded) _buildEmbeddedHeader(context),
            Expanded(
              child: StreamBuilder<List<_PollItem>>(
                stream: _pollsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.pastelBlueDark),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    );
                  }

                  final polls = snapshot.data ?? [];
                  final active =
                      polls.where((p) => p.isActive).toList();
                  final closed =
                      polls.where((p) => !p.isActive).toList();

                  if (polls.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.how_to_vote_outlined,
                              size: 44, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          Text('No polls yet',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
                          Text('Tap "+ New Poll" to create one',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textHint)),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (active.isNotEmpty) ...[
                        _sectionTitle('Active (${active.length})'),
                        const SizedBox(height: 12),
                        ...active.map((p) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 16),
                              child: _PollCard(
                                poll: p,
                                memberCache: _memberCache,
                                onToggle: () => _togglePollStatus(
                                    p.id, p.isActive),
                              ),
                            )),
                      ],
                      if (closed.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _sectionTitle('Closed (${closed.length})'),
                        const SizedBox(height: 12),
                        ...closed.map((p) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 16),
                              child: _PollCard(
                                poll: p,
                                memberCache: _memberCache,
                                onToggle: () => _togglePollStatus(
                                    p.id, p.isActive),
                              ),
                            )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      );

  Widget _buildEmbeddedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Polls',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3)),
              Text('Active & closed polls',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary)),
            ],
          ),
          const Spacer(),
          _newPollButton(context),
        ],
      ),
    );
  }

  Widget _newPollButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreatePoll(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.pastelBlueDark,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('+ New Poll',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }

  void _showCreatePoll(BuildContext context) {
    _questionController.clear();
    _optionControllers
      ..clear()
      ..addAll([
        TextEditingController(text: 'Option 1'),
        TextEditingController(text: 'Option 2'),
      ]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Create Poll',
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
              const SizedBox(height: 20),
              TextField(
                controller: _questionController,
                decoration: const InputDecoration(
                    hintText: 'Ask your team something...'),
              ),
              const SizedBox(height: 16),
              Text('Options',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              ..._optionControllers.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: c,
                      decoration: InputDecoration(
                        hintText: 'Option',
                        suffixIcon: _optionControllers.length > 2
                            ? IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: AppColors.textHint,
                                    size: 20),
                                onPressed: () => setSheetState(() =>
                                    _optionControllers.remove(c)),
                              )
                            : null,
                      ),
                    ),
                  )),
              GestureDetector(
                onTap: () => setSheetState(() =>
                    _optionControllers.add(TextEditingController())),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text('+ Add option',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.pastelBlueDark,
                          fontWeight: FontWeight.w500)),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _publishPoll(ctx),
                  child: const Text('Publish Poll'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publishPoll(BuildContext ctx) async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Enter a question and at least 2 options.')),
      );
      return;
    }

    await _db
        .collection('organizations')
        .doc(widget.orgId)
        .collection('polls')
        .add({
      'question': question,
      'options': options,
      'votes': List.filled(options.length, 0),
      'voterMap': {},
      'total': 0,
      'deadline': 'No deadline',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (ctx.mounted) Navigator.pop(ctx);
  }
}

// ─── Admin Poll Card ──────────────────────────────────────────────────────────

class _PollCard extends StatefulWidget {
  final _PollItem poll;
  final Map<String, Map<String, dynamic>> memberCache;
  final VoidCallback onToggle;

  const _PollCard({
    required this.poll,
    required this.memberCache,
    required this.onToggle,
  });

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  bool _showVoters = false;

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main poll content ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(children: [
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: poll.isActive
                          ? AppColors.mint
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      poll.isActive ? 'Active' : 'Closed',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: poll.isActive
                              ? AppColors.mintDark
                              : AppColors.textHint),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Total votes chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${poll.total} vote${poll.total == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lavenderDark),
                    ),
                  ),
                  const Spacer(),
                  // Close/Reopen button
                  GestureDetector(
                    onTap: widget.onToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: poll.isActive
                            ? const Color(0xFFFCEBEB)
                            : AppColors.mint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        poll.isActive ? 'Close' : 'Reopen',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: poll.isActive
                                ? const Color(0xFFA32D2D)
                                : AppColors.mintDark),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Question
                Text(poll.question,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 14),

                // Vote bars
                ...List.generate(poll.options.length, (i) {
                  final pct = poll.total > 0
                      ? poll.votes[i] / poll.total
                      : 0.0;
                  final isLeading = poll.total > 0 &&
                      poll.votes[i] ==
                          poll.votes
                              .reduce((a, b) => a > b ? a : b);

                  // Voters for this option
                  final votersForOption = poll.voterMap.entries
                      .where((e) => e.value == poll.options[i])
                      .map((e) => e.key)
                      .toList();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            if (isLeading && poll.total > 0)
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: 5),
                                child: Icon(
                                    Icons.emoji_events_rounded,
                                    size: 13,
                                    color: AppColors.pastelBlueDark),
                              ),
                            Expanded(
                              child: Text(poll.options[i],
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight:
                                          isLeading && poll.total > 0
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                      color:
                                          isLeading && poll.total > 0
                                              ? AppColors.pastelBlueDark
                                              : AppColors
                                                  .textSecondary)),
                            ),
                            Text(
                              '${(pct * 100).round()}%  ·  ${poll.votes[i]}',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textHint),
                            ),
                          ]),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: AppColors.surface,
                              valueColor: AlwaysStoppedAnimation(
                                isLeading && poll.total > 0
                                    ? AppColors.pastelBlueDark
                                    : AppColors.border,
                              ),
                            ),
                          ),
                          // Voter avatars row below each option bar
                          if (_showVoters &&
                              votersForOption.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: votersForOption.map((uid) {
                                final member =
                                    widget.memberCache[uid];
                                final name =
                                    member?['name'] as String? ??
                                        'Unknown';
                                final photoUrl =
                                    member?['photoUrl'] as String?;
                                final initials = name.trim().isEmpty
                                    ? '?'
                                    : name
                                        .trim()
                                        .split(' ')
                                        .map((p) => p[0])
                                        .take(2)
                                        .join()
                                        .toUpperCase();
                                return _VoterChip(
                                  name: name,
                                  initials: initials,
                                  photoUrl: photoUrl,
                                );
                              }).toList(),
                            ),
                          ],
                        ]),
                  );
                }),
              ],
            ),
          ),

          // ── See Voters toggle ─────────────────────────────────────────
          if (poll.total > 0)
            GestureDetector(
              onTap: () =>
                  setState(() => _showVoters = !_showVoters),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: const Border(
                      top: BorderSide(
                          color: AppColors.border, width: 0.8)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showVoters
                          ? Icons.visibility_off_rounded
                          : Icons.people_rounded,
                      size: 14,
                      color: AppColors.pastelBlueDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showVoters
                          ? 'Hide voters'
                          : 'See who voted (${poll.total})',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pastelBlueDark),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Voter Chip ───────────────────────────────────────────────────────────────

class _VoterChip extends StatelessWidget {
  final String name;
  final String initials;
  final String? photoUrl;

  const _VoterChip({
    required this.name,
    required this.initials,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pastelBlue,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.pastelBlueDark.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.pastelBlueDark,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Text(initials,
                    style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white))
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            name.split(' ').first, // first name only
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.pastelBlueDark),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _PollItem {
  final String id;
  final String question;
  final List<String> options;
  final List<int> votes;
  final int total;
  final String deadline;
  final bool isActive;
  final Map<String, String> voterMap; // uid → option chosen

  const _PollItem({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.total,
    required this.deadline,
    required this.isActive,
    required this.voterMap,
  });
}