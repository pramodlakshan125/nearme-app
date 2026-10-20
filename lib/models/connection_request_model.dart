import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, accepted, rejected }

class ConnectionRequestModel {
  final String requestId;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final String receiverId;
  final RequestStatus status;
  final DateTime timestamp;

  ConnectionRequestModel({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.receiverId,
    required this.status,
    required this.timestamp,
  });

  factory ConnectionRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return ConnectionRequestModel(
      requestId: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhotoUrl: map['senderPhotoUrl'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: RequestStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => RequestStatus.pending,
      ),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'receiverId': receiverId,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
