import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/room_models.dart';
import 'api_service.dart';

class RoomService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  String? _currentRoomId;
  String? _userId;
  String? _username;
  RoomStateData? _state;
  bool _isConnected = false;

  // Playback sync event callbacks
  Function(double position, int executeAtMs)? onPlayReceived;
  Function(double position)? onPauseReceived;
  Function(double position, int executeAtMs)? onSeekReceived;
  Function(String mediaId, String title, String streamUrl)? onMediaChangedReceived;

  String? get currentRoomId => _currentRoomId;
  String? get username => _username;
  RoomStateData? get state => _state;
  bool get isConnected => _isConnected;
  bool get isHost => _state != null && _userId != null && _state!.hostId == _userId;

  Future<void> connect({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    disconnect();

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
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnected = false;
      notifyListeners();
    }
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
          }
          break;

        case 'PLAY':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          final execAt = (jsonMap['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          if (_state != null) {
            _state = RoomStateData(
              roomId: _state!.roomId,
              hostId: _state!.hostId,
              mediaId: _state!.mediaId,
              title: _state!.title,
              streamUrl: _state!.streamUrl,
              episodeId: _state!.episodeId,
              playbackPosition: pos,
              isPlaying: true,
              participants: _state!.participants,
              recentChat: _state!.recentChat,
            );
            notifyListeners();
          }
          onPlayReceived?.call(pos, execAt);
          break;

        case 'PAUSE':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          if (_state != null) {
            _state = RoomStateData(
              roomId: _state!.roomId,
              hostId: _state!.hostId,
              mediaId: _state!.mediaId,
              title: _state!.title,
              streamUrl: _state!.streamUrl,
              episodeId: _state!.episodeId,
              playbackPosition: pos,
              isPlaying: false,
              participants: _state!.participants,
              recentChat: _state!.recentChat,
            );
            notifyListeners();
          }
          onPauseReceived?.call(pos);
          break;

        case 'SEEK':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          final execAt = (jsonMap['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          if (_state != null) {
            _state = RoomStateData(
              roomId: _state!.roomId,
              hostId: _state!.hostId,
              mediaId: _state!.mediaId,
              title: _state!.title,
              streamUrl: _state!.streamUrl,
              episodeId: _state!.episodeId,
              playbackPosition: pos,
              isPlaying: _state!.isPlaying,
              participants: _state!.participants,
              recentChat: _state!.recentChat,
            );
            notifyListeners();
          }
          onSeekReceived?.call(pos, execAt);
          break;

        case 'CHANGE_MEDIA':
          final mediaId = jsonMap['media_id'] ?? '';
          final title = jsonMap['title'] ?? '';
          final streamUrl = jsonMap['stream_url'] ?? '';
          if (_state != null) {
            _state = RoomStateData(
              roomId: _state!.roomId,
              hostId: _state!.hostId,
              mediaId: mediaId,
              title: title,
              streamUrl: streamUrl,
              episodeId: jsonMap['episode_id'] ?? '',
              playbackPosition: 0.0,
              isPlaying: false,
              participants: _state!.participants,
              recentChat: _state!.recentChat,
            );
            notifyListeners();
          }
          onMediaChangedReceived?.call(mediaId, title, streamUrl);
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
            _state = RoomStateData(
              roomId: _state!.roomId,
              hostId: _state!.hostId,
              mediaId: _state!.mediaId,
              title: _state!.title,
              streamUrl: _state!.streamUrl,
              episodeId: _state!.episodeId,
              playbackPosition: _state!.playbackPosition,
              isPlaying: _state!.isPlaying,
              participants: _state!.participants,
              recentChat: updatedChat,
            );
            notifyListeners();
          }
          break;

        case 'USER_JOINED':
          if (jsonMap['user'] != null && _state != null) {
            final joined = Participant.fromJson(jsonMap['user']);
            final updatedParts = List<Participant>.from(_state!.participants.where((p) => p.id != joined.id))..add(joined);
            _state = RoomStateData(
              roomId: _state!.roomId,
              hostId: _state!.hostId,
              mediaId: _state!.mediaId,
              title: _state!.title,
              streamUrl: _state!.streamUrl,
              episodeId: _state!.episodeId,
              playbackPosition: _state!.playbackPosition,
              isPlaying: _state!.isPlaying,
              participants: updatedParts,
              recentChat: _state!.recentChat,
            );
            notifyListeners();
          }
          break;

        case 'USER_LEFT':
          if (jsonMap['user'] != null && _state != null) {
            final leftId = jsonMap['user']['id'];
            final updatedParts = _state!.participants.where((p) => p.id != leftId).toList();
            _state = RoomStateData(
              roomId: _state!.roomId,
              hostId: _state!.hostId,
              mediaId: _state!.mediaId,
              title: _state!.title,
              streamUrl: _state!.streamUrl,
              episodeId: _state!.episodeId,
              playbackPosition: _state!.playbackPosition,
              isPlaying: _state!.isPlaying,
              participants: updatedParts,
              recentChat: _state!.recentChat,
            );
            notifyListeners();
          }
          break;
      }
    } catch (_) {}
  }

  void sendPlay(double position) {
    _send({
      'type': 'PLAY',
      'position': position,
    });
  }

  void sendPause(double position) {
    _send({
      'type': 'PAUSE',
      'position': position,
    });
  }

  void sendSeek(double position) {
    _send({
      'type': 'SEEK',
      'position': position,
    });
  }

  void sendChangeMedia(String mediaId, String title, String streamUrl, String episodeId) {
    _send({
      'type': 'CHANGE_MEDIA',
      'media_id': mediaId,
      'title': title,
      'stream_url': streamUrl,
      'episode_id': episodeId,
    });
  }

  void sendChat(String message) {
    if (message.trim().isEmpty) return;
    _send({
      'type': 'CHAT',
      'message': message.trim(),
    });
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
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

