import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveSessionModel {
  final String uid;
  final String discoveryToken;
  final DateTime lastSeen;
  final bool isBroadcasting;

  ActiveSessionModel({
    required this.uid,
    required this.discoveryToken,
    required this.lastSeen,
    required this.isBroadcasting,
  });

  factory ActiveSessionModel.fromMap(Map<String, dynamic> map, String id) {
    return ActiveSessionModel(
      uid: id,
      discoveryToken: map['discoveryToken'] ?? '',
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isBroadcasting: map['isBroadcasting'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'discoveryToken': discoveryToken,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isBroadcasting': isBroadcasting,
    };
  }
}
