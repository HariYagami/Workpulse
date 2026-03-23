import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpdatesService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Fetch current user's name and role from Firestore users collection
  Future<Map<String, String>> getCurrentUserDetails() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'name': '', 'role': ''};
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return {'name': '', 'role': ''};
    final data = doc.data()!;
    return {
      'name': (data['name'] ?? data['displayName'] ?? '').toString(),
      'role': (data['role'] ?? data['designation'] ?? '').toString(),
    };
  }

  String get currentUid => _auth.currentUser?.uid ?? '';

  Future<void> submitUpdate({
    required String orgId,
    required String work,
    required String blockers,
    required String tomorrow,
    required String name,
    required String role,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final today = _todayKey();

    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('updates')
        .doc('${today}_$uid')
        .set({
      'uid': uid,
      'name': name,
      'role': role,
      'work': work,
      'blockers': blockers,
      'tomorrow': tomorrow,
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewed': false,
      'streak': await _computeStreak(orgId, uid),
    });
  }

  Future<bool> hasSubmittedToday(String orgId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('updates')
        .doc('${_todayKey()}_$uid')
        .get();
    return doc.exists;
  }

  Future<Map<String, dynamic>?> getMyTodayUpdate(String orgId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('updates')
        .doc('${_todayKey()}_$uid')
        .get();
    return doc.exists ? doc.data() : null;
  }

  Stream<List<Map<String, dynamic>>> streamTodayUpdates(String orgId) {
    return _db
        .collection('organizations')
        .doc(orgId)
        .collection('updates')
        .where('submittedAt', isGreaterThanOrEqualTo: _todayStart())
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> markReviewed(String orgId, String docId) async {
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('updates')
        .doc(docId)
        .update({'reviewed': true});
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Timestamp _todayStart() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return Timestamp.fromDate(start);
  }

  Future<int> _computeStreak(String orgId, String uid) async {
    int streak = 0;
    DateTime day = DateTime.now().subtract(const Duration(days: 1));
    for (int i = 0; i < 30; i++) {
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}_$uid';
      final doc = await _db
          .collection('organizations')
          .doc(orgId)
          .collection('updates')
          .doc(key)
          .get();
      if (doc.exists) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}