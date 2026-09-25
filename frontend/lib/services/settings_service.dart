import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';
import 'api_service.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyLiquidGlass = 'settings_liquid_glass';
  static const String _keyAutoSyncParty = 'settings_auto_sync_party';
  static const String _keyHardwareAccel = 'settings_hardware_accel';
  static const String _keySubtitlesEnabled = 'settings_subtitles_enabled';
  static const String _keyDefaultQuality = 'settings_default_quality';

  bool _liquidGlass = true;
  bool _autoSyncParty = true;
  bool _hardwareAccel = true;
  bool _subtitlesEnabled = true;
  String _defaultQuality = 'Auto';
  bool _isLoaded = false;

  bool get liquidGlass => _liquidGlass;
  bool get autoSyncParty => _autoSyncParty;
  bool get hardwareAccel => _hardwareAccel;
  bool get subtitlesEnabled => _subtitlesEnabled;
  String get defaultQuality => _defaultQuality;
  bool get isLoaded => _isLoaded;

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _liquidGlass = prefs.getBool(_keyLiquidGlass) ?? true;
      _autoSyncParty = prefs.getBool(_keyAutoSyncParty) ?? true;
      _hardwareAccel = prefs.getBool(_keyHardwareAccel) ?? true;
      _subtitlesEnabled = prefs.getBool(_keySubtitlesEnabled) ?? true;
      _defaultQuality = prefs.getString(_keyDefaultQuality) ?? 'Auto';
      _isLoaded = true;
      notifyListeners();

      // If user is authenticated, sync with database
      await syncWithRemote();
    } catch (e) {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> syncWithRemote() async {
    try {
      final remote = await ApiService().getUserSettings();
      if (remote != null) {
        _liquidGlass = remote.liquidGlass;
        _autoSyncParty = remote.autoSyncParty;
        _hardwareAccel = remote.hardwareAccel;
        _subtitlesEnabled = remote.subtitlesEnabled;
        _defaultQuality = remote.defaultQuality;

        // Cache locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyLiquidGlass, _liquidGlass);
        await prefs.setBool(_keyAutoSyncParty, _autoSyncParty);
        await prefs.setBool(_keyHardwareAccel, _hardwareAccel);
        await prefs.setBool(_keySubtitlesEnabled, _subtitlesEnabled);
        await prefs.setString(_keyDefaultQuality, _defaultQuality);

        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLiquidGlass(bool value) async {
    if (_liquidGlass == value) return;
    _liquidGlass = value;
    notifyListeners();
    _persistLocally(_keyLiquidGlass, value);
    _pushToRemote();
  }

  Future<void> setAutoSyncParty(bool value) async {
    if (_autoSyncParty == value) return;
    _autoSyncParty = value;
    notifyListeners();
    _persistLocally(_keyAutoSyncParty, value);
    _pushToRemote();
  }

  Future<void> setHardwareAccel(bool value) async {
    if (_hardwareAccel == value) return;
    _hardwareAccel = value;
    notifyListeners();
    _persistLocally(_keyHardwareAccel, value);
    _pushToRemote();
  }

  Future<void> setSubtitlesEnabled(bool value) async {
    if (_subtitlesEnabled == value) return;
    _subtitlesEnabled = value;
    notifyListeners();
    _persistLocally(_keySubtitlesEnabled, value);
    _pushToRemote();
  }

  Future<void> setDefaultQuality(String value) async {
    if (_defaultQuality == value) return;
    _defaultQuality = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDefaultQuality, value);
    } catch (_) {}
    _pushToRemote();
  }

  Future<void> _persistLocally(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
  }

  void _pushToRemote() {
    final model = UserSettingsModel(
      liquidGlass: _liquidGlass,
      autoSyncParty: _autoSyncParty,
      hardwareAccel: _hardwareAccel,
      subtitlesEnabled: _subtitlesEnabled,
      defaultQuality: _defaultQuality,
    );
    ApiService().saveUserSettings(model);
  }
}
