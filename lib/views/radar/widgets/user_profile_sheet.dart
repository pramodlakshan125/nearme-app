import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/user_model.dart';
import '../../../providers/app_providers.dart';

class UserProfileSheet extends ConsumerWidget {
  const UserProfileSheet({super.key, required this.nearbyUser});

  final UserModel nearbyUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(nearbyConnectionsProvider);
    final matchingContacts = service.acceptedContacts.where(
      (item) => item.uid == nearbyUser.uid,
    );
    final contact = matchingContacts.isEmpty ? null : matchingContacts.first;
    final isPending = service.isRequestPending(nearbyUser.uid);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF111719),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.cyan.shade900,
              child: Text(
                nearbyUser.displayName.isEmpty
                    ? '?'
                    : nearbyUser.displayName[0].toUpperCase(),
                style: const TextStyle(fontSize: 30),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              nearbyUser.displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Nearby device',
              style: TextStyle(color: Color(0xFF8DDADC)),
            ),
            const SizedBox(height: 20),
            if (contact != null) ...[
              if (contact.facebookUrl.isNotEmpty)
                _SharedDetail(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  value: contact.facebookUrl,
                  onOpen: () => _openFacebook(context, contact.facebookUrl),
                ),
              if (contact.phoneNumber.isNotEmpty)
                _SharedDetail(
                  icon: Icons.phone,
                  label: 'Phone number',
                  value: contact.phoneNumber,
                ),
              if (contact.facebookUrl.isEmpty && contact.phoneNumber.isEmpty)
                const Text(
                  'You are connected, but no contact details were shared.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
            ] else ...[
              const Text(
                'Contact details stay private until the request is accepted.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isPending
                      ? null
                      : () async {
                          try {
                            await service.sendConnectionRequest(nearbyUser.uid);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not send request: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: Icon(
                    isPending ? Icons.hourglass_top : Icons.person_add,
                  ),
                  label: Text(
                    isPending ? 'Request pending' : 'Send connection request',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SharedDetail extends StatelessWidget {
  const _SharedDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.onOpen,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF8DDADC)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8DDADC)),
          ),
          if (onOpen != null)
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Facebook'),
            ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$label copied')));
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text('Copy $label'),
          ),
        ],
      ),
    );
  }
}

Future<void> _openFacebook(BuildContext context, String facebookUrl) async {
  final uri = Uri.tryParse(facebookUrl);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      !(uri.host == 'facebook.com' || uri.host.endsWith('.facebook.com'))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This Facebook link is invalid')),
    );
    return;
  }

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open Facebook')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Facebook: $error')),
      );
    }
  }
}
