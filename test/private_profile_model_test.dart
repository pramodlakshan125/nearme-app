import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/models/private_profile_model.dart';
import 'package:near_me/models/user_model.dart';

void main() {
  group('PrivateProfileModel', () {
    test('does not share contact details by default', () {
      const profile = PrivateProfileModel(
        facebookUrl: 'https://facebook.com/example',
        phoneNumber: '+94771234567',
        bio: 'Hello',
      );

      expect(profile.toSharedMap(), isEmpty);
    });

    test('shares only the fields individually enabled by the owner', () {
      const profile = PrivateProfileModel(
        facebookUrl: 'https://facebook.com/example',
        phoneNumber: '+94771234567',
        bio: 'Hello',
        shareFacebook: true,
        shareBio: true,
      );

      expect(profile.toSharedMap(), {
        'facebookUrl': 'https://facebook.com/example',
        'bio': 'Hello',
      });
    });
  });

  test('public user data excludes private contact details', () {
    final user = UserModel(
      uid: 'user-id',
      displayName: 'NearMe User',
      photoUrl: 'https://example.com/photo.png',
      createdAt: DateTime(2026),
      lastActive: DateTime(2026),
    );

    expect(user.toMap().keys, isNot(contains('facebookUrl')));
    expect(user.toMap().keys, isNot(contains('phoneNumber')));
    expect(user.toMap().keys, isNot(contains('bio')));
    expect(user.toMap().keys, isNot(contains('email')));
  });
}
