import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/connection_request_model.dart';
import '../../../models/private_profile_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/database_service.dart';

class UserProfileSheet extends ConsumerWidget {
  final UserModel nearbyUser;

  const UserProfileSheet({
    super.key,
    required this.nearbyUser,
  });

  Future<void> _launchFacebookUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Facebook profile')),
        );
      }
    }
  }

  Widget _buildAcceptedProfile(
    BuildContext context,
    String userId,
    DatabaseService databaseService,
  ) {
    return StreamBuilder<PrivateProfileModel?>(
      stream: databaseService.streamSharedProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Could not load shared profile: ${snapshot.error}',
            style: const TextStyle(color: Colors.redAccent),
          );
        }
        if (!snapshot.hasData) {
          return const CircularProgressIndicator(color: Colors.cyanAccent);
        }

        final profile = snapshot.data;
        final hasSharedDetails = profile != null &&
            (profile.facebookUrl.isNotEmpty ||
                profile.phoneNumber.isNotEmpty ||
                profile.bio.isNotEmpty);
        if (!hasSharedDetails) {
          return const Text(
            'This person has not shared any contact details.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          );
        }

        return Column(
          children: [
            if (profile.bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  profile.bio,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            if (profile.phoneNumber.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.phoneNumber,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Call',
                    icon: const Icon(Icons.call, color: Colors.greenAccent),
                    onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: profile.phoneNumber),
                    ),
                  ),
                ],
              ),
            if (profile.facebookUrl.isNotEmpty) ...[
              Text(
                profile.facebookUrl,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    _launchFacebookUrl(context, profile.facebookUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Facebook Profile'),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserModelProvider).value;
    if (currentUser == null) return const SizedBox.shrink();

    final dbService = ref.watch(databaseServiceProvider);
    final requestStream = dbService.streamConnectionStatus(
      currentUser.uid,
      nearbyUser.uid,
    );

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: StreamBuilder<ConnectionRequestModel?>(
        stream: requestStream,
        builder: (context, snapshot) {
          final request = snapshot.data;
          final isAccepted = request?.status == RequestStatus.accepted;
          final isPending = request?.status == RequestStatus.pending;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 44,
                backgroundImage: nearbyUser.photoUrl.isNotEmpty
                    ? NetworkImage(nearbyUser.photoUrl)
                    : null,
                backgroundColor: Colors.cyan.shade900,
                child: nearbyUser.photoUrl.isEmpty
                    ? Text(
                        nearbyUser.displayName.isNotEmpty
                            ? nearbyUser.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                nearbyUser.displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_searching,
                      size: 16, color: Colors.cyanAccent),
                  SizedBox(width: 6),
                  Text(
                    'Discovered Nearby',
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- PRIVACY LOCK / REVEAL BOX ---
              if (isAccepted) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open, color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Text(
                            'Connection Accepted!',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildAcceptedProfile(
                        context,
                        nearbyUser.uid,
                        dbService,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: Colors.amberAccent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Contact details are hidden until the connection request is accepted.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (isPending)
                  ElevatedButton.icon(
                    onPressed: null, // Disabled when pending
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon:
                        const Icon(Icons.hourglass_top, color: Colors.white70),
                    label: const Text(
                      'Connection Request Pending',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () async {
                      await dbService.sendConnectionRequest(
                        sender: currentUser,
                        receiverId: nearbyUser.uid,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connection request sent!'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text(
                      'Send Connection Request',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
