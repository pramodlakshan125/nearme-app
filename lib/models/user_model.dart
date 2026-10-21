import 'dart:convert';

class UserModel {
  const UserModel({
    required this.uid,
    required this.displayName,
    this.facebookUrl = '',
    this.phoneNumber = '',
    this.sharePhone = false,
    this.photoPath = '',
    this.photoData = '',
    this.isVisible = true,
  });

  final String uid;
  final String displayName;
  final String facebookUrl;
  final String phoneNumber;
  final bool sharePhone;
  final String photoPath;
  final String photoData;
  final bool isVisible;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'facebookUrl': facebookUrl,
        'phoneNumber': phoneNumber,
        'sharePhone': sharePhone,
        'photoPath': photoPath,
        'photoData': photoData,
        'isVisible': isVisible,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        uid: json['uid'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        facebookUrl: json['facebookUrl'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        sharePhone: json['sharePhone'] as bool? ?? false,
        photoPath: json['photoPath'] as String? ?? '',
        photoData: json['photoData'] as String? ?? '',
        isVisible: json['isVisible'] as bool? ?? true,
      );

  factory UserModel.fromPresence(Map<String, dynamic> json, String endpointId) {
    final photo = json['photo'] as String? ?? '';
    return UserModel(
      uid: endpointId,
      displayName: json['name'] as String? ?? 'Nearby user',
      photoData: photo,
    );
  }

  factory UserModel.fromStoredContact(Map<String, dynamic> json) =>
      UserModel.fromJson(json);

  Map<String, dynamic> toPresence() => {
        'type': 'profile',
        'name': displayName,
        'photo': photoData,
      };

  UserModel copyWith({
    String? displayName,
    String? facebookUrl,
    String? phoneNumber,
    bool? sharePhone,
    String? photoPath,
    bool? visible,
  }) =>
      UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
        facebookUrl: facebookUrl ?? this.facebookUrl,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        sharePhone: sharePhone ?? this.sharePhone,
        photoPath: photoPath ?? this.photoPath,
        photoData: photoData,
        isVisible: visible ?? isVisible,
      );

  static String encode(List<UserModel> users) =>
      jsonEncode(users.map((user) => user.toJson()).toList());
}

class IncomingRequest {
  const IncomingRequest({
    required this.endpointId,
    required this.displayName,
    required this.photoData,
  });

  final String endpointId;
  final String displayName;
  final String photoData;

  UserModel toUser() => UserModel(
        uid: endpointId,
        displayName: displayName,
        photoData: photoData,
      );
}
