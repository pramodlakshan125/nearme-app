import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../models/active_session_model.dart';
import '../../models/user_model.dart';
import '../../models/private_profile_model.dart';
import '../../providers/app_providers.dart';
import '../history/connected_history_screen.dart';
import '../requests/incoming_requests_sheet.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _fbUrlController;
  late TextEditingController _phoneController;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isVisible = true;
  bool _shareFacebook = false;
  bool _sharePhoneNumber = false;
  bool _shareBio = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _fbUrlController = TextEditingController();
    _phoneController = TextEditingController();
  }

  void _initFields(UserModel user, PrivateProfileModel privateProfile) {
    if (!_isInitialized) {
      _nameController.text = user.displayName;
      _bioController.text = privateProfile.bio;
      _fbUrlController.text = privateProfile.facebookUrl;
      _phoneController.text = privateProfile.phoneNumber;
      _isVisible = user.isVisible;
      _shareFacebook = privateProfile.shareFacebook;
      _sharePhoneNumber = privateProfile.sharePhoneNumber;
      _shareBio = privateProfile.shareBio;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _fbUrlController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(
    UserModel currentUser,
    PrivateProfileModel currentPrivateProfile,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedUser = currentUser.copyWith(
      displayName: _nameController.text.trim(),
      isVisible: _isVisible,
      lastActive: DateTime.now(),
    );
    final updatedPrivateProfile = PrivateProfileModel(
      facebookUrl: _fbUrlController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      bio: _bioController.text.trim(),
      shareFacebook: _shareFacebook,
      sharePhoneNumber: _sharePhoneNumber,
      shareBio: _shareBio,
    );

    try {
      await ref.read(databaseServiceProvider).createOrUpdateUser(
            updatedUser,
            privateProfile: updatedPrivateProfile,
          );
      await _syncRadarVisibility(currentUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncRadarVisibility(UserModel currentUser) async {
    if (!ref.read(isScanningProvider) || currentUser.isVisible == _isVisible) {
      return;
    }
    final bleService = ref.read(bleServiceProvider);
    final dbService = ref.read(databaseServiceProvider);
    if (_isVisible) {
      final token = bleService.createDiscoveryToken();
      await bleService.startAdvertising(token);
      ref.read(currentDiscoveryTokenProvider.notifier).state = token;
      await dbService.updateActiveSession(
        ActiveSessionModel(
          uid: currentUser.uid,
          discoveryToken: token,
          lastSeen: DateTime.now(),
          isBroadcasting: true,
        ),
      );
    } else {
      await bleService.stopAdvertising();
      ref.read(currentDiscoveryTokenProvider.notifier).state = null;
      await dbService.clearActiveSession(currentUser.uid);
    }
  }

  Future<void> _changeProfilePhoto(UserModel user) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image == null || !mounted) return;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://api.cloudinary.com/v1_1/dnn94io0q/image/upload',
        ),
      )
        ..fields['upload_preset'] = 'nearme_profile'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            await image.readAsBytes(),
            filename: image.name,
          ),
        );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed (${response.statusCode}): ${response.body}',
        );
      }

      final responseData = jsonDecode(response.body);
      if (responseData is! Map<String, dynamic> ||
          responseData['secure_url'] is! String ||
          (responseData['secure_url'] as String).isEmpty) {
        throw const FormatException(
          'Cloudinary response did not include a secure_url.',
        );
      }
      final photoUrl = responseData['secure_url'] as String;

      await ref.read(databaseServiceProvider).updateUserPhoto(
            uid: user.uid,
            photoUrl: photoUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to sign out from NearMe?',
          style: TextStyle(color: Colors.white70),
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
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentUser = ref.read(currentUserModelProvider).value;
      final bleService = ref.read(bleServiceProvider);
      bleService.stopScanning();
      await bleService.stopAdvertising();
      ref.read(isScanningProvider.notifier).state = false;
      ref.read(currentDiscoveryTokenProvider.notifier).state = null;
      if (currentUser != null) {
        await ref
            .read(databaseServiceProvider)
            .clearActiveSession(currentUser.uid);
      }
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);
    final privateProfileAsync = ref.watch(currentPrivateProfileProvider);
    final acceptedAsync = ref.watch(acceptedConnectionsProvider);
    final incomingAsync = ref.watch(incomingRequestsProvider);

    final acceptedCount = acceptedAsync.value?.length ?? 0;
    final incomingCount = incomingAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F2027),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text(
                'User profile not found',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final privateProfile = privateProfileAsync.value;
          if (privateProfile == null) {
            if (privateProfileAsync.hasError) {
              return Center(
                child: Text(
                  'Error loading private profile: ${privateProfileAsync.error}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          }

          _initFields(user, privateProfile);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar Header
                    Center(
                      child: Stack(
                        children: [
                          InkWell(
                            onTap: _isUploadingPhoto
                                ? null
                                : () => _changeProfilePhoto(user),
                            customBorder: const CircleBorder(),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.cyanAccent,
                              child: CircleAvatar(
                                radius: 49,
                                backgroundImage: user.photoUrl.isNotEmpty
                                    ? NetworkImage(user.photoUrl)
                                    : null,
                                backgroundColor: const Color(0xFF1A2A3A),
                                child: user.photoUrl.isEmpty
                                    ? Text(
                                        user.displayName.isNotEmpty
                                            ? user.displayName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.cyanAccent,
                                shape: BoxShape.circle,
                              ),
                              child: _isUploadingPhoto
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        ref.read(authServiceProvider).currentUser?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Navigation Hub
                    Row(
                      children: [
                        // Connected Accounts Card
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ConnectedHistoryScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2A3A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Icon(Icons.people_alt,
                                          color: Colors.cyanAccent, size: 24),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.cyanAccent
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$acceptedCount',
                                          style: const TextStyle(
                                            color: Colors.cyanAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Connected Accounts',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    'View friends & links',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Incoming Requests Card
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const IncomingRequestsSheet(),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2A3A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: incomingCount > 0
                                      ? Colors.amberAccent
                                      : Colors.white24,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(
                                        Icons.notifications,
                                        color: incomingCount > 0
                                            ? Colors.amberAccent
                                            : Colors.white60,
                                        size: 24,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: incomingCount > 0
                                              ? Colors.amberAccent
                                                  .withValues(alpha: 0.2)
                                              : Colors.white12,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$incomingCount',
                                          style: TextStyle(
                                            color: incomingCount > 0
                                                ? Colors.amberAccent
                                                : Colors.white60,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Requests',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    'Pending invites',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'EDIT PROFILE DETAILS',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Name
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: Colors.cyanAccent),
                        filled: true,
                        fillColor: const Color(0xFF1A2A3A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Colors.cyanAccent, width: 1.5),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Display name cannot be empty'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Bio / Status
                    TextFormField(
                      controller: _bioController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: 'Bio / Status (Optional)',
                        hintText:
                            'e.g. Flutter developer passionate about tech & coffee!',
                        hintStyle: const TextStyle(
                            color: Colors.white30, fontSize: 13),
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.info_outline,
                            color: Colors.cyanAccent),
                        counterStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1A2A3A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Colors.cyanAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _shareSetting(
                      title: 'Share bio after connection',
                      value: _shareBio,
                      onChanged: (value) => setState(() => _shareBio = value),
                    ),
                    const SizedBox(height: 8),

                    Material(
                      color: const Color(0xFF1A2A3A),
                      borderRadius: BorderRadius.circular(16),
                      child: SwitchListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        value: _isVisible,
                        onChanged: (visible) =>
                            setState(() => _isVisible = visible),
                        activeThumbColor: Colors.cyanAccent,
                        title: const Text(
                          'Visible on Radar',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Let nearby people see your profile',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Facebook URL
                    TextFormField(
                      controller: _fbUrlController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Facebook Profile URL',
                        hintText: 'https://facebook.com/your.username',
                        hintStyle: const TextStyle(
                            color: Colors.white30, fontSize: 13),
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon:
                            const Icon(Icons.link, color: Colors.cyanAccent),
                        filled: true,
                        fillColor: const Color(0xFF1A2A3A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Colors.cyanAccent, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter your Facebook profile link';
                        }
                        if (!val.contains('facebook.com') &&
                            !val.contains('fb.com')) {
                          return 'Enter a valid Facebook URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    _shareSetting(
                      title: 'Share Facebook link after connection',
                      value: _shareFacebook,
                      onChanged: (value) =>
                          setState(() => _shareFacebook = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number (Optional)',
                        hintText: '+94 77 123 4567',
                        hintStyle: const TextStyle(color: Colors.white30),
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.phone_outlined,
                            color: Colors.cyanAccent),
                        filled: true,
                        fillColor: const Color(0xFF1A2A3A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _shareSetting(
                      title: 'Share phone number after connection',
                      value: _sharePhoneNumber,
                      onChanged: (value) =>
                          setState(() => _sharePhoneNumber = value),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock, size: 14, color: Colors.white54),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Selected contact details are shared only with accepted connections.',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    _isSaving || _isUploadingPhoto
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.cyanAccent),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _saveProfile(user, privateProfile),
                            icon: const Icon(Icons.save_rounded),
                            label: const Text(
                              'Save Changes',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _shareSetting({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.cyanAccent,
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      subtitle: const Text(
        'Only visible to accepted connections',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}
