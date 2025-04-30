import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/credentials.dart';

class CredentialsManager {
  static const String _credentialsKey = 'credentials';

  static Future<void> saveCredentials(Credentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    final credentialsJson = jsonEncode(credentials.toJson());
    await prefs.setString(_credentialsKey, credentialsJson);
  }

  static Future<Credentials?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final credentialsJson = prefs.getString(_credentialsKey);
    if (credentialsJson != null) {
      return Credentials.fromJson(jsonDecode(credentialsJson));
    }
    return null;
  }

  static Future<void> removeCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_credentialsKey);
  }
}