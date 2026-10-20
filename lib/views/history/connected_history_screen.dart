import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_providers.dart';
import '../radar/widgets/user_profile_sheet.dart';

class ConnectedHistoryScreen extends ConsumerStatefulWidget {
  const ConnectedHistoryScreen({super.key});

  @override
  ConsumerState<ConnectedHistoryScreen> createState() =>
      _ConnectedHistoryScreenState();
}

class _ConnectedHistoryScreenState
    extends ConsumerState<ConnectedHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Facebook link')),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDisconnect(
      BuildContext context, ConnectedAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disconnect Account',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to disconnect with ${account.otherUser.displayName}? This will remove them from your connected history.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(databaseServiceProvider)
          .removeConnection(account.request.requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from ${account.otherUser.displayName}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedAccountsAsync = ref.watch(connectedAccountsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        title: const Text(
          'Connected Accounts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search connections by name...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.cyanAccent),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1A2A3A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Content List
            Expanded(
              child: connectedAccountsAsync.when(
                data: (accounts) {
                  final filtered = accounts.where((acc) {
                    if (_searchQuery.isEmpty) return true;
                    return acc.otherUser.displayName
                        .toLowerCase()
                        .contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState(accounts.isEmpty);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildConnectionCard(context, item);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    'Error loading connections: $err',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyanAccent.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isCompletelyEmpty
                  ? 'No Connected Accounts Yet'
                  : 'No Matches Found',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCompletelyEmpty
                  ? 'When you accept proximity connection requests on the Radar, your friends and their unlocked social links will appear here.'
                  : 'Try searching with a different name.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, ConnectedAccount item) {
    final user = item.otherUser;
    final dateStr =
        '${item.request.timestamp.day}/${item.request.timestamp.month}/${item.request.timestamp.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.25),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => UserProfileSheet(nearbyUser: user),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: user.photoUrl.isNotEmpty
                        ? NetworkImage(user.photoUrl)
                        : null,
                    backgroundColor: Colors.cyan.shade900,
                    child: user.photoUrl.isEmpty
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user.bio.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.bio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 4),
                            Text(
                              'Connected $dateStr',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white60),
                    color: const Color(0xFF1E3246),
                    onSelected: (val) {
                      if (val == 'disconnect') {
                        _confirmDisconnect(context, item);
                      } else if (val == 'copy') {
                        _copyToClipboard(user.facebookUrl);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 18, color: Colors.white70),
                            SizedBox(width: 10),
                            Text('Copy Link',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'disconnect',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove,
                                size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Disconnect',
                                style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Facebook Link Action Button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1877F2).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _launchUrl(user.facebookUrl),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.facebook,
                                  color: Color(0xFF1877F2), size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  user.facebookUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.cyanAccent,
                                  ),
                                ),
                              ),
                              const Icon(Icons.open_in_new,
                                  size: 16, color: Colors.cyanAccent),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          size: 18, color: Colors.white70),
                      tooltip: 'Copy Facebook link',
                      onPressed: () => _copyToClipboard(user.facebookUrl),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
