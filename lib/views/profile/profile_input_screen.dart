import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/app_providers.dart';

class ProfileInputScreen extends ConsumerStatefulWidget {
  const ProfileInputScreen({super.key});

  @override
  ConsumerState<ProfileInputScreen> createState() => _ProfileInputScreenState();
}

class _ProfileInputScreenState extends ConsumerState<ProfileInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _facebookController = TextEditingController();
  String _photoPath = '';
  String _pickedPhotoPath = '';
  bool _removeExistingPhoto = false;
  bool _visible = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserModelProvider);
    if (profile != null) {
      _nameController.text = profile.displayName;
      _facebookController.text = profile.facebookUrl;
      _photoPath = profile.photoPath;
      _visible = profile.isVisible;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _facebookController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (image == null) return;
      if (mounted) {
        setState(() {
          _pickedPhotoPath = image.path;
          _removeExistingPhoto = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile photo: $error')),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _pickedPhotoPath = '';
      _removeExistingPhoto = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    String? copiedPhotoPath;
    var profileSaved = false;
    try {
      final previous = ref.read(currentUserModelProvider);
      final store = ref.read(localProfileStoreProvider);
      var photoPath = _removeExistingPhoto ? '' : _photoPath;
      if (_pickedPhotoPath.isNotEmpty) {
        copiedPhotoPath = await store.copyPhotoToAppDirectory(
          File(_pickedPhotoPath),
        );
        photoPath = copiedPhotoPath;
      }
      final profile = await store.saveProfile(
        name: _nameController.text.trim(),
        facebookUrl: _facebookController.text.trim(),
        photoPath: photoPath,
        isVisible: _visible,
        uid: previous?.uid,
      );
      profileSaved = true;
      ref.read(currentUserModelProvider.notifier).state = profile;
      if (previous != null &&
          previous.photoPath.isNotEmpty &&
          previous.photoPath != photoPath) {
        await store.deleteProfilePhoto(previous.photoPath);
      }
      await ref.read(nearbyConnectionsProvider).updateProfile(profile);
      if (mounted && previous != null) Navigator.of(context).pop();
    } catch (error) {
      if (copiedPhotoPath != null && !profileSaved) {
        await ref
            .read(localProfileStoreProvider)
            .deleteProfilePhoto(copiedPhotoPath);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = ref.watch(currentUserModelProvider) != null;
    final displayedPhotoPath = _pickedPhotoPath.isNotEmpty
        ? _pickedPhotoPath
        : _removeExistingPhoto
        ? ''
        : _photoPath;
    final photoExists =
        displayedPhotoPath.isNotEmpty && File(displayedPhotoPath).existsSync();
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit Profile' : 'Create Your Profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: const Color(0xFF17383A),
                    backgroundImage: photoExists
                        ? FileImage(File(displayedPhotoPath))
                        : null,
                    child: photoExists
                        ? null
                        : const Icon(
                            Icons.person,
                            size: 42,
                            color: Color(0xFFB9EEEE),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickPhoto,
                        icon: Icon(
                          photoExists ? Icons.edit : Icons.add_a_photo,
                        ),
                        label: Text(photoExists ? 'Change photo' : 'Add photo'),
                      ),
                      if (photoExists)
                        TextButton.icon(
                          onPressed: _saving ? null : _removePhoto,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Profile photo is optional',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _facebookController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Facebook profile URL',
                  hintText: 'https://facebook.com/your.profile',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final url = value?.trim() ?? '';
                  if (url.isEmpty) return 'Enter your Facebook profile URL';
                  final uri = Uri.tryParse(url);
                  if (uri == null ||
                      !uri.hasScheme ||
                      !(uri.host == 'facebook.com' ||
                          uri.host.endsWith('.facebook.com') ||
                          uri.host == 'fb.com' ||
                          uri.host.endsWith('.fb.com'))) {
                    return 'Enter a valid Facebook URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible to nearby devices'),
                subtitle: const Text(
                  'Turn this off to discover others without sharing your profile.',
                ),
                value: _visible,
                onChanged: (value) => setState(() => _visible = value),
              ),
              const SizedBox(height: 18),
              const Text(
                'Your name and a small photo preview are shared with nearby devices. Your Facebook URL is sent only after you accept a connection request.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(editing ? 'Save Profile' : 'Save & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
