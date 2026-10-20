import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_request_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/ble_service.dart';
import '../services/database_service.dart';

// Services
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final databaseServiceProvider =
    Provider<DatabaseService>((ref) => DatabaseService());
final bleServiceProvider =
    Provider<BleDiscoveryService>((ref) => BleDiscoveryService());

// Auth State
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Current User Model
final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return ref.watch(databaseServiceProvider).streamUser(authUser.uid);
});

// BLE Scanning State
final isScanningProvider = StateProvider<bool>((ref) => false);

// Nearby Users Stream
final nearbyUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final currentUser = ref.watch(currentUserModelProvider).value;
  if (currentUser == null) return Stream.value([]);
  return ref.watch(databaseServiceProvider).streamActiveUsers(currentUser.uid);
});

// Incoming Requests Stream
final incomingRequestsProvider =
    StreamProvider<List<ConnectionRequestModel>>((ref) {
  final currentUser = ref.watch(currentUserModelProvider).value;
  if (currentUser == null) return Stream.value([]);
  return ref
      .watch(databaseServiceProvider)
      .streamIncomingRequests(currentUser.uid);
});

// Accepted Connections Stream
final acceptedConnectionsProvider =
    StreamProvider<List<ConnectionRequestModel>>((ref) {
  final currentUser = ref.watch(currentUserModelProvider).value;
  if (currentUser == null) return Stream.value([]);
  return ref
      .watch(databaseServiceProvider)
      .streamAcceptedConnections(currentUser.uid);
});

// Helper model representing a connected friend
class ConnectedAccount {
  final ConnectionRequestModel request;
  final UserModel otherUser;

  ConnectedAccount({
    required this.request,
    required this.otherUser,
  });
}

// Connected Accounts with full UserModel loaded
final connectedAccountsProvider =
    FutureProvider<List<ConnectedAccount>>((ref) async {
  final requests = await ref.watch(acceptedConnectionsProvider.future);
  final db = ref.watch(databaseServiceProvider);
  final currentUser = ref.watch(currentUserModelProvider).value;

  if (currentUser == null || requests.isEmpty) return [];

  final List<ConnectedAccount> accounts = [];
  for (final req in requests) {
    final otherId =
        req.senderId == currentUser.uid ? req.receiverId : req.senderId;
    final user = await db.getUser(otherId);
    if (user != null) {
      accounts.add(ConnectedAccount(request: req, otherUser: user));
    }
  }
  return accounts;
});
