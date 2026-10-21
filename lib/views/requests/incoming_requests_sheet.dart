import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/nearby_connections_service.dart';
import '../radar/widgets/user_avatar_node.dart';

class IncomingRequestsSheet extends ConsumerWidget {
  const IncomingRequestsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(nearbyConnectionsProvider);
    final requests = service.incomingRequests;
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
        minHeight: 220,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111719),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Connection Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: requests.isEmpty
                ? const Center(
                    child: Text(
                      'No pending connection requests',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: UserAvatarNode(
                            user: request.toUser(),
                            onTap: () {},
                          ),
                          title: Text(
                            request.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Wants to connect with you'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Accept',
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
                                ),
                                onPressed: () => _respond(
                                  context,
                                  service,
                                  request.endpointId,
                                  accept: true,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _respond(
                                  context,
                                  service,
                                  request.endpointId,
                                  accept: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    NearbyConnectionsService service,
    String endpointId, {
    required bool accept,
  }) async {
    try {
      if (accept) {
        await service.acceptRequest(endpointId);
      } else {
        await service.rejectRequest(endpointId);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not respond to request: $error')),
        );
      }
    }
  }
}
