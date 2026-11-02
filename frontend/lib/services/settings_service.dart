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
  static const String _keySeekDuration = 'settings_seek_duration';
  static const String _keyAutoHideDuration = 'settings_auto_hide_duration';
  static const String _keyAutoPlayNext = 'settings_auto_play_next';
  static const String _keySubFontSize = 'settings_sub_font_size';
  static const String _keySubTextColor = 'settings_sub_text_color';
  static const String _keySubBgOpacity = 'settings_sub_bg_opacity';

  bool _liquidGlass = true;
  bool _autoSyncParty = true;
  bool _hardwareAccel = true;
  bool _subtitlesEnabled = true;
  String _defaultQuality = 'Auto';
  int _seekDurationSeconds = 10;
  double _autoHideControlsSeconds = 3.5;
  bool _autoPlayNextEpisode = true;
  double _subtitleFontSize = 18.0;
  int _subtitleTextColor = 0xFFFFFFFF;
  double _subtitleBackgroundOpacity = 0.5;
  bool _isLoaded = false;

  bool get liquidGlass => _liquidGlass;
  bool get autoSyncParty => _autoSyncParty;
  bool get hardwareAccel => _hardwareAccel;
  bool get subtitlesEnabled => _subtitlesEnabled;
  String get defaultQuality => _defaultQuality;
  int get seekDurationSeconds => _seekDurationSeconds;
  double get autoHideControlsSeconds => _autoHideControlsSeconds;
  bool get autoPlayNextEpisode => _autoPlayNextEpisode;
  double get subtitleFontSize => _subtitleFontSize;
  int get subtitleTextColor => _subtitleTextColor;
  double get subtitleBackgroundOpacity => _subtitleBackgroundOpacity;
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
      _seekDurationSeconds = prefs.getInt(_keySeekDuration) ?? 10;
      _autoHideControlsSeconds = prefs.getDouble(_keyAutoHideDuration) ?? 3.5;
      _autoPlayNextEpisode = prefs.getBool(_keyAutoPlayNext) ?? true;
      _subtitleFontSize = prefs.getDouble(_keySubFontSize) ?? 18.0;
      _subtitleTextColor = prefs.getInt(_keySubTextColor) ?? 0xFFFFFFFF;
      _subtitleBackgroundOpacity = prefs.getDouble(_keySubBgOpacity) ?? 0.5;
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
        _seekDurationSeconds = remote.seekDurationSeconds;
        _autoHideControlsSeconds = remote.autoHideControlsSeconds;
        _autoPlayNextEpisode = remote.autoPlayNextEpisode;
        _subtitleFontSize = remote.subtitleFontSize;
        _subtitleTextColor = remote.subtitleTextColor;
        _subtitleBackgroundOpacity = remote.subtitleBackgroundOpacity;

        // Cache locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyLiquidGlass, _liquidGlass);
        await prefs.setBool(_keyAutoSyncParty, _autoSyncParty);
        await prefs.setBool(_keyHardwareAccel, _hardwareAccel);
        await prefs.setBool(_keySubtitlesEnabled, _subtitlesEnabled);
        await prefs.setString(_keyDefaultQuality, _defaultQuality);
        await prefs.setInt(_keySeekDuration, _seekDurationSeconds);
        await prefs.setDouble(_keyAutoHideDuration, _autoHideControlsSeconds);
        await prefs.setBool(_keyAutoPlayNext, _autoPlayNextEpisode);
        await prefs.setDouble(_keySubFontSize, _subtitleFontSize);
        await prefs.setInt(_keySubTextColor, _subtitleTextColor);
        await prefs.setDouble(_keySubBgOpacity, _subtitleBackgroundOpacity);

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

  Future<void> setSeekDurationSeconds(int value) async {
    if (_seekDurationSeconds == value) return;
    _seekDurationSeconds = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySeekDuration, value);
    } catch (_) {}
    _pushToRemote();
  }

  Future<void> setAutoHideControlsSeconds(double value) async {
    if (_autoHideControlsSeconds == value) return;
    _autoHideControlsSeconds = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyAutoHideDuration, value);
    } catch (_) {}
    _pushToRemote();
  }

  Future<void> setAutoPlayNextEpisode(bool value) async {
    if (_autoPlayNextEpisode == value) return;
    _autoPlayNextEpisode = value;
    notifyListeners();
    _persistLocally(_keyAutoPlayNext, value);
    _pushToRemote();
  }

  Future<void> setSubtitleFontSize(double value) async {
    if (_subtitleFontSize == value) return;
    _subtitleFontSize = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keySubFontSize, value);
    } catch (_) {}
    _pushToRemote();
  }

  Future<void> setSubtitleTextColor(int value) async {
    if (_subtitleTextColor == value) return;
    _subtitleTextColor = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySubTextColor, value);
    } catch (_) {}
    _pushToRemote();
  }

  Future<void> setSubtitleBackgroundOpacity(double value) async {
    if (_subtitleBackgroundOpacity == value) return;
    _subtitleBackgroundOpacity = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keySubBgOpacity, value);
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
      seekDurationSeconds: _seekDurationSeconds,
      autoHideControlsSeconds: _autoHideControlsSeconds,
      autoPlayNextEpisode: _autoPlayNextEpisode,
      subtitleFontSize: _subtitleFontSize,
      subtitleTextColor: _subtitleTextColor,
      subtitleBackgroundOpacity: _subtitleBackgroundOpacity,
    );
    ApiService().saveUserSettings(model);
  }
}
