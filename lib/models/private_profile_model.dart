class PrivateProfileModel {
  final String facebookUrl;
  final String phoneNumber;
  final String bio;
  final bool shareFacebook;
  final bool sharePhoneNumber;
  final bool shareBio;

  const PrivateProfileModel({
    this.facebookUrl = '',
    this.phoneNumber = '',
    this.bio = '',
    this.shareFacebook = false,
    this.sharePhoneNumber = false,
    this.shareBio = false,
  });

  factory PrivateProfileModel.fromMap(Map<String, dynamic> map) {
    return PrivateProfileModel(
      facebookUrl: map['facebookUrl'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      shareFacebook: map['shareFacebook'] as bool? ?? false,
      sharePhoneNumber: map['sharePhoneNumber'] as bool? ?? false,
      shareBio: map['shareBio'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toPrivateMap() => {
        'facebookUrl': facebookUrl,
        'phoneNumber': phoneNumber,
        'bio': bio,
        'shareFacebook': shareFacebook,
        'sharePhoneNumber': sharePhoneNumber,
        'shareBio': shareBio,
      };

  Map<String, dynamic> toSharedMap() => {
        if (shareFacebook && facebookUrl.isNotEmpty) 'facebookUrl': facebookUrl,
        if (sharePhoneNumber && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
        if (shareBio && bio.isNotEmpty) 'bio': bio,
      };
}
