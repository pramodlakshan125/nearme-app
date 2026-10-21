import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

class LocalProfileStore {
  LocalProfileStore(this._preferences);

  static const _profileKey = 'local_profile';
  static const _contactsKey = 'accepted_contacts';

  final SharedPreferences _preferences;

  UserModel? readProfile() {
    final value = _preferences.getString(_profileKey);
    if (value == null) return null;
    return UserModel.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<UserModel> saveProfile({
    required String name,
    required String facebookUrl,
    String phoneNumber = '',
    bool sharePhone = false,
    required String photoPath,
    required bool isVisible,
    String? uid,
  }) async {
    final profile = UserModel(
      uid: uid ?? DateTime.now().microsecondsSinceEpoch.toString(),
      displayName: name,
      facebookUrl: facebookUrl,
      phoneNumber: phoneNumber,
      sharePhone: sharePhone,
      photoPath: photoPath,
      isVisible: isVisible,
    );
    final saved = await _preferences.setString(
      _profileKey,
      jsonEncode(profile.toJson()),
    );
    if (!saved) throw StateError('Could not save the local profile.');
    return profile;
  }

  Future<String> copyPhotoToAppDirectory(File source) async {
    final directory = await getApplicationDocumentsDirectory();
    final target = File(
      '${directory.path}${Platform.pathSeparator}profile_photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<void> deleteProfilePhoto(String path) async {
    if (path.isEmpty) return;
    final directory = await getApplicationDocumentsDirectory();
    final normalizedPath = File(path).absolute.path;
    final normalizedDirectory = Directory(directory.path).absolute.path;
    final separator = Platform.pathSeparator;
    if (!normalizedPath.startsWith('$normalizedDirectory$separator') ||
        !RegExp(
          r'^profile_photo(?:_\d+)?\.jpg$',
        ).hasMatch(normalizedPath.split(separator).last)) {
      return;
    }
    final file = File(normalizedPath);
    if (await file.exists()) await file.delete();
  }

  List<UserModel> readContacts() {
    final values = _preferences.getStringList(_contactsKey) ?? const [];
    return values
        .map(
          (value) => UserModel.fromStoredContact(
            jsonDecode(value) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> saveContact(UserModel contact) async {
    final contacts = readContacts();
    final index = contacts.indexWhere((item) => item.uid == contact.uid);
    if (index == -1) {
      contacts.add(contact);
    } else {
      contacts[index] = contact;
    }
    final saved = await _preferences.setStringList(
      _contactsKey,
      contacts.map((item) => jsonEncode(item.toJson())).toList(),
    );
    if (!saved) throw StateError('Could not save the local connection.');
  }
}
