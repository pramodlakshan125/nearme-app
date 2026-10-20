import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/active_session_model.dart';
import '../models/connection_request_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users Collection ---
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Stream<UserModel?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> createOrUpdateUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }

  // --- Active Sessions (BLE Presence) ---
  Future<void> updateActiveSession(ActiveSessionModel session) async {
    await _db.collection('active_sessions').doc(session.uid).set(
          session.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> clearActiveSession(String uid) async {
    await _db.collection('active_sessions').doc(uid).delete();
  }

  Stream<List<UserModel>> streamActiveUsers(String currentUid) {
    // Return all users who have been active in the last 15 minutes excluding current user
    final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
    return _db
        .collection('users')
        .where('lastActive', isGreaterThan: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .where((user) => user.isVisible)
          .toList();
    });
  }

  // --- Connection Requests ---
  Future<void> sendConnectionRequest({
    required UserModel sender,
    required String receiverId,
  }) async {
    final docId = '${sender.uid}_$receiverId';
    final request = ConnectionRequestModel(
      requestId: docId,
      senderId: sender.uid,
      senderName: sender.displayName,
      senderPhotoUrl: sender.photoUrl,
      receiverId: receiverId,
      status: RequestStatus.pending,
      timestamp: DateTime.now(),
    );

    await _db.collection('connection_requests').doc(docId).set(request.toMap());
  }

  Stream<ConnectionRequestModel?> streamConnectionStatus(
      String userId1, String userId2) {
    final id1 = '${userId1}_$userId2';
    final id2 = '${userId2}_$userId1';

    return _db
        .collection('connection_requests')
        .where(FieldPath.documentId, whereIn: [id1, id2])
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return ConnectionRequestModel.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  Stream<List<ConnectionRequestModel>> streamIncomingRequests(String userId) {
    return _db
        .collection('connection_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ConnectionRequestModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ConnectionRequestModel>> streamAcceptedConnections(
      String userId) {
    final receiverStream = _db
        .collection('connection_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: RequestStatus.accepted.name)
        .snapshots();

    final senderStream = _db
        .collection('connection_requests')
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: RequestStatus.accepted.name)
        .snapshots();

    final controller = StreamController<List<ConnectionRequestModel>>();
    List<ConnectionRequestModel> receiverList = [];
    List<ConnectionRequestModel> senderList = [];

    void emitMerged() {
      final map = <String, ConnectionRequestModel>{};
      for (final r in receiverList) {
        map[r.requestId] = r;
      }
      for (final r in senderList) {
        map[r.requestId] = r;
      }
      final merged = map.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    StreamSubscription? sub1;
    StreamSubscription? sub2;

    controller.onListen = () {
      sub1 = receiverStream.listen((snapshot) {
        receiverList = snapshot.docs
            .map((doc) => ConnectionRequestModel.fromMap(doc.data(), doc.id))
            .toList();
        emitMerged();
      }, onError: controller.addError);

      sub2 = senderStream.listen((snapshot) {
        senderList = snapshot.docs
            .map((doc) => ConnectionRequestModel.fromMap(doc.data(), doc.id))
            .toList();
        emitMerged();
      }, onError: controller.addError);
    };

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
  }

  Future<void> updateRequestStatus(
      String requestId, RequestStatus status) async {
    await _db
        .collection('connection_requests')
        .doc(requestId)
        .update({'status': status.name});
  }

  Future<void> removeConnection(String requestId) async {
    await _db.collection('connection_requests').doc(requestId).delete();
  }
}
