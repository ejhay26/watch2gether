import 'package:dio/dio.dart';
import '../models/media_item.dart';
import '../models/room_models.dart';
import '../models/user_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String _baseUrl = 'https://nuclei-oil-modular.ngrok-free.dev';
  String? _authToken;

  String get baseUrl => _baseUrl;
  String? get authToken => _authToken;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
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

  void setAuthToken(String? token) {
    _authToken = token;
  }

  // --- Auth Endpoints ---
  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/api/v1/auth/login', data: {
        'username': username,
        'password': password,
      });
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ?? 'Login failed';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception(e.toString());
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
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ?? 'Registration failed';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserModel?> getMe() async {
    if (_authToken == null) return null;
    try {
      final res = await _dio.get('/api/v1/auth/me');
      final userData = res.data['user'];
      if (userData != null) {
        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- Media & Catalog Endpoints ---
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

  // --- Watch Room Endpoints ---
  Future<String?> createRoom({
    String mediaId = '',
    String title = 'Watch Party',
    String streamUrl = '',
    String episodeId = '',
    Map<String, String>? headers,
  }) async {
    try {
      final res = await _dio.post('/api/v1/rooms', data: {
        'media_id': mediaId,
        'title': title,
        'stream_url': streamUrl,
        'episode_id': episodeId,
        ...?headers != null ? {'headers': headers} : null,
      });
      return res.data['room_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<RoomStateData?> getRoom(String roomId) async {
    try {
      final res = await _dio.get('/api/v1/rooms/$roomId');
      return RoomStateData.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveWatchHistory({
    required String mediaId,
    required String title,
    String poster = '',
    String episodeId = '',
    required int timestampSeconds,
    required int durationSeconds,
  }) async {
    if (_authToken == null) return false;
    try {
      await _dio.post('/api/v1/history', data: {
        'media_id': mediaId,
        'title': title,
        'poster': poster,
        'episode_id': episodeId,
        'timestamp_seconds': timestampSeconds,
        'duration_seconds': durationSeconds,
      });
      return true;
    } catch (e) {
      return false;
    }
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
