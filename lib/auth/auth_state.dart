import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_role.dart';

/// Dev-only auth state.
/// Stores the selected role in shared_preferences (=> localStorage on web).
class AuthState extends ChangeNotifier {
  static const _roleKey = 'dev_role';
  static const _nameKey = 'dev_name';

  bool _ready = false;
  AppRole? _role;
  String? _displayName;

  bool get ready => _ready;
  bool get isLoggedIn => _role != null;
  AppRole? get role => _role;
  String get displayName => _displayName ?? 'Utilisateur';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _role = AppRoleX.fromString(prefs.getString(_roleKey));
    _displayName = prefs.getString(_nameKey);
    _ready = true;
    notifyListeners();
  }

  Future<void> devLogin({
    required AppRole role,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
    if (displayName != null && displayName.trim().isNotEmpty) {
      await prefs.setString(_nameKey, displayName.trim());
      _displayName = displayName.trim();
    }
    _role = role;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_nameKey);
    _role = null;
    _displayName = null;
    notifyListeners();
  }
}
