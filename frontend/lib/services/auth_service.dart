import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  String? _token;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  String? get username => _currentUser?.username ?? _guestName;
  String? get userId => _currentUser?.id ?? _guestId;
  String? get email => _currentUser?.email;
  String? get role => _currentUser?.role ?? 'guest';
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;

  String? _guestName;
  String? _guestId;

  AuthService() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('wt_token');
      final savedId = prefs.getString('wt_user_id');
      final savedUsername = prefs.getString('wt_username');
      final savedEmail = prefs.getString('wt_email');
      final savedRole = prefs.getString('wt_role');

      if (_token != null && _token!.isNotEmpty && savedId != null) {
        _currentUser = UserModel(
          id: savedId,
          username: savedUsername ?? 'Member',
          email: savedEmail ?? '',
          role: savedRole ?? 'member',
          createdAt: DateTime.now(),
        );
        ApiService().setAuthToken(_token);

        // Fetch fresh profile in background
        ApiService().getMe().then((me) {
          if (me != null) {
            _currentUser = me;
            notifyListeners();
          }
        }).catchError((_) {});
      } else {
        _guestName = prefs.getString('wt_guest_name') ?? 'Guest_${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
        _guestId = prefs.getString('wt_guest_id') ?? 'g_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        await prefs.setString('wt_guest_name', _guestName!);
        await prefs.setString('wt_guest_id', _guestId!);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final res = await ApiService().login(
      username: username,
      password: password,
    );

    if (res != null && res['token'] != null) {
      final token = res['token'] as String;
      final userData = res['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wt_token', token);
      await prefs.setString('wt_user_id', user.id);
      await prefs.setString('wt_username', user.username);
      await prefs.setString('wt_email', user.email);
      await prefs.setString('wt_role', user.role);

      _token = token;
      _currentUser = user;
      ApiService().setAuthToken(token);
      notifyListeners();
    } else {
      throw Exception('Invalid login response from server');
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await ApiService().register(
      username: username,
      email: email,
      password: password,
    );

    if (res != null && res['token'] != null) {
      final token = res['token'] as String;
      final userData = res['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wt_token', token);
      await prefs.setString('wt_user_id', user.id);
      await prefs.setString('wt_username', user.username);
      await prefs.setString('wt_email', user.email);
      await prefs.setString('wt_role', user.role);

      _token = token;
      _currentUser = user;
      ApiService().setAuthToken(token);
      notifyListeners();
    } else {
      throw Exception('Invalid registration response from server');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wt_token');
    await prefs.remove('wt_user_id');
    await prefs.remove('wt_username');
    await prefs.remove('wt_email');
    await prefs.remove('wt_role');

    _token = null;
    _currentUser = null;
    ApiService().setAuthToken(null);
    notifyListeners();
  }
}
