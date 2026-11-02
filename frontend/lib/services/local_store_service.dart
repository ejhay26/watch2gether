import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_model.dart';
import '../models/media_item.dart';

class PersistentPeer {
  final String id;
  final String name;
  final String deviceType;
  final DateTime lastSeen;

  PersistentPeer({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.lastSeen,
  });

  factory PersistentPeer.fromJson(Map<String, dynamic> json) {
    return PersistentPeer(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Peer',
      deviceType: json['device_type'] ?? 'Device',
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'device_type': deviceType,
        'last_seen': lastSeen.toIso8601String(),
      };
}

class PersistentGroup {
  final String groupId;
  final String groupName;
  final String secretKey;
  final List<PersistentPeer> peers;
  final DateTime createdAt;

  PersistentGroup({
    required this.groupId,
    required this.groupName,
    required this.secretKey,
    required this.peers,
    required this.createdAt,
  });

  factory PersistentGroup.fromJson(Map<String, dynamic> json) {
    final rawPeers = (json['peers'] as List<dynamic>?) ?? [];
    return PersistentGroup(
      groupId: json['group_id'] ?? '',
      groupName: json['group_name'] ?? 'Watch Circle',
      secretKey: json['secret_key'] ?? '',
      peers: rawPeers.map((p) => PersistentPeer.fromJson(p as Map<String, dynamic>)).toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'group_name': groupName,
        'secret_key': secretKey,
        'peers': peers.map((p) => p.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

class LocalStoreService extends ChangeNotifier {
  static final LocalStoreService _instance = LocalStoreService._internal();
  factory LocalStoreService() => _instance;
  LocalStoreService._internal();

  static const String _keyPeerId = 'wt_peer_id';
  static const String _keyUsername = 'wt_username';
  static const String _keyHasCustomUsername = 'wt_has_custom_username';
  static const String _keyAvatar = 'wt_avatar_seed';
  static const String _keyHistory = 'wt_local_history_v2';
  static const String _keyFavorites = 'wt_local_favorites_v2';
  static const String _keyGroups = 'wt_persistent_groups_v2';
  static const String _keyBackendUrl = 'wt_companion_backend_url';
  static const String _keyDirectMeshPort = 'wt_mesh_direct_port';

  String _peerId = '';
  String _username = '';
  bool _hasCustomUsername = false;
  int _avatarIndex = 0;
  String _companionBackendUrl = '';
  int _meshDirectPort = 8888;

  List<WatchHistoryItem> _history = [];
  List<MediaItem> _favorites = [];
  List<PersistentGroup> _groups = [];
  bool _isInitialized = false;

  String get peerId => _peerId;
  String get username => _username;
  bool get hasCustomUsername => _hasCustomUsername;
  int get avatarIndex => _avatarIndex;
  String get companionBackendUrl => _companionBackendUrl;
  int get meshDirectPort => _meshDirectPort;
  List<WatchHistoryItem> get history => List.unmodifiable(_history);
  List<MediaItem> get favorites => List.unmodifiable(_favorites);
  List<PersistentGroup> get groups => List.unmodifiable(_groups);
  bool get isInitialized => _isInitialized;

  String get deviceType {
    if (kIsWeb) return 'Web Browser';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isAndroid) return 'Android Mobile';
    if (Platform.isMacOS) return 'macOS Desktop';
    if (Platform.isLinux) return 'Linux Desktop';
    if (Platform.isIOS) return 'iOS Mobile';
    return 'Client Device';
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Peer Identity (Cryptographic / Decentralized Local ID)
      String? savedPeerId = prefs.getString(_keyPeerId);
      if (savedPeerId == null || savedPeerId.isEmpty) {
        final randHex = _generateRandomCode(6);
        savedPeerId = 'P2P-$randHex';
        await prefs.setString(_keyPeerId, savedPeerId);
      }
      _peerId = savedPeerId;

      String? savedUsername = prefs.getString(_keyUsername);
      if (savedUsername == null || savedUsername.isEmpty) {
        final defaultName = kIsWeb
            ? 'WebGuest_${_peerId.substring(_peerId.length - 4)}'
            : (Platform.isAndroid
                ? 'Mobile_${_peerId.substring(_peerId.length - 4)}'
                : 'Host_${_peerId.substring(_peerId.length - 4)}');
        savedUsername = defaultName;
        await prefs.setString(_keyUsername, savedUsername);
      }
      _username = savedUsername;
      final hasCustom = prefs.getBool(_keyHasCustomUsername);
      if (hasCustom != null) {
        _hasCustomUsername = hasCustom;
      } else {
        _hasCustomUsername = savedUsername != null &&
            savedUsername.isNotEmpty &&
            !savedUsername.startsWith('Host_') &&
            !savedUsername.startsWith('Mobile_') &&
            !savedUsername.startsWith('WebGuest_');
      }
      _avatarIndex = prefs.getInt(_keyAvatar) ?? (_peerId.hashCode.abs() % 6);

      // 2. Default Companion Backend URL
      final savedUrl = prefs.getString(_keyBackendUrl);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _companionBackendUrl = savedUrl;
      } else {
        // Defaults: Localhost on Desktop, loopback/lan on Android
        if (!kIsWeb && Platform.isWindows) {
          _companionBackendUrl = 'http://127.0.0.1:8080';
        } else {
          _companionBackendUrl = 'http://10.0.2.2:8080';
        }
      }
      _meshDirectPort = prefs.getInt(_keyDirectMeshPort) ?? 8888;

      // 3. Load Local Watch History
      final rawHist = prefs.getString(_keyHistory);
      if (rawHist != null && rawHist.isNotEmpty) {
        try {
          final list = jsonDecode(rawHist) as List<dynamic>;
          _history = list.map((e) => WatchHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
          _history.sort((a, b) {
            final ta = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final tb = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return tb.compareTo(ta);
          });
        } catch (_) {
          _history = [];
        }
      }

      // 4. Load Local Favorites
      final rawFavs = prefs.getString(_keyFavorites);
      if (rawFavs != null && rawFavs.isNotEmpty) {
        try {
          final list = jsonDecode(rawFavs) as List<dynamic>;
          _favorites = list.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {
          _favorites = [];
        }
      }

      // 5. Load Persistent Groups
      final rawGroups = prefs.getString(_keyGroups);
      if (rawGroups != null && rawGroups.isNotEmpty) {
        try {
          final list = jsonDecode(rawGroups) as List<dynamic>;
          _groups = list.map((e) => PersistentGroup.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {
          _groups = [];
        }
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // --- Identity Management ---
  Future<void> updateUsername(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    _username = clean;
    _hasCustomUsername = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, clean);
    await prefs.setBool(_keyHasCustomUsername, true);
    notifyListeners();
  }

  Future<void> updateAvatarIndex(int idx) async {
    _avatarIndex = idx;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAvatar, idx);
    notifyListeners();
  }

  Future<void> updateCompanionBackendUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty || clean == _companionBackendUrl) return;
    _companionBackendUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackendUrl, clean);
    notifyListeners();
  }

  // --- Watch History Management (Local-First) ---
  Future<List<WatchHistoryItem>> getWatchHistory() async {
    if (!_isInitialized) await init();
    return List.unmodifiable(_history);
  }

  Future<bool> saveWatchHistory({
    required String mediaId,
    required String title,
    String poster = '',
    String episodeId = '',
    required int timestampSeconds,
    required int durationSeconds,
    bool? isWatched,
  }) async {
    if (!_isInitialized) await init();
    final now = DateTime.now();
    final watched = isWatched ?? (durationSeconds > 0 && timestampSeconds >= (durationSeconds * 0.90));

    final existingIndex = _history.indexWhere(
      (it) => it.mediaId == mediaId && (it.episodeId ?? '') == episodeId,
    );

    final item = WatchHistoryItem(
      id: existingIndex >= 0 ? _history[existingIndex].id : 'hist_${now.millisecondsSinceEpoch}',
      userId: _peerId,
      mediaId: mediaId,
      title: title,
      poster: poster,
      episodeId: episodeId.isNotEmpty ? episodeId : null,
      timestampSeconds: timestampSeconds,
      durationSeconds: durationSeconds,
      isWatched: watched,
      updatedAt: now,
    );

    if (existingIndex >= 0) {
      _history[existingIndex] = item;
    } else {
      _history.insert(0, item);
    }

    // Sort descending by updated timestamp
    _history.sort((a, b) => (b.updatedAt ?? now).compareTo(a.updatedAt ?? now));

    // Cap to 500 recent items
    if (_history.length > 500) {
      _history = _history.sublist(0, 500);
    }

    await _persistHistory();
    notifyListeners();
    return true;
  }

  Future<bool> deleteWatchHistory({required String mediaId, String episodeId = ''}) async {
    if (!_isInitialized) await init();
    final initialLen = _history.length;
    _history.removeWhere(
      (it) => it.mediaId == mediaId && (episodeId.isEmpty || (it.episodeId ?? '') == episodeId),
    );
    if (_history.length != initialLen) {
      await _persistHistory();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> clearWatchHistory() async {
    _history.clear();
    await _persistHistory();
    notifyListeners();
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _history.map((it) => it.toJson()).toList();
      await prefs.setString(_keyHistory, jsonEncode(jsonList));
    } catch (_) {}
  }

  // --- Favorites Management (Local-First) ---
  Future<List<MediaItem>> getFavorites() async {
    if (!_isInitialized) await init();
    return List.unmodifiable(_favorites);
  }

  bool isFavorite(String mediaId) {
    return _favorites.any((it) => it.id == mediaId);
  }

  Future<bool> toggleFavorite(MediaItem item) async {
    if (!_isInitialized) await init();
    final idx = _favorites.indexWhere((it) => it.id == item.id);
    if (idx >= 0) {
      _favorites.removeAt(idx);
    } else {
      _favorites.insert(0, item);
    }
    await _persistFavorites();
    notifyListeners();
    return idx < 0; // True if newly added, False if removed
  }

  Future<void> _persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _favorites.map((it) => it.toJson()).toList();
      await prefs.setString(_keyFavorites, jsonEncode(jsonList));
    } catch (_) {}
  }

  // --- Persistent Groups (Circles) ---
  Future<PersistentGroup> createPersistentGroup(String name) async {
    if (!_isInitialized) await init();
    final code = 'GRP-${_generateRandomCode(6)}';
    final secret = _generateRandomCode(12);
    final group = PersistentGroup(
      groupId: code,
      groupName: name.trim().isNotEmpty ? name.trim() : 'Watch Group',
      secretKey: secret,
      peers: [
        PersistentPeer(
          id: _peerId,
          name: _username,
          deviceType: deviceType,
          lastSeen: DateTime.now(),
        )
      ],
      createdAt: DateTime.now(),
    );

    _groups.insert(0, group);
    await _persistGroups();
    notifyListeners();
    return group;
  }

  Future<PersistentGroup?> joinPersistentGroup(String groupId, {String? name}) async {
    if (!_isInitialized) await init();
    final cleanCode = groupId.trim().toUpperCase();
    final existingIdx = _groups.indexWhere((g) => g.groupId == cleanCode);
    if (existingIdx >= 0) return _groups[existingIdx];

    final group = PersistentGroup(
      groupId: cleanCode,
      groupName: name ?? 'Circle $cleanCode',
      secretKey: '',
      peers: [
        PersistentPeer(
          id: _peerId,
          name: _username,
          deviceType: deviceType,
          lastSeen: DateTime.now(),
        )
      ],
      createdAt: DateTime.now(),
    );

    _groups.insert(0, group);
    await _persistGroups();
    notifyListeners();
    return group;
  }

  Future<void> removePersistentGroup(String groupId) async {
    _groups.removeWhere((g) => g.groupId == groupId);
    await _persistGroups();
    notifyListeners();
  }

  Future<void> _persistGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _groups.map((g) => g.toJson()).toList();
      await prefs.setString(_keyGroups, jsonEncode(jsonList));
    } catch (_) {}
  }

  static String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
