import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationModel {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final String inviteCode;
  final int memberCount;
  final String? photoUrl;
  final DateTime createdAt;

  OrganizationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.inviteCode,
    required this.memberCount,
    this.photoUrl,
    required this.createdAt,
  });

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrganizationModel(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      createdBy: d['createdBy'] ?? '',
      inviteCode: d['inviteCode'] ?? '',
      memberCount: d['memberCount'] ?? 1,
      photoUrl: d['photoUrl'],
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'createdBy': createdBy,
        'inviteCode': inviteCode,
        'memberCount': memberCount,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

  // Initials from org name for avatar
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class OrgMember {
  final String uid;
  final String name;
  final String email;
  final String role;
  final DateTime joinedAt;
  final String? photoUrl;

  OrgMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.photoUrl,
  });

  factory OrgMember.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrgMember(
      uid: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      role: d['role'] ?? 'staff',
      joinedAt: d['joinedAt'] != null
          ? (d['joinedAt'] as Timestamp).toDate()
          : DateTime.now(),
      photoUrl: d['photoUrl'],
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  bool get isAdmin => role == 'admin';
}