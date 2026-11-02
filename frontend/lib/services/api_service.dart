import 'dart:io' show Platform, Socket;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/history_model.dart';
import '../models/settings_model.dart';
import '../models/media_item.dart';
import '../models/room_models.dart';
import '../models/user_model.dart';
import 'local_store_service.dart';
import 'p2p_mesh_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String _baseUrl = 'http://127.0.0.1:8080';
  String? _authToken;

  String get baseUrl => _baseUrl;
  String? get authToken => _authToken;

  ApiService._internal() {
    _baseUrl = 'http://127.0.0.1:8080';

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['ngrok-skip-browser-warning'] = 'true';
          if (_authToken != null && _authToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
      ),
    );
  }

  void updateBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _dio.options.baseUrl = _baseUrl;
  }

  /// Automatically tests whether the embedded localhost companion server is active,
  /// falling back to Android emulator host loopback if needed.
  Future<void> autoDetectBaseUrl() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final socket = await Socket.connect('127.0.0.1', 8080, timeout: const Duration(milliseconds: 250));
        socket.destroy();
        updateBaseUrl('http://127.0.0.1:8080');
        return;
      } catch (_) {}

      try {
        final socket = await Socket.connect('10.0.2.2', 8080, timeout: const Duration(milliseconds: 250));
        socket.destroy();
        updateBaseUrl('http://10.0.2.2:8080');
        return;
      } catch (_) {}
    }
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  // --- Auth Endpoints (Local Peer Sovereignty) ---
  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    // If local companion Go backend is running, attempt login; otherwise generate local peer token
    try {
      final res = await _dio.post('/api/v1/auth/login', data: {
        'username': username,
        'password': password,
      });
      return res.data as Map<String, dynamic>?;
    } catch (_) {
      // Local fallback
      final peerId = LocalStoreService().peerId;
      await LocalStoreService().updateUsername(username);
      return {
        'token': 'peer_token_$peerId',
        'user': {
          'id': peerId,
          'username': username,
          'email': '$username@local.mesh',
          'role': 'peer',
        }
      };
    }
  }

  Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/api/v1/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
      });
      return res.data as Map<String, dynamic>?;
    } catch (_) {
      final peerId = LocalStoreService().peerId;
      await LocalStoreService().updateUsername(username);
      return {
        'token': 'peer_token_$peerId',
        'user': {
          'id': peerId,
          'username': username,
          'email': email,
          'role': 'peer',
        }
      };
    }
  }

  Future<UserModel?> getMe() async {
    final peerId = LocalStoreService().peerId;
    final username = LocalStoreService().username;
    return UserModel(
      id: peerId,
      username: username,
      email: '$username@local.mesh',
      role: 'peer',
      createdAt: DateTime.now(),
    );
  }

  // --- Media Catalog Endpoints (Scraper API) ---
  Future<List<MediaItem>> getTrending() async {
    try {
      final res = await _dio.get('/api/v1/trending');
      final items = (res.data['items'] as List<dynamic>?) ?? [];
      return items.map((e) => MediaItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<MediaItem>> getRecommendations(String id) async {
    try {
      final res = await _dio.get('/api/v1/recommendations', queryParameters: {'id': id});
      final items = (res.data['items'] as List<dynamic>?) ?? [];
      final list = items.map((e) => MediaItem.fromJson(e)).toList();
      if (list.isNotEmpty) return list;
      return getTrending();
    } catch (e) {
      return getTrending();
    }
  }

  Future<List<MediaItem>> search(String query) async {
    try {
      final res = await _dio.get('/api/v1/search', queryParameters: {'q': query});
      final items = (res.data['items'] as List<dynamic>?) ?? [];
      return items.map((e) => MediaItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<MediaItem?> getDetails(String id) async {
    try {
      final res = await _dio.get('/api/v1/details', queryParameters: {'id': id});
      return MediaItem.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }

  Future<List<Episode>> getEpisodes(String id, {int season = 1}) async {
    try {
      final res = await _dio.get('/api/v1/episodes', queryParameters: {
        'id': id,
        'season': season.toString(),
      });
      final eps = (res.data['episodes'] as List<dynamic>?) ?? [];
      return eps.map((e) => Episode.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Server>> getServers(String episodeId, {String? title}) async {
    try {
      final queryParams = <String, dynamic>{'episodeId': episodeId};
      if (title != null && title.isNotEmpty) {
        queryParams['title'] = title;
      }
      final res = await _dio.get('/api/v1/servers', queryParameters: queryParams);
      final srvs = (res.data['servers'] as List<dynamic>?) ?? [];
      return srvs.map((e) => Server.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<StreamResult?> getSources(String serverId, {String? title}) async {
    try {
      final queryParams = <String, dynamic>{'serverId': serverId};
      if (title != null && title.isNotEmpty) {
        queryParams['title'] = title;
      }
      final res = await _dio.get('/api/v1/sources', queryParameters: queryParams);
      return StreamResult.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }

  Future<List<SubtitleTrack>> searchSubtitles(String query, {String? imdbId, String? lang}) async {
    try {
      final queryParams = <String, dynamic>{'q': query};
      if (imdbId != null && imdbId.isNotEmpty) queryParams['imdb'] = imdbId;
      if (lang != null && lang.isNotEmpty) queryParams['lang'] = lang;
      final res = await _dio.get('/api/v1/subtitles/search', queryParameters: queryParams);
      final subs = (res.data['subtitles'] as List<dynamic>?) ?? [];
      return subs.map((e) => SubtitleTrack.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Watch Room Endpoints (Decentralized Mesh + Local Host) ---
  Future<String?> createRoom({
    String mediaId = '',
    String title = 'Watch Party',
    String streamUrl = '',
    String episodeId = '',
    Map<String, String>? headers,
  }) async {
    final code = await P2PMeshService().hostDirectParty(
      hostUserId: LocalStoreService().peerId,
      hostUsername: LocalStoreService().username,
      title: title,
    );
    return code;
  }

  Future<RoomStateData?> getRoom(String roomId) async {
    if (P2PMeshService().state != null && P2PMeshService().activeRoomCode == roomId) {
      return P2PMeshService().state;
    }
    try {
      final res = await _dio.get('/api/v1/rooms/$roomId');
      return RoomStateData.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }

  // --- Watch History Endpoints (100% Local-First) ---
  Future<List<WatchHistoryItem>> getWatchHistory() async {
    return await LocalStoreService().getWatchHistory();
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
    return await LocalStoreService().saveWatchHistory(
      mediaId: mediaId,
      title: title,
      poster: poster,
      episodeId: episodeId,
      timestampSeconds: timestampSeconds,
      durationSeconds: durationSeconds,
      isWatched: isWatched,
    );
  }

  Future<bool> deleteWatchHistory({
    required String mediaId,
    String? episodeId,
  }) async {
    return await LocalStoreService().deleteWatchHistory(
      mediaId: mediaId,
      episodeId: episodeId ?? '',
    );
  }

  Future<bool> clearAllWatchHistory() async {
    await LocalStoreService().clearWatchHistory();
    return true;
  }

  // --- Settings Endpoints (Local-First) ---
  Future<UserSettingsModel?> getUserSettings() async {
    // User settings are maintained locally in SettingsService & SharedPreferences
    return null;
  }

  Future<bool> saveUserSettings(UserSettingsModel settings) async {
    return true;
  }

  // --- App Version & In-App Update ---
  Future<Map<String, dynamic>?> checkAppVersion() async {
    try {
      final res = await _dio.get('/api/v1/app/version');
      return res.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
