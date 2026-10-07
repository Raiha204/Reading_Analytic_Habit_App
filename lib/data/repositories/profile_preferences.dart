import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePreferences {
  ProfilePreferences._();

  static final instance = ProfilePreferences._();
  final _preferences = SharedPreferencesAsync();

  Future<Uint8List?> pickAvatarBytes() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('That image could not be read. Choose another image.');
    }
    final maxBytes = kIsWeb ? 900 * 1024 : 5 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      final limit = kIsWeb ? '900 KB' : '5 MB';
      throw StateError('Please choose an image smaller than $limit.');
    }
    return bytes;
  }

  Future<void> saveAvatar(String uid, Uint8List bytes) async {
    final key = _key(uid);
    if (kIsWeb) {
      await _preferences.setString('$key.web', base64Encode(bytes));
      await _preferences.remove('$key.path');
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final avatarDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}profile_images',
    );
    await avatarDirectory.create(recursive: true);
    final file = File(
      '${avatarDirectory.path}${Platform.pathSeparator}$uid.avatar',
    );
    await file.writeAsBytes(bytes, flush: true);
    await _preferences.setString('$key.path', file.path);
    await _preferences.remove('$key.web');
  }

  Future<Uint8List?> loadAvatar(String uid) async {
    final key = _key(uid);
    if (kIsWeb) {
      final encoded = await _preferences.getString('$key.web');
      if (encoded == null) return null;
      try {
        return base64Decode(encoded);
      } catch (_) {
        return null;
      }
    }
    final path = await _preferences.getString('$key.path');
    if (path == null) return null;
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfileUsername(String uid, String username) =>
      _preferences.setString(_usernameKey(uid), username.trim());

  Future<String?> loadProfileUsername(String uid) =>
      _preferences.getString(_usernameKey(uid));

  Future<bool> hasCompletedGoogleSetup(String uid) async =>
      await _preferences.getBool(_setupKey(uid)) ?? false;

  Future<void> markGoogleSetupComplete(String uid) =>
      _preferences.setBool(_setupKey(uid), true);

  String _key(String uid) =>
      'profile_avatar_${uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

  String _usernameKey(String uid) =>
      'profile_username_${uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

  String _setupKey(String uid) =>
      'google_profile_setup_${uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';
}
