import 'package:dio/dio.dart';
import '../models/media_item.dart';
import '../models/room_models.dart';

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

  Future<List<MediaItem>> getTrending() async {
    try {
      final res = await _dio.get('/api/v1/trending');
      final items = (res.data['items'] as List<dynamic>?) ?? [];
      return items.map((e) => MediaItem.fromJson(e)).toList();
    } catch (e) {
      return [];
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

  Future<List<Server>> getServers(String episodeId) async {
    try {
      final res = await _dio.get('/api/v1/servers', queryParameters: {'episodeId': episodeId});
      final srvs = (res.data['servers'] as List<dynamic>?) ?? [];
      return srvs.map((e) => Server.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<StreamResult?> getSources(String serverId) async {
    try {
      final res = await _dio.get('/api/v1/sources', queryParameters: {'serverId': serverId});
      return StreamResult.fromJson(res.data);
    } catch (e) {
      return null;
    }
  }

  Future<String?> createRoom({
    required String mediaId,
    required String title,
    required String streamUrl,
    String episodeId = '',
  }) async {
    try {
      final res = await _dio.post('/api/v1/rooms', data: {
        'media_id': mediaId,
        'title': title,
        'stream_url': streamUrl,
        'episode_id': episodeId,
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
}
