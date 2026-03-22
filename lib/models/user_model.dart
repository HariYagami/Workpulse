import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isAdmin;        // ← boolean flag instead of role string
  final List<String> orgs;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.isAdmin,
    required this.orgs,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      photoUrl: d['photoUrl'],
      isAdmin: d['isAdmin'] ?? false,  // ← read boolean field
      orgs: List<String>.from(d['orgs'] ?? []),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory UserModel.fromFirebaseUser(User user,
      {required bool isAdmin}) {
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      isAdmin: isAdmin,
      orgs: [],
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'isAdmin': isAdmin,        // ← write boolean field
        'orgs': orgs,
        'createdAt': FieldValue.serverTimestamp(),
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : 'U';
  }

  // role string for backward compatibility with OrgService
  String get role => isAdmin ? 'admin' : 'staff';
}