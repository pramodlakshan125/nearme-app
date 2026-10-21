import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/app_notification_service.dart';
import '../services/local_profile_store.dart';
import '../services/nearby_connections_service.dart';

final initialProfileProvider = Provider<UserModel?>((ref) => null);
final currentUserModelProvider = StateProvider<UserModel?>(
  (ref) => ref.watch(initialProfileProvider),
);
final localProfileStoreProvider = Provider<LocalProfileStore>(
  (ref) => throw StateError('LocalProfileStore was not initialized.'),
);
final appNotificationServiceProvider = Provider<AppNotificationService>(
  (ref) => throw StateError('AppNotificationService was not initialized.'),
);
final nearbyConnectionsProvider =
    ChangeNotifierProvider<NearbyConnectionsService>(
      (ref) => NearbyConnectionsService(
        ref.watch(localProfileStoreProvider),
        ref.watch(appNotificationServiceProvider),
      ),
    );
