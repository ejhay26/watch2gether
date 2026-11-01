import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'local_store_service.dart';

class AuthService extends ChangeNotifier {
  final LocalStoreService _localStore = LocalStoreService();
  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  String? get username => _localStore.username;
  String? get userId => _localStore.peerId;
  String? get email => '${_localStore.username.toLowerCase()}@mesh.p2p';
  String? get role => _localStore.deviceType;
  String? get token => 'p2p_token_${_localStore.peerId}';
  bool get isAuthenticated => true; // Self-sovereign local peer identity is always active
  bool get isLoading => _isLoading;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    await _localStore.init();
    _refreshUserModel();

    _isLoading = false;
    notifyListeners();
  }

  void _refreshUserModel() {
    _currentUser = UserModel(
      id: _localStore.peerId,
      username: _localStore.username,
      email: '${_localStore.username.toLowerCase()}@mesh.p2p',
      role: _localStore.deviceType,
      createdAt: DateTime.now(),
    );
    ApiService().setAuthToken(token);
  }

  Future<void> updateUsername(String newName) async {
    await _localStore.updateUsername(newName);
    _refreshUserModel();
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    await updateUsername(username);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    await updateUsername(username);
  }

  Future<void> logout() async {
    // Generate new peer identity if user explicitly resets
    _refreshUserModel();
    notifyListeners();
  }
}
