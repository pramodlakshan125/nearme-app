import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../models/user_model.dart';

class UserAvatarNode extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const UserAvatarNode({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (user.photoData.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(user.photoData));
      } on FormatException {
        image = null;
      }
    } else if (user.photoPath.isNotEmpty && File(user.photoPath).existsSync()) {
      image = FileImage(File(user.photoPath));
    }
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF56BFC2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF36BFC2).withValues(alpha: 0.16),
                  blurRadius: 8,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundImage: image,
              backgroundColor: const Color(0xFF17383A),
              child: image == null
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFFB9EEEE),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF101516),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              user.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
