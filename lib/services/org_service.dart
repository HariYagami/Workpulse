import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/organization_model.dart';

class OrgService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  String? get currentUid => _uid;

  String get _requireUid {
    final uid = _uid;
    if (uid == null) throw Exception('You must be signed in to do this.');
    return uid;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code =
        List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return '${code.substring(0, 2)}-${code.substring(2)}';
  }

  Future<String> createOrg({
    required String name,
    required String description,
  }) async {
    final uid = _requireUid;
    final user = _auth.currentUser!;
    final code = _generateCode();

    final orgRef = await _db.collection('organizations').add({
      'name': name,
      'description': description,
      'createdBy': uid,
      'inviteCode': code,
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await orgRef.collection('members').doc(uid).set({
      'uid': uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
      'photoUrl': user.photoURL,
    });

    await _db.collection('users').doc(uid).set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL,
      'orgs': FieldValue.arrayUnion([orgRef.id]),
    }, SetOptions(merge: true));

    return orgRef.id;
  }

  Future<OrganizationModel?> getOrgByCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    final snap = await _db
        .collection('organizations')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return OrganizationModel.fromFirestore(snap.docs.first);
  }

  Future<String> joinOrgByCode(String rawCode) async {
    final uid = _requireUid;
    final user = _auth.currentUser!;
    final code = rawCode.trim().toUpperCase();

    final snap = await _db
        .collection('organizations')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('Invalid invite code. Please check and try again.');
    }

    final orgId = snap.docs.first.id;

    final existing = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .get();

    if (existing.exists) {
      throw Exception('You are already a member of this organization.');
    }

    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .set({
      'uid': uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'role': 'staff',
      'joinedAt': FieldValue.serverTimestamp(),
      'photoUrl': user.photoURL,
    });

    await _db.collection('organizations').doc(orgId).update({
      'memberCount': FieldValue.increment(1),
    });

    await _db.collection('users').doc(uid).set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL,
      'orgs': FieldValue.arrayUnion([orgId]),
    }, SetOptions(merge: true));

    return orgId;
  }

  Future<String> regenerateCode(String orgId) async {
    final code = _generateCode();
    await _db
        .collection('organizations')
        .doc(orgId)
        .update({'inviteCode': code});
    return code;
  }

  Stream<List<OrganizationModel>> streamMyOrgs() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists) return <OrganizationModel>[];
      final data = userDoc.data() as Map<String, dynamic>?;
      final orgIds = List<String>.from(data?['orgs'] ?? []);
      if (orgIds.isEmpty) return <OrganizationModel>[];

      final futures =
          orgIds.map((id) => _db.collection('organizations').doc(id).get());
      final docs = await Future.wait(futures);
      return docs
          .where((d) => d.exists)
          .map((d) => OrganizationModel.fromFirestore(d))
          .toList();
    });
  }

  Future<List<OrganizationModel>> getMyOrgs() async {
    final uid = _uid;
    if (uid == null) return [];

    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return [];
    final data = userDoc.data() as Map<String, dynamic>?;
    final orgIds = List<String>.from(data?['orgs'] ?? []);
    if (orgIds.isEmpty) return [];

    final futures =
        orgIds.map((id) => _db.collection('organizations').doc(id).get());
    final docs = await Future.wait(futures);
    return docs
        .where((d) => d.exists)
        .map((d) => OrganizationModel.fromFirestore(d))
        .toList();
  }

  Stream<List<OrgMember>> streamMembers(String orgId) {
    return _db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots()
        .map((s) => s.docs.map((d) => OrgMember.fromFirestore(d)).toList());
  }

  Future<void> removeMember(String orgId, String memberId) async {
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(memberId)
        .delete();

    await _db
        .collection('organizations')
        .doc(orgId)
        .update({'memberCount': FieldValue.increment(-1)});

    await _db
        .collection('users')
        .doc(memberId)
        .update({'orgs': FieldValue.arrayRemove([orgId])});
  }

  Future<OrganizationModel?> getOrg(String orgId) async {
    final doc = await _db.collection('organizations').doc(orgId).get();
    if (!doc.exists) return null;
    return OrganizationModel.fromFirestore(doc);
  }

  Future<String?> getUserRole(String orgId) async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>)['role'] as String?;
  }

  // ─── Save office location ─────────────────────────────────────────────────
  Future<void> saveOfficeLocation({
    required String orgId,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String? address,                              // ✅ added
  }) async {
    await _db
        .collection('organizations')
        .doc(orgId)
        .collection('settings')
        .doc('location')
        .set({
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'address': address ?? '',                   // ✅ saved to Firestore
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Fetch office location ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getOfficeLocation(String orgId) async {
    final doc = await _db
        .collection('organizations')
        .doc(orgId)
        .collection('settings')
        .doc('location')
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }
}