import 'package:flutter/material.dart';

class PollData {
  final String id;
  final String question;
  final List<String> options;
  final List<int> votes;
  final int total;
  final String deadline;
  final bool isActive;
  final String? myVote;

  PollData({
    required this.id,
    required this.question,
    required this.options,
    required this.votes,
    required this.total,
    required this.deadline,
    required this.isActive,
    this.myVote,
  });

  PollData copyWith({
    List<int>? votes,
    int? total,
    String? myVote,
  }) {
    return PollData(
      id: id,
      question: question,
      options: options,
      votes: votes ?? this.votes,
      total: total ?? this.total,
      deadline: deadline,
      isActive: isActive,
      myVote: myVote ?? this.myVote,
    );
  }
}

class PollStore extends ChangeNotifier {
  static final PollStore _instance = PollStore._internal();
  factory PollStore() => _instance;
  PollStore._internal();

  final List<PollData> _polls = [
    PollData(
      id: '1',
      question: 'Work arrangement this Friday?',
      options: ['Office', 'WFH', 'Hybrid'],
      votes: [7, 2, 1],
      total: 10,
      deadline: 'Today, 5:00 PM',
      isActive: true,
    ),
    PollData(
      id: '2',
      question: 'Team lunch day preference?',
      options: ['Tuesday', 'Wednesday', 'Friday'],
      votes: [3, 5, 2],
      total: 10,
      deadline: 'Yesterday',
      isActive: false,
    ),
  ];

  List<PollData> get polls => List.unmodifiable(_polls);

  void addPoll(PollData poll) {
    _polls.insert(0, poll);
    notifyListeners();
  }

  void vote(String pollId, String option) {
    final idx = _polls.indexWhere((p) => p.id == pollId);
    if (idx == -1) return;
    final p = _polls[idx];
    final optIdx = p.options.indexOf(option);
    if (optIdx == -1 || p.myVote != null) return;
    final newVotes = List<int>.from(p.votes);
    newVotes[optIdx]++;
    _polls[idx] = p.copyWith(
      votes: newVotes,
      total: p.total + 1,
      myVote: option,
    );
    notifyListeners();
  }
}