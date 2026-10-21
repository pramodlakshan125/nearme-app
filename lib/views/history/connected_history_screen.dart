import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/app_providers.dart';

class ConnectedHistoryScreen extends ConsumerWidget {
  const ConnectedHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(nearbyConnectionsProvider).acceptedContacts;
    return Scaffold(
      appBar: AppBar(title: const Text('Connected History')),
      body: contacts.isEmpty
          ? const Center(
              child: Text(
                'Accepted connections will appear here.',
                style: TextStyle(color: Colors.white60),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                ImageProvider? photo;
                if (contact.photoData.isNotEmpty) {
                  try {
                    photo = MemoryImage(base64Decode(contact.photoData));
                  } on FormatException {
                    photo = null;
                  }
                }
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF17383A),
                      backgroundImage: photo,
                      child: photo == null
                          ? Text(
                              contact.displayName.isNotEmpty
                                  ? contact.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFFB9EEEE),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      contact.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          if (contact.facebookUrl.isNotEmpty)
                            'Facebook: ${contact.facebookUrl}',
                          if (contact.phoneNumber.isNotEmpty)
                            'Phone: ${contact.phoneNumber}',
                          if (contact.facebookUrl.isEmpty &&
                              contact.phoneNumber.isEmpty)
                            'No contact details shared',
                        ].join('\n'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing:
                        contact.facebookUrl.isEmpty &&
                            contact.phoneNumber.isEmpty
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (contact.facebookUrl.isNotEmpty)
                                IconButton(
                                  tooltip: 'Open Facebook',
                                  icon: const Icon(Icons.facebook),
                                  onPressed: () => _openFacebook(
                                    context,
                                    contact.facebookUrl,
                                  ),
                                ),
                              PopupMenuButton<String>(
                                tooltip: 'Copy contact detail',
                                icon: const Icon(Icons.copy),
                                onSelected: (value) async {
                                  await Clipboard.setData(
                                    ClipboardData(text: value),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Contact detail copied'),
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (contact.facebookUrl.isNotEmpty)
                                    PopupMenuItem(
                                      value: contact.facebookUrl,
                                      child: const Text('Copy Facebook URL'),
                                    ),
                                  if (contact.phoneNumber.isNotEmpty)
                                    PopupMenuItem(
                                      value: contact.phoneNumber,
                                      child: const Text('Copy phone number'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                  ),
                );
              },
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
