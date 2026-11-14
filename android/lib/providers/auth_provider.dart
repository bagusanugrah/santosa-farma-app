import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store_setting.dart' show UserModel;
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('santosa_pos_user');
    if (jsonStr != null) {
      try {
        _currentUser = UserModel.fromMap(jsonDecode(jsonStr));
      } catch (e) {
        // Session decode fallback
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final user = await SupabaseService.instance.loginStaff(username, password);
    if (user != null) {
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('santosa_pos_user', jsonEncode(user.toMap()));
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('santosa_pos_user');
    notifyListeners();
  }
}
