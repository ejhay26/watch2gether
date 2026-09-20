import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  String? _username;
  String? _userId;
  String? _token;

  String? get username => _username;
  String? get userId => _userId;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  AuthService() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('wt_username') ?? 'Guest_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _userId = prefs.getString('wt_user_id') ?? 'u_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _token = prefs.getString('wt_token');

    ApiService().setAuthToken(_token);
    notifyListeners();
  }

  Future<void> setGuestUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    _username = username;
    _userId = 'u_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    await prefs.setString('wt_username', _username!);
    await prefs.setString('wt_user_id', _userId!);
    notifyListeners();
  }

  Future<void> setAuthenticatedUser({
    required String username,
    required String userId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _username = username;
    _userId = userId;
    _token = token;

    await prefs.setString('wt_username', username);
    await prefs.setString('wt_user_id', userId);
    await prefs.setString('wt_token', token);

    ApiService().setAuthToken(token);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wt_token');
    _token = null;
    ApiService().setAuthToken(null);
    notifyListeners();
  }
}
