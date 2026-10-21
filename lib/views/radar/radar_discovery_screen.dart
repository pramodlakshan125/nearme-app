import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../services/nearby_connections_service.dart';
import '../history/connected_history_screen.dart';
import '../profile/profile_input_screen.dart';
import '../requests/incoming_requests_sheet.dart';
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
  @override
  void dispose() {
    unawaited(
      ref.read(nearbyConnectionsProvider).stop().catchError((Object error) {
        debugPrint('Could not stop Nearby when Radar closed: $error');
      }),
    );
    super.dispose();
  }

  Future<void> _toggleRadar(
    BuildContext context,
    UserModel profile,
    NearbyConnectionsService service,
  ) async {
    try {
      if (service.isScanning) {
        await service.stop();
      } else {
        await service.start(profile);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start Radar: $error')),
        );
      }
    }
  }

  void _showRequests(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IncomingRequestsSheet(),
    );
  }

  void _showPeer(BuildContext context, UserModel user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserProfileSheet(nearbyUser: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider)!;
    final service = ref.watch(nearbyConnectionsProvider);
    final peers = service.peers;
    final incomingCount = service.incomingRequests.length;
    final hasPhoto =
        user.photoPath.isNotEmpty && File(user.photoPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileInputScreen())),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundImage: hasPhoto
                    ? FileImage(File(user.photoPath))
                    : null,
                backgroundColor: const Color(0xFF17383A),
                child: hasPhoto
                    ? null
                    : Text(
                        user.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFB9EEEE),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(user.displayName, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Connected history',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConnectedHistoryScreen()),
            ),
          ),
          Stack(
            children: [
              IconButton(
                tooltip: 'Connection requests',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _showRequests(context),
              ),
              if (incomingCount > 0)
                Positioned(
                  right: 8,
                  top: 7,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.redAccent,
                    child: Text(
                      '$incomingCount',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              !Platform.isAndroid
                  ? 'Nearby device discovery is supported on Android only.'
                  : service.isScanning
                  ? 'Searching for nearby devices'
                  : 'Discover people around you',
              style: TextStyle(
                color: service.isScanning
                    ? const Color(0xFF8DDADC)
                    : Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (service.error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  service.error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            if (service.notificationPermissionGranted == false)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  'Notifications are off. Enable them in Android app settings '
                  'to hear about requests while NearMe is in the background.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFFFCC80), fontSize: 12),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final center = Offset(
                    constraints.maxWidth / 2,
                    constraints.maxHeight / 2,
                  );
                  final radius =
                      math.min(constraints.maxWidth, constraints.maxHeight) *
                      0.38;
                  return RadarAnimationWidget(
                    isScanning: service.isScanning,
                    child: Stack(
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: hasPhoto
                                ? FileImage(File(user.photoPath))
                                : null,
                            child: hasPhoto
                                ? null
                                : const Icon(Icons.person, color: Colors.white),
                          ),
                        ),
                        ...peers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final angle =
                              index * (2 * math.pi / peers.length) + .5;
                          final ratio = .4 + (index % 3) * .2;
                          return Positioned(
                            left:
                                center.dx +
                                radius * ratio * math.cos(angle) -
                                30,
                            top:
                                center.dy +
                                radius * ratio * math.sin(angle) -
                                34,
                            child: UserAvatarNode(
                              user: entry.value,
                              onTap: () => _showPeer(context, entry.value),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 100,
              child: peers.isEmpty
                  ? const Center(
                      child: Text(
                        'No nearby users discovered yet.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final peer in peers)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: UserAvatarNode(
                              user: peer,
                              onTap: () => _showPeer(context, peer),
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: ElevatedButton.icon(
                onPressed: Platform.isAndroid
                    ? () => _toggleRadar(context, user, service)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: service.isScanning
                      ? const Color(0xFF713B41)
                      : const Color(0xFF16777B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: Icon(
                  service.isScanning ? Icons.stop_circle : Icons.radar,
                ),
                label: Text(
                  service.isScanning ? 'Stop Radar' : 'Discover Nearby People',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
