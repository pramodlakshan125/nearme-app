import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveSessionModel {
  final String uid;
  final String bleDeviceId;
  final String serviceUuid;
  final DateTime lastSeen;
  final bool isBroadcasting;

  ActiveSessionModel({
    required this.uid,
    required this.bleDeviceId,
    required this.serviceUuid,
    required this.lastSeen,
    required this.isBroadcasting,
  });

  factory ActiveSessionModel.fromMap(Map<String, dynamic> map, String id) {
    return ActiveSessionModel(
      uid: id,
      bleDeviceId: map['bleDeviceId'] ?? '',
      serviceUuid: map['serviceUuid'] ?? '',
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isBroadcasting: map['isBroadcasting'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'bleDeviceId': bleDeviceId,
      'serviceUuid': serviceUuid,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isBroadcasting': isBroadcasting,
    };
  }
}
