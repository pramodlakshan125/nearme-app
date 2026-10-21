import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/models/user_model.dart';

void main() {
  test('presence data does not include the private Facebook URL', () {
    const user = UserModel(
      uid: 'user-id',
      displayName: 'NearMe User',
      facebookUrl: 'https://facebook.com/example',
      phoneNumber: '+94771234567',
      sharePhone: true,
      photoData: 'thumbnail-bytes',
    );

    expect(user.toPresence(), {
      'type': 'profile',
      'name': 'NearMe User',
      'photo': 'thumbnail-bytes',
    });
    expect(user.toPresence().containsKey('phoneNumber'), isFalse);
  });
}
