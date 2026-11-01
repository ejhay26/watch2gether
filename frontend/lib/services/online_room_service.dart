import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/room_models.dart';
import 'room_crypto_service.dart';

enum OnlineConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class OnlineRoomService extends ChangeNotifier {
  static final OnlineRoomService _instance = OnlineRoomService._internal();
  factory OnlineRoomService() => _instance;
  OnlineRoomService._internal();

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _hostSyncTimer;
  int _ref = 1;

  OnlineConnectionStatus _status = OnlineConnectionStatus.disconnected;
  String? _activeRoomCode;
  String? _currentUserId;
  String? _currentUsername;
  bool _isHost = false;

  RoomStateData? _state;
  final List<Participant> _participants = [];
  final List<ChatMessage> _recentChat = [];

  // Callbacks consumed by RoomService and PlayerScreen
  ValueChanged<RoomStateData>? onRoomStateChanged;
  Function(double position, int executeAtMs)? onPlayReceived;
  Function(double position)? onPauseReceived;
  Function(double position, int executeAtMs)? onSeekReceived;
  Function(String mediaId, String title, String streamUrl, String episodeId, Map<String, String>? headers)? onMediaChanged;
  Function(ChatMessage message)? onChatReceived;
  Function(Participant user)? onUserJoined;
  Function(String userId)? onUserLeft;

  // Supabase Realtime Edge WSS Endpoint
  static const String _defaultWssUrl =
      'wss://xlciaxmmpqggacedbtsy.supabase.co/realtime/v1/websocket?apikey=sb_publishable_MWhAX8M8Lj9y24PTHbltVQ_3FE2HsiL&vsn=1.0.0';

  OnlineConnectionStatus get status => _status;
  bool get isConnected => _status == OnlineConnectionStatus.connected;
  bool get isHost => _isHost;
  String? get activeRoomCode => _activeRoomCode;
  RoomStateData? get state => _state;
  List<Participant> get participants => List.unmodifiable(_participants);
  List<ChatMessage> get recentChat => List.unmodifiable(_recentChat);

  // --- 1. Clean Alphanumeric Room Codes ---

  static String generateRoomCode() {
    const prefixes = [
      'SKY', 'STAR', 'NOVA', 'LION', 'MOON', 'COSMO',
      'MARS', 'ECHO', 'WAVE', 'APEX', 'ZEN', 'SOLAR',
      'NEO', 'ORBIT', 'NEXUS', 'PULSE', 'TITAN', 'CYBER'
    ];
    final rnd = Random.secure();
    final prefix = prefixes[rnd.nextInt(prefixes.length)];
    final num = rnd.nextInt(900) + 100; // 100-999
    return '$prefix-$num';
  }

  static String cleanCode(String code) {
    return code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  // --- 2. Host an Online Worldwide Party ---

  Future<String?> hostRoom({
    required String userId,
    required String username,
    String title = "Watch Party",
  }) async {
    await disconnect();

    _activeRoomCode = generateRoomCode();
    _currentUserId = userId;
    _currentUsername = username;
    _isHost = true;
    _status = OnlineConnectionStatus.connecting;
    notifyListeners();

    final hostParticipant = Participant(id: userId, username: username, isHost: true);
    _participants.clear();
    _participants.add(hostParticipant);
    _recentChat.clear();

    _state = RoomStateData(
      roomId: _activeRoomCode!,
      hostId: userId,
      mediaId: '',
      title: title,
      streamUrl: '',
      episodeId: '',
      playbackPosition: 0.0,
      isPlaying: false,
      lastUpdated: DateTime.now(),
      participants: List.from(_participants),
      recentChat: List.from(_recentChat),
    );

    final cleanTopic = 'w2g_${cleanCode(_activeRoomCode!)}';

    try {
      final ws = await WebSocket.connect(_defaultWssUrl).timeout(const Duration(seconds: 8));
      _socket = ws;

      _socketListen(ws, cleanTopic);

      // Join Phoenix Realtime Channel
      _sendPhxJoin(ws, cleanTopic);
      _startHeartbeat(ws);

      _status = OnlineConnectionStatus.connected;
      onRoomStateChanged?.call(_state!);
      notifyListeners();

      _startHostPeriodicSync();
      return _activeRoomCode;
    } catch (e) {
      debugPrint('[OnlineRoomService] Host connection error: $e');
      await disconnect();
      return null;
    }
  }

  // --- 3. Join an Online Worldwide Party by Code ---

  Future<bool> joinRoom({
    required String roomCode,
    required String userId,
    required String username,
  }) async {
    await disconnect();

    final clean = cleanCode(roomCode);
    if (clean.isEmpty) return false;

    _activeRoomCode = roomCode.trim().toUpperCase();
    _currentUserId = userId;
    _currentUsername = username;
    _isHost = false;
    _status = OnlineConnectionStatus.connecting;
    notifyListeners();

    final cleanTopic = 'w2g_$clean';
    final completer = Completer<bool>();

    try {
      final ws = await WebSocket.connect(_defaultWssUrl).timeout(const Duration(seconds: 8));
      _socket = ws;

      // Handle handshake timeout
      Timer(const Duration(seconds: 6), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      _socketListen(ws, cleanTopic, onJoinedRoomState: () {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      // Join Phoenix Channel
      _sendPhxJoin(ws, cleanTopic);
      _startHeartbeat(ws);

      // Send encrypted request for active room state to host
      await Future.delayed(const Duration(milliseconds: 300));
      _broadcastEncrypted({
        'type': 'REQUEST_STATE',
        'user': {
          'id': userId,
          'username': username,
          'is_host': false,
        },
      });

      final success = await completer.future;
      if (success) {
        _status = OnlineConnectionStatus.connected;
        notifyListeners();
        return true;
      } else {
        await disconnect();
        return false;
      }
    } catch (e) {
      debugPrint('[OnlineRoomService] Join connection error: $e');
      await disconnect();
      return false;
    }
  }

  // --- 4. WebSocket Event Handling & Decryption ---

  void _socketListen(WebSocket ws, String cleanTopic, {VoidCallback? onJoinedRoomState}) {
    ws.listen(
      (data) {
        try {
          final msg = jsonDecode(data.toString()) as Map<String, dynamic>;
          final event = msg['event'] as String?;
          final payload = msg['payload'] as Map<String, dynamic>?;

          if (event == 'broadcast' && payload != null) {
            final innerPayload = payload['payload'] as Map<String, dynamic>?;
            if (innerPayload != null) {
              final senderId = innerPayload['sender_id'] as String?;
              // Ignore own reflected packets
              if (senderId != null && senderId == _currentUserId) return;

              final encryptedData = innerPayload['data'] as String?;
              if (encryptedData != null && _activeRoomCode != null) {
                final decrypted = RoomCryptoService.decryptPayload(encryptedData, _activeRoomCode!);
                _handleDecryptedEvent(decrypted, onJoinedRoomState);
              }
            }
          }
        } catch (e) {
          debugPrint('[OnlineRoomService] Message parse error: $e');
        }
      },
      onDone: () {
        debugPrint('[OnlineRoomService] Socket closed by server');
        disconnect();
      },
      onError: (err) {
        debugPrint('[OnlineRoomService] Socket error: $err');
        disconnect();
      },
    );
  }

  void _handleDecryptedEvent(Map<String, dynamic> msg, VoidCallback? onJoinedRoomState) {
    final type = msg['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'REQUEST_STATE':
        // If I am the host, register the new participant and reply with full ROOM_STATE
        if (_isHost && _state != null) {
          final userJson = msg['user'] as Map<String, dynamic>?;
          if (userJson != null) {
            final joined = Participant.fromJson(userJson);
            _participants.removeWhere((p) => p.id == joined.id);
            _participants.add(joined);
            _updateHostRoomState();
          }

          // Broadcast active room state
          _broadcastEncrypted({
            'type': 'ROOM_STATE',
            'room_state': _serializeState(_state!),
          });
        }
        break;

      case 'ROOM_STATE':
        final rawState = msg['room_state'] as Map<String, dynamic>?;
        if (rawState != null) {
          _state = RoomStateData.fromJson(rawState);
          _participants.clear();
          _participants.addAll(_state!.participants);
          _recentChat.clear();
          _recentChat.addAll(_state!.recentChat);
          onRoomStateChanged?.call(_state!);
          notifyListeners();
          onJoinedRoomState?.call();
        }
        break;

      case 'PLAY':
        final pos = (msg['position'] as num?)?.toDouble() ?? 0.0;
        final execAt = (msg['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        if (_state != null) {
          _state = _state!.copyWith(playbackPosition: pos, isPlaying: true, lastUpdated: DateTime.now());
          notifyListeners();
        }
        onPlayReceived?.call(pos, execAt);
        break;

      case 'PAUSE':
        final pos = (msg['position'] as num?)?.toDouble() ?? 0.0;
        if (_state != null) {
          _state = _state!.copyWith(playbackPosition: pos, isPlaying: false, lastUpdated: DateTime.now());
          notifyListeners();
        }
        onPauseReceived?.call(pos);
        break;

      case 'SEEK':
        final pos = (msg['position'] as num?)?.toDouble() ?? 0.0;
        final execAt = (msg['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        if (_state != null) {
          _state = _state!.copyWith(playbackPosition: pos, lastUpdated: DateTime.now());
          notifyListeners();
        }
        onSeekReceived?.call(pos, execAt);
        break;

      case 'SYNC_TIME':
        final pos = (msg['position'] as num?)?.toDouble() ?? 0.0;
        final isPlaying = msg['is_playing'] as bool? ?? true;
        if (_state != null) {
          _state = _state!.copyWith(playbackPosition: pos, isPlaying: isPlaying, lastUpdated: DateTime.now());
          notifyListeners();
        }
        break;

      case 'CHANGE_MEDIA':
        final mediaId = msg['media_id'] ?? '';
        final title = msg['title'] ?? '';
        final streamUrl = msg['stream_url'] ?? '';
        final episodeId = msg['episode_id'] ?? '';
        final rawHeaders = msg['headers'] as Map<String, dynamic>?;
        final headers = rawHeaders?.map((k, v) => MapEntry(k, v.toString()));

        if (_state != null) {
          _state = _state!.copyWith(
            mediaId: mediaId,
            title: title,
            streamUrl: streamUrl,
            episodeId: episodeId,
            headers: headers,
            playbackPosition: 0.0,
            isPlaying: true,
            lastUpdated: DateTime.now(),
          );
          notifyListeners();
        }
        onMediaChanged?.call(mediaId, title, streamUrl, episodeId, headers);
        break;

      case 'CHAT':
        final user = msg['user'] != null ? Participant.fromJson(msg['user']) : null;
        final chatMsg = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user?.id ?? msg['user_id'] ?? '',
          username: user?.username ?? msg['username'] ?? 'Peer',
          message: msg['message'] ?? '',
          timestamp: DateTime.now(),
        );
        _recentChat.add(chatMsg);
        if (_recentChat.length > 100) _recentChat.removeAt(0);
        if (_state != null) {
          _state = _state!.copyWith(recentChat: List.from(_recentChat));
          notifyListeners();
        }
        onChatReceived?.call(chatMsg);
        break;

      case 'USER_JOINED':
        if (msg['user'] != null) {
          final joined = Participant.fromJson(msg['user']);
          _participants.removeWhere((p) => p.id == joined.id);
          _participants.add(joined);
          if (_state != null) {
            _state = _state!.copyWith(participants: List.from(_participants));
            notifyListeners();
          }
          onUserJoined?.call(joined);
        }
        break;

      case 'USER_LEFT':
        final leftId = msg['user_id'] as String?;
        if (leftId != null) {
          _participants.removeWhere((p) => p.id == leftId);
          if (_state != null) {
            _state = _state!.copyWith(participants: List.from(_participants));
            notifyListeners();
          }
          onUserLeft?.call(leftId);
        }
        break;

      case 'USER_RENAMED':
        final uid = msg['user_id'] as String?;
        final newName = msg['new_name'] as String?;
        if (uid != null && newName != null && newName.isNotEmpty) {
          final idx = _participants.indexWhere((p) => p.id == uid);
          if (idx != -1) {
            final old = _participants[idx];
            _participants[idx] = Participant(id: old.id, username: newName, isHost: old.isHost);
            if (_state != null) {
              _state = _state!.copyWith(participants: List.from(_participants));
              notifyListeners();
            }
          }
        }
        break;
    }
  }

  // --- 5. Outgoing Senders (End-to-End Encrypted via RoomCryptoService) ---

  void sendPlay(double position, {int? executeAtMs}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final execAt = executeAtMs ?? (now + 120);

    if (_state != null) {
      _state = _state!.copyWith(playbackPosition: position, isPlaying: true, lastUpdated: DateTime.now());
      notifyListeners();
    }

    _broadcastEncrypted({
      'type': 'PLAY',
      'position': position,
      'execute_at_ms': execAt,
    });
  }

  void sendPause(double position) {
    if (_state != null) {
      _state = _state!.copyWith(playbackPosition: position, isPlaying: false, lastUpdated: DateTime.now());
      notifyListeners();
    }

    _broadcastEncrypted({
      'type': 'PAUSE',
      'position': position,
    });
  }

  void sendSeek(double position, {int? executeAtMs}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final execAt = executeAtMs ?? (now + 120);

    if (_state != null) {
      _state = _state!.copyWith(playbackPosition: position, lastUpdated: DateTime.now());
      notifyListeners();
    }

    _broadcastEncrypted({
      'type': 'SEEK',
      'position': position,
      'execute_at_ms': execAt,
    });
  }

  void sendChangeMedia(
    String mediaId,
    String title,
    String streamUrl,
    String episodeId, {
    Map<String, String>? headers,
  }) {
    if (_state != null) {
      _state = _state!.copyWith(
        mediaId: mediaId,
        title: title,
        streamUrl: streamUrl,
        episodeId: episodeId,
        headers: headers,
        playbackPosition: 0.0,
        isPlaying: true,
        lastUpdated: DateTime.now(),
      );
      onRoomStateChanged?.call(_state!);
      notifyListeners();
    }

    _broadcastEncrypted({
      'type': 'CHANGE_MEDIA',
      'media_id': mediaId,
      'title': title,
      'stream_url': streamUrl,
      'episode_id': episodeId,
      'headers': headers,
      'playback_position': 0.0,
      'is_playing': true,
    });
  }

  void sendChat(String text, {required String userId, required String username}) {
    final chatMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      username: username,
      message: text,
      timestamp: DateTime.now(),
    );
    _recentChat.add(chatMsg);
    if (_recentChat.length > 100) _recentChat.removeAt(0);
    if (_state != null) {
      _state = _state!.copyWith(recentChat: List.from(_recentChat));
      notifyListeners();
    }

    _broadcastEncrypted({
      'type': 'CHAT',
      'message': text,
      'user_id': userId,
      'username': username,
    });
  }

  void sendRename(String newName, {required String userId}) {
    _broadcastEncrypted({
      'type': 'USER_RENAMED',
      'user_id': userId,
      'new_name': newName,
    });
  }

  void updateHostActiveMedia(
    String mediaId,
    String title,
    String streamUrl,
    String episodeId, {
    Map<String, String>? headers,
  }) {
    if (!_isHost) return;
    sendChangeMedia(mediaId, title, streamUrl, episodeId, headers: headers);
  }

  // --- 6. Helper & Phoenix Protocol Routines ---

  void _broadcastEncrypted(Map<String, dynamic> data) {
    if (_socket == null || _activeRoomCode == null) return;
    try {
      final cleanTopic = 'w2g_${cleanCode(_activeRoomCode!)}';
      final encryptedJson = RoomCryptoService.encryptPayload(data, _activeRoomCode!);
      final msg = jsonEncode({
        'topic': 'realtime:$cleanTopic',
        'event': 'broadcast',
        'payload': {
          'type': 'broadcast',
          'event': 'w2g_sync',
          'payload': {
            'sender_id': _currentUserId ?? 'anon',
            'data': encryptedJson,
          }
        },
        'ref': (_ref++).toString(),
      });
      _socket?.add(msg);
    } catch (e) {
      debugPrint('[OnlineRoomService] Broadcast error: $e');
    }
  }

  void _sendPhxJoin(WebSocket ws, String cleanTopic) {
    final joinMsg = jsonEncode({
      'topic': 'realtime:$cleanTopic',
      'event': 'phx_join',
      'payload': {
        'config': {
          'broadcast': {'self': false, 'ack': false},
          'presence': {'key': _currentUserId ?? 'peer_${Random().nextInt(9999)}'}
        }
      },
      'ref': (_ref++).toString(),
    });
    ws.add(joinMsg);
  }

  void _startHeartbeat(WebSocket ws) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (t) {
      try {
        final hb = jsonEncode({
          'topic': 'phoenix',
          'event': 'heartbeat',
          'payload': {},
          'ref': (_ref++).toString(),
        });
        ws.add(hb);
      } catch (_) {
        t.cancel();
      }
    });
  }

  void _startHostPeriodicSync() {
    _hostSyncTimer?.cancel();
    _hostSyncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_isHost && _state != null && _state!.isPlaying) {
        final currentPos = _state!.currentPosition;
        _broadcastEncrypted({
          'type': 'SYNC_TIME',
          'position': currentPos,
          'is_playing': true,
        });
      }
    });
  }

  void _updateHostRoomState() {
    if (_state != null) {
      _state = _state!.copyWith(
        participants: List.from(_participants),
        recentChat: List.from(_recentChat),
        lastUpdated: DateTime.now(),
      );
      onRoomStateChanged?.call(_state!);
      notifyListeners();
    }
  }

  Map<String, dynamic> _serializeState(RoomStateData s) {
    return {
      'room_id': s.roomId,
      'host_id': s.hostId,
      'media_id': s.mediaId,
      'title': s.title,
      'stream_url': s.streamUrl,
      'episode_id': s.episodeId,
      'headers': s.headers,
      'playback_position': s.playbackPosition,
      'is_playing': s.isPlaying,
      'last_updated': s.lastUpdated.toIso8601String(),
      'participants': s.participants.map((p) => p.toJson()).toList(),
      'recent_chat': s.recentChat.map((c) => c.toJson()).toList(),
    };
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _hostSyncTimer?.cancel();
    _heartbeatTimer = null;
    _hostSyncTimer = null;

    if (_activeRoomCode != null && _currentUserId != null) {
      try {
        _broadcastEncrypted({
          'type': 'USER_LEFT',
          'user_id': _currentUserId,
        });
      } catch (_) {}
    }

    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    _status = OnlineConnectionStatus.disconnected;
    _activeRoomCode = null;
    _isHost = false;
    _state = null;
    _participants.clear();
    _recentChat.clear();
    notifyListeners();
  }
}
