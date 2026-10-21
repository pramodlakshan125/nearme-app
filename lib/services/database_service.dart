import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/private_profile_model.dart';
import '../models/active_session_model.dart';
import '../models/connection_request_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users Collection ---
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('public_profiles').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Stream<UserModel?> streamUser(String uid) {
    return _db
        .collection('public_profiles')
        .doc(uid)
        .snapshots()
        .asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }

      final legacyDoc = await _db.collection('users').doc(uid).get();
      final legacyData = legacyDoc.data();
      if (!legacyDoc.exists || legacyData == null) return null;

      final legacyUser = UserModel.fromMap(legacyData, uid);
      await _migrateLegacyUser(legacyDoc.reference, legacyUser, legacyData);
      return legacyUser;
    });
  }

  Future<void> _migrateLegacyUser(
    DocumentReference<Map<String, dynamic>> legacyRef,
    UserModel user,
    Map<String, dynamic> legacyData,
  ) async {
    final privateProfile = PrivateProfileModel(
      facebookUrl: legacyData['facebookUrl'] as String? ?? '',
      bio: legacyData['bio'] as String? ?? '',
    );
    final batch = _db.batch();
    batch.set(_db.collection('public_profiles').doc(user.uid), user.toMap());
    batch.set(
      _db.collection('private_profiles').doc(user.uid),
      privateProfile.toPrivateMap(),
    );
    batch.set(
      _db.collection('shared_profiles').doc(user.uid),
      privateProfile.toSharedMap(),
    );
    batch.delete(legacyRef);
    await batch.commit();
  }

  Future<PrivateProfileModel?> getPrivateProfile(String uid) async {
    final doc = await _db.collection('private_profiles').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return PrivateProfileModel.fromMap(doc.data()!);
  }

  Stream<PrivateProfileModel?> streamPrivateProfile(String uid) {
    return _db.collection('private_profiles').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PrivateProfileModel.fromMap(doc.data()!);
    });
  }

  Future<PrivateProfileModel?> getSharedProfile(String uid) async {
    final doc = await _db.collection('shared_profiles').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return PrivateProfileModel.fromMap(doc.data()!);
  }

  Stream<PrivateProfileModel?> streamSharedProfile(String uid) {
    return _db.collection('shared_profiles').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PrivateProfileModel.fromMap(doc.data()!);
    });
  }

  Future<void> createOrUpdateUser(
    UserModel user, {
    required PrivateProfileModel privateProfile,
  }) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('public_profiles').doc(user.uid),
      user.toMap(),
    );
    batch.set(
      _db.collection('private_profiles').doc(user.uid),
      privateProfile.toPrivateMap(),
    );
    batch.set(
      _db.collection('shared_profiles').doc(user.uid),
      privateProfile.toSharedMap(),
    );
    batch.delete(_db.collection('users').doc(user.uid));
    await batch.commit();
  }

  Future<void> updateUserPhoto({
    required String uid,
    required String photoUrl,
  }) async {
    await _db.collection('public_profiles').doc(uid).update({
      'photoUrl': photoUrl,
      'lastActive': Timestamp.fromDate(DateTime.now()),
    });
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

  Stream<List<UserModel>> streamNearbyUsers(
    String currentUid,
    List<String> discoveredTokens,
  ) {
    if (discoveredTokens.isEmpty) return Stream.value([]);

    return _db
        .collection('active_sessions')
        .where('isBroadcasting', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final now = DateTime.now();
      final matchingSessions = snapshot.docs.where((doc) {
        final data = doc.data();
        final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
        return doc.id != currentUid &&
            discoveredTokens.contains(data['discoveryToken']) &&
            lastSeen != null &&
            now.difference(lastSeen) < const Duration(seconds: 45);
      });

      final users = await Future.wait(
        matchingSessions.map((session) async {
          final profile =
              await _db.collection('public_profiles').doc(session.id).get();
          if (!profile.exists || profile.data() == null) return null;
          return UserModel.fromMap(profile.data()!, profile.id);
        }),
      );
      return users
          .whereType<UserModel>()
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
    final requests = <String, ConnectionRequestModel>{};
    final controller = StreamController<ConnectionRequestModel?>();
    final firstRef = _db.collection('connection_requests').doc(id1);
    final secondRef = _db.collection('connection_requests').doc(id2);

    void emit() {
      final current = requests.values.toList()
        ..sort((a, b) {
          if (a.status == RequestStatus.accepted &&
              b.status != RequestStatus.accepted) {
            return -1;
          }
          if (b.status == RequestStatus.accepted &&
              a.status != RequestStatus.accepted) {
            return 1;
          }
          return b.timestamp.compareTo(a.timestamp);
        });
      controller.add(current.isEmpty ? null : current.first);
    }

    StreamSubscription? firstSubscription;
    StreamSubscription? secondSubscription;

    controller.onListen = () {
      firstSubscription = firstRef.snapshots().listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          requests[id1] =
              ConnectionRequestModel.fromMap(snapshot.data()!, snapshot.id);
        } else {
          requests.remove(id1);
        }
        emit();
      }, onError: controller.addError);
      secondSubscription = secondRef.snapshots().listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          requests[id2] =
              ConnectionRequestModel.fromMap(snapshot.data()!, snapshot.id);
        } else {
          requests.remove(id2);
        }
        emit();
      }, onError: controller.addError);
    };
    controller.onCancel = () {
      firstSubscription?.cancel();
      secondSubscription?.cancel();
    };
    return controller.stream;
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
