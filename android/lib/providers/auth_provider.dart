import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store_setting.dart' show UserModel;
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _legacySessionKey = 'santosa_pos_user';
  static const String _sessionKey = 'santosa_pos_session_v2';

  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Bersihkan key sesi lama agar instalasi ulang / update tidak langsung masuk dashboard
      if (prefs.containsKey(_legacySessionKey)) {
        await prefs.remove(_legacySessionKey);
      }

      final jsonStr = prefs.getString(_sessionKey);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          final cachedUser = UserModel.fromMap(decoded);
          final validRole = cachedUser.role == 'super_admin' ||
              cachedUser.role == 'admin' ||
              cachedUser.role == 'admin_kasir';

          if (cachedUser.id > 0 && cachedUser.username.trim().isNotEmpty && validRole) {
            final verifiedUser = await SupabaseService.instance.verifyStaffSession(
              userId: cachedUser.id,
              username: cachedUser.username,
            );
            if (verifiedUser != null) {
              _currentUser = verifiedUser;
              await prefs.setString(_sessionKey, jsonEncode(verifiedUser.toMap()));
            } else {
              await prefs.remove(_sessionKey);
            }
          } else {
            await prefs.remove(_sessionKey);
          }
        } else {
          await prefs.remove(_sessionKey);
        }
      }
    } catch (_) {
      // Fail-closed: jika gagal verifikasi sesi (mis. korup atau offline), wajib login ulang
      _currentUser = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final user = await SupabaseService.instance.loginStaff(username, password);
    if (user != null && user.id > 0 && user.username.trim().isNotEmpty) {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacySessionKey);
      await prefs.setString(_sessionKey, jsonEncode(user.toMap()));
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacySessionKey);
    await prefs.remove(_sessionKey);
    notifyListeners();
  }
}
