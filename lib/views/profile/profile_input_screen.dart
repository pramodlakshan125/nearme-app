import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';

class ProfileInputScreen extends ConsumerStatefulWidget {
  const ProfileInputScreen({super.key});

  @override
  ConsumerState<ProfileInputScreen> createState() => _ProfileInputScreenState();
}

class _ProfileInputScreenState extends ConsumerState<ProfileInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fbUrlController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authServiceProvider).currentUser;
    if (authUser != null) {
      _nameController.text = authUser.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fbUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final authUser = ref.read(authServiceProvider).currentUser;
    if (authUser == null) return;

    final user = UserModel(
      uid: authUser.uid,
      displayName: _nameController.text.trim(),
      email: authUser.email ?? '',
      photoUrl: authUser.photoURL ?? '',
      facebookUrl: _fbUrlController.text.trim(),
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
    );

    try {
      await ref.read(databaseServiceProvider).createOrUpdateUser(user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authServiceProvider).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: authUser?.photoURL != null
                          ? NetworkImage(authUser!.photoURL!)
                          : null,
                      backgroundColor: Colors.cyan.shade900,
                      child: authUser?.photoURL == null
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.person_outline, color: Colors.cyanAccent),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Enter your display name' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _fbUrlController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Facebook Profile URL',
                      hintText: 'https://facebook.com/your.profile',
                      hintStyle: const TextStyle(color: Colors.white38),
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.link, color: Colors.cyanAccent),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.white30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter your Facebook profile link';
                      }
                      if (!val.contains('facebook.com') && !val.contains('fb.com')) {
                        return 'Enter a valid Facebook profile URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '🔒 Privacy Note: Your Facebook profile link is strictly kept private and only revealed to users whose connection request you accept.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                      : ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Save & Continue to Radar',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
