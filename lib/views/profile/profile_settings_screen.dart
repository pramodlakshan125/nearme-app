import 'package:flutter/material.dart';

import '../history/connected_history_screen.dart';
import 'profile_input_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              leading: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF8DDADC),
              ),
              title: const Text('Edit profile'),
              subtitle: const Text('Name, Facebook URL, photo and visibility'),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileInputScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              leading: const Icon(
                Icons.people_alt_outlined,
                color: Color(0xFF8DDADC),
              ),
              title: const Text('Connected history'),
              subtitle: const Text('View people you have connected with'),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ConnectedHistoryScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
