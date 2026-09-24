import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/room_models.dart';
import 'api_service.dart';

class RoomService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;
  bool _isReconnecting = false;

  String? _currentRoomId;
  String? _userId;
  String? _username;
  RoomStateData? _state;
  bool _isConnected = false;

  // Playback sync event callbacks
  ValueChanged<RoomStateData>? onRoomStateReceived;
  Function(double position, int executeAtMs)? onPlayReceived;
  Function(double position)? onPauseReceived;
  Function(double position, int executeAtMs)? onSeekReceived;
  Function(String mediaId, String title, String streamUrl)? onMediaChangedReceived;
  Function(String mediaId, String title, String streamUrl, String episodeId, Map<String, String>? headers)? onPartyPlayPrompt;
  String? localActiveMediaId;

  bool get isInParty => _isConnected && _currentRoomId != null;

  String? get currentRoomId => _currentRoomId;
  String? get username => _username;
  RoomStateData? get state => _state;
  bool get isConnected => _isConnected;
  bool get isHost => _state != null && _userId != null && _state!.hostId == _userId;


  Future<String?> startParty({String? username, String? userId, String title = "Watch Party"}) async {
    final uname = username ?? _username ?? "Host";
    final uid = userId ?? _userId ?? "host_${DateTime.now().millisecondsSinceEpoch % 10000}";
    final code = await ApiService().createRoom(title: title);
    if (code != null) {
      await connect(roomId: code, userId: uid, username: uname);
      notifyListeners();
    }
    return code;
  }

  Future<bool> joinParty(String code, {String? username, String? userId}) async {
    final cleanCode = code.toUpperCase().trim();
    if (cleanCode.length != 6) return false;
    final uname = username ?? _username ?? "Viewer";
    final uid = userId ?? _userId ?? "user_${DateTime.now().millisecondsSinceEpoch % 10000}";
    final room = await ApiService().getRoom(cleanCode);
    if (room != null) {
      await connect(roomId: cleanCode, userId: uid, username: uname);
      notifyListeners();
      return true;
    }
    return false;
  }

  void leaveParty() {
    disconnect();
  }

  Future<void> connect({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    _reconnectTimer?.cancel();
    _intentionalDisconnect = false;

    // Disconnect existing without marking as intentional
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;

    _currentRoomId = roomId;
    _userId = userId;
    _username = username;

    final base = ApiService().baseUrl;
    final wsScheme = base.startsWith('https') ? 'wss' : 'ws';
    final host = base.replaceFirst(RegExp(r'^https?:\/\/'), '');
    final uri = Uri.parse('$wsScheme://$host/ws/room/$roomId?userId=$userId&username=${Uri.encodeComponent(username)}');

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      notifyListeners();

      _sub = _channel!.stream.listen(
        (data) {
          _handleIncoming(data.toString());
        },
        onError: (err) {
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isReconnecting || _intentionalDisconnect || _currentRoomId == null) return;
    _isReconnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      _isReconnecting = false;
      if (_currentRoomId != null && !_intentionalDisconnect && !_isConnected) {
        await connect(
          roomId: _currentRoomId!,
          userId: _userId ?? '',
          username: _username ?? 'Viewer',
        );
      }
    });
  }

  void _handleIncoming(String raw) {
    try {
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      final type = jsonMap['type'] as String?;

      switch (type) {
        case 'ROOM_STATE':
          if (jsonMap['room_state'] != null) {
            _state = RoomStateData.fromJson(jsonMap['room_state']);
            notifyListeners();
            onRoomStateReceived?.call(_state!);
          }
          break;

        case 'PLAY':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          final execAt = (jsonMap['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          if (_state != null) {
            _state = _state!.copyWith(
              playbackPosition: pos,
              isPlaying: true,
              lastUpdated: DateTime.now(),
            );
            notifyListeners();
          }
          onPlayReceived?.call(pos, execAt);
          break;

        case 'PAUSE':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          if (_state != null) {
            _state = _state!.copyWith(
              playbackPosition: pos,
              isPlaying: false,
              lastUpdated: DateTime.now(),
            );
            notifyListeners();
          }
          onPauseReceived?.call(pos);
          break;

        case 'SEEK':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          final execAt = (jsonMap['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          if (_state != null) {
            _state = _state!.copyWith(
              playbackPosition: pos,
              lastUpdated: DateTime.now(),
            );
            notifyListeners();
          }
          onSeekReceived?.call(pos, execAt);
          break;

        case 'CHANGE_MEDIA':
          final mediaId = jsonMap['media_id'] ?? '';
          final title = jsonMap['title'] ?? '';
          final streamUrl = jsonMap['stream_url'] ?? '';
          final episodeId = jsonMap['episode_id'] ?? '';
          final rawHeaders = jsonMap['headers'] as Map<String, dynamic>?;
          final headers = rawHeaders?.map((k, v) => MapEntry(k, v.toString()));

          if (_state != null) {
            _state = _state!.copyWith(
              mediaId: mediaId,
              title: title,
              streamUrl: streamUrl,
              episodeId: episodeId,
              headers: headers,
              playbackPosition: 0.0,
              isPlaying: false,
              lastUpdated: DateTime.now(),
            );
            notifyListeners();
          }
          onMediaChangedReceived?.call(mediaId, title, streamUrl);
          // Only prompt user to join if they are NOT already actively watching this media in PlayerScreen
          if (localActiveMediaId != mediaId && onMediaChangedReceived == null) {
            onPartyPlayPrompt?.call(mediaId, title, streamUrl, episodeId, headers);
          }
          break;

        case 'CHAT':
          final user = jsonMap['user'] != null ? Participant.fromJson(jsonMap['user']) : null;
          final msg = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: user?.id ?? '',
            username: user?.username ?? 'Anonymous',
            message: jsonMap['message'] ?? '',
            timestamp: DateTime.now(),
          );
          if (_state != null) {
            final updatedChat = List<ChatMessage>.from(_state!.recentChat)..add(msg);
            _state = _state!.copyWith(recentChat: updatedChat);
            notifyListeners();
          }
          break;

        case 'USER_JOINED':
          if (jsonMap['user'] != null && _state != null) {
            final joined = Participant.fromJson(jsonMap['user']);
            final updatedParts = List<Participant>.from(_state!.participants.where((p) => p.id != joined.id))..add(joined);
            _state = _state!.copyWith(participants: updatedParts);
            notifyListeners();
          }
          break;

        case 'USER_LEFT':
          if (jsonMap['user'] != null && _state != null) {
            final leftId = jsonMap['user']['id'];
            final updatedParts = _state!.participants.where((p) => p.id != leftId).toList();
            _state = _state!.copyWith(participants: updatedParts);
            notifyListeners();
          }
          break;
      }
    } catch (_) {}
  }

  double get currentPosition => _state?.currentPosition ?? 0.0;

  void sendPlay(double position) {
    if (_state != null) {
      _state = _state!.copyWith(
        playbackPosition: position,
        isPlaying: true,
        lastUpdated: DateTime.now(),
      );
    }
    _send({
      'type': 'PLAY',
      'position': position,
    });
  }

  void sendPause(double position) {
    if (_state != null) {
      _state = _state!.copyWith(
        playbackPosition: position,
        isPlaying: false,
        lastUpdated: DateTime.now(),
      );
    }
    _send({
      'type': 'PAUSE',
      'position': position,
    });
  }

  void sendSeek(double position) {
    if (_state != null) {
      _state = _state!.copyWith(
        playbackPosition: position,
        lastUpdated: DateTime.now(),
      );
    }
    _send({
      'type': 'SEEK',
      'position': position,
    });
  }

  void sendChangeMedia(String mediaId, String title, String streamUrl, String episodeId, {Map<String, String>? headers}) {
    _send({
      'type': 'CHANGE_MEDIA',
      'media_id': mediaId,
      'title': title,
      'stream_url': streamUrl,
      'episode_id': episodeId,
      ...?headers != null ? {'headers': headers} : null,
    });
  }

  void sendChat(String message) {
    if (message.trim().isEmpty) return;
    _send({
      'type': 'CHAT',
      'message': message.trim(),
    });
  }

  void requestSync() {
    _send({'type': 'SYNC_REQUEST'});
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _state = null;
    _currentRoomId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
