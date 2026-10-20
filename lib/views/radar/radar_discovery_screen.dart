import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:near_me/services/ble_service.dart';
import '../../models/active_session_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../requests/incoming_requests_sheet.dart';
import 'widgets/radar_animation_widget.dart';
import 'widgets/user_avatar_node.dart';
import 'widgets/user_profile_sheet.dart';

class RadarDiscoveryScreen extends ConsumerWidget {
  const RadarDiscoveryScreen({super.key});

  Future<void> _toggleDiscovery(BuildContext context, WidgetRef ref) async {
    final bleService = ref.read(bleServiceProvider);
    final dbService = ref.read(databaseServiceProvider);
    final isScanning = ref.read(isScanningProvider);
    final currentUser = ref.read(currentUserModelProvider).value;

    if (currentUser == null) return;

    if (!isScanning) {
      final granted = await bleService.requestPermissions();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Bluetooth & Location permissions are required for radar discovery'),
            ),
          );
        }
        return;
      }

      bleService.startScanning();
      ref.read(isScanningProvider.notifier).state = true;

      // Register Active Session in Firestore
      final session = ActiveSessionModel(
        uid: currentUser.uid,
        bleDeviceId: 'ble_${currentUser.uid.substring(0, 8)}',
        serviceUuid: BleDiscoveryService.appServiceUuid.toString(),
        lastSeen: DateTime.now(),
        isBroadcasting: true,
      );
      await dbService.updateActiveSession(session);
    } else {
      bleService.stopScanning();
      ref.read(isScanningProvider.notifier).state = false;
      await dbService.clearActiveSession(currentUser.uid);
    }
  }

  void _openUserProfileSheet(BuildContext context, UserModel nearbyUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserProfileSheet(nearbyUser: nearbyUser),
    );
  }

  void _openRequestsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IncomingRequestsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserModelProvider).value;
    final isScanning = ref.watch(isScanningProvider);
    final nearbyUsersAsync = ref.watch(nearbyUsersProvider);
    final incomingRequestsAsync = ref.watch(incomingRequestsProvider);

    final incomingCount = incomingRequestsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: currentUser?.photoUrl.isNotEmpty == true
                  ? NetworkImage(currentUser!.photoUrl)
                  : null,
              child: currentUser?.photoUrl.isEmpty == true
                  ? Text(currentUser?.displayName[0].toUpperCase() ?? 'U')
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                currentUser?.displayName ?? 'NearMe',
                style: const TextStyle(fontSize: 16, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.cyanAccent),
                onPressed: () => _openRequestsSheet(context),
              ),
              if (incomingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$incomingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header status
            Text(
              isScanning
                  ? 'Radar Scanning Active...'
                  : 'Radar Idle - Tap button to discover nearby people',
              style: TextStyle(
                color: isScanning ? Colors.cyanAccent : Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            // Radar Visual Area
            Expanded(
              child: nearbyUsersAsync.when(
                data: (users) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final center = Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight / 2,
                      );
                      final radius = math.min(
                              constraints.maxWidth, constraints.maxHeight) *
                          0.38;

                      return RadarAnimationWidget(
                        isScanning: isScanning,
                        child: Stack(
                          children: [
                            // Center User Icon
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.cyanAccent.withOpacity(0.2),
                                  border: Border.all(
                                      color: Colors.cyanAccent, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      currentUser?.photoUrl.isNotEmpty == true
                                          ? NetworkImage(currentUser!.photoUrl)
                                          : null,
                                  child: currentUser?.photoUrl.isEmpty == true
                                      ? const Icon(Icons.person,
                                          color: Colors.white)
                                      : null,
                                ),
                              ),
                            ),

                            // Plot Nearby Users in radial positions around radar
                            ...users.asMap().entries.map((entry) {
                              final index = entry.key;
                              final user = entry.value;

                              // Calculate position angle & distance
                              final angle = (index *
                                      (2 *
                                          math.pi /
                                          math.max(users.length, 1))) +
                                  0.5;
                              final distanceRatio = 0.4 + ((index % 3) * 0.25);
                              final posX = center.dx +
                                  (radius * distanceRatio * math.cos(angle)) -
                                  30;
                              final posY = center.dy +
                                  (radius * distanceRatio * math.sin(angle)) -
                                  30;

                              return Positioned(
                                left: posX,
                                top: posY,
                                child: UserAvatarNode(
                                  user: user,
                                  onTap: () =>
                                      _openUserProfileSheet(context, user),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                ),
                error: (err, stack) => Center(
                  child: Text('Error: $err',
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              ),
            ),

            // Nearby People Horizontal List View below radar
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.black26,
              child: nearbyUsersAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    return const Center(
                      child: Text(
                        'No nearby users discovered yet.',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: UserAvatarNode(
                          user: u,
                          onTap: () => _openUserProfileSheet(context, u),
                        ),
                      );
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: 16),

            // "Discover Nearby People" Button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => _toggleDiscovery(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isScanning ? Colors.redAccent : Colors.cyanAccent,
                  foregroundColor: isScanning ? Colors.white : Colors.black,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 6,
                ),
                icon: Icon(
                  isScanning ? Icons.stop_circle : Icons.radar,
                  size: 26,
                ),
                label: Text(
                  isScanning
                      ? 'Stop Radar Discovery'
                      : 'Discover Nearby People',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
