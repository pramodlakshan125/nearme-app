import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String facebookUrl;
  final DateTime createdAt;
  final DateTime lastActive;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.facebookUrl,
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      facebookUrl: map['facebookUrl'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActive: (map['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'facebookUrl': facebookUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? facebookUrl,
    DateTime? lastActive,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
