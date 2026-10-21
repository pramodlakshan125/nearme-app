import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/active_session_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../requests/incoming_requests_sheet.dart';
import '../profile/profile_settings_screen.dart';
import 'widgets/radar_animation_widget.dart';
import 'widgets/user_avatar_node.dart';
import 'widgets/user_profile_sheet.dart';

class RadarDiscoveryScreen extends ConsumerStatefulWidget {
  const RadarDiscoveryScreen({super.key});

  @override
  ConsumerState<RadarDiscoveryScreen> createState() =>
      _RadarDiscoveryScreenState();
}

class _RadarDiscoveryScreenState extends ConsumerState<RadarDiscoveryScreen> {
  Timer? _presenceHeartbeat;

  @override
  void dispose() {
    _presenceHeartbeat?.cancel();
    super.dispose();
  }

  Future<void> _toggleDiscovery(BuildContext context) async {
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
                  'Bluetooth and nearby-device permissions are required for Radar discovery'),
            ),
          );
        }
        return;
      }

      try {
        await bleService.startScanning();
        if (currentUser.isVisible) {
          await _startPresence(currentUser.uid);
        }
        ref.read(isScanningProvider.notifier).state = true;
        _presenceHeartbeat?.cancel();
        _presenceHeartbeat = Timer.periodic(
          const Duration(seconds: 20),
          (_) => _refreshPresence(),
        );
      } catch (error) {
        bleService.stopScanning();
        try {
          await bleService.stopAdvertising();
        } catch (cleanupError) {
          debugPrint('BLE advertising cleanup failed: $cleanupError');
        }
        ref.read(currentDiscoveryTokenProvider.notifier).state = null;
        ref.read(isScanningProvider.notifier).state = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is TimeoutException
                    ? 'Turn on Bluetooth and try again.'
                    : 'Could not start Radar: $error',
              ),
            ),
          );
        }
      }
    } else {
      bleService.stopScanning();
      try {
        await bleService.stopAdvertising();
        await dbService.clearActiveSession(currentUser.uid);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not stop Radar cleanly: $error')),
          );
        }
      } finally {
        _presenceHeartbeat?.cancel();
        _presenceHeartbeat = null;
        ref.read(currentDiscoveryTokenProvider.notifier).state = null;
        ref.read(isScanningProvider.notifier).state = false;
      }
    }
  }

  Future<void> _startPresence(String uid) async {
    final bleService = ref.read(bleServiceProvider);
    final dbService = ref.read(databaseServiceProvider);
    final token = bleService.createDiscoveryToken();
    await bleService.startAdvertising(token);
    ref.read(currentDiscoveryTokenProvider.notifier).state = token;

    await dbService.updateActiveSession(
      ActiveSessionModel(
        uid: uid,
        discoveryToken: token,
        lastSeen: DateTime.now(),
        isBroadcasting: true,
      ),
    );
  }

  Future<void> _refreshPresence() async {
    final user = ref.read(currentUserModelProvider).value;
    final token = ref.read(currentDiscoveryTokenProvider);
    if (user == null || token == null || !user.isVisible) return;
    try {
      await ref.read(databaseServiceProvider).updateActiveSession(
            ActiveSessionModel(
              uid: user.uid,
              discoveryToken: token,
              lastSeen: DateTime.now(),
              isBroadcasting: true,
            ),
          );
    } catch (error) {
      debugPrint('Radar presence update failed: $error');
    }
  }

  Future<void> _signOut() async {
    try {
      if (ref.read(isScanningProvider)) {
        await _toggleDiscovery(context);
      } else {
        await ref.read(bleServiceProvider).stopAdvertising();
        final currentUser = ref.read(currentUserModelProvider).value;
        if (currentUser != null) {
          await ref
              .read(databaseServiceProvider)
              .clearActiveSession(currentUser.uid);
        }
      }
      await ref.read(authServiceProvider).signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not stop Radar: $error')),
        );
      }
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
  Widget build(BuildContext context) {
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
        title: Tooltip(
          message: 'Profile & Settings',
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileSettingsScreen(),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: currentUser?.photoUrl.isNotEmpty == true
                      ? NetworkImage(currentUser!.photoUrl)
                      : null,
                  child: currentUser?.photoUrl.isEmpty == true
                      ? Text(
                          currentUser?.displayName.isNotEmpty == true
                              ? currentUser!.displayName[0].toUpperCase()
                              : 'U',
                        )
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
          ),
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
            onPressed: _signOut,
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
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.2),
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
                onPressed: () => _toggleDiscovery(context),
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
