import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/models/user_model.dart';
import 'package:near_me/services/local_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile and accepted contacts persist locally', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = LocalProfileStore(preferences);

    final profile = await store.saveProfile(
      name: 'NearMe User',
      facebookUrl: 'https://facebook.com/example',
      phoneNumber: '+94771234567',
      sharePhone: true,
      photoPath: 'profile_photo.jpg',
      isVisible: false,
      uid: 'local-user',
    );
    await store.saveContact(
      const UserModel(
        uid: 'nearby-endpoint',
        displayName: 'Nearby Friend',
        facebookUrl: 'https://facebook.com/friend',
        photoData: 'thumbnail',
      ),
    );

    expect(store.readProfile()?.toJson(), profile.toJson());
    expect(store.readProfile()?.isVisible, isFalse);
    expect(store.readProfile()?.phoneNumber, '+94771234567');
    expect(store.readProfile()?.sharePhone, isTrue);
    expect(
        store.readContacts().single.facebookUrl, 'https://facebook.com/friend');
  });
}
