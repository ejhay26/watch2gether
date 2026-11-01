import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/room_models.dart';
import 'local_store_service.dart';

enum MeshConnectionMode {
  directLanHost,
  directLanClient,
  companionServer,
  disconnected,
}

class P2PMeshService extends ChangeNotifier {
  static final P2PMeshService _instance = P2PMeshService._internal();
  factory P2PMeshService() => _instance;
  P2PMeshService._internal();

  HttpServer? _localServer;
  final List<WebSocket> _connectedPeerSockets = [];
  WebSocketChannel? _clientChannel;
  StreamSubscription? _clientSub;

  MeshConnectionMode _mode = MeshConnectionMode.disconnected;
  String? _activeRoomId;
  String? _activeRoomCode;
  String? _localIpAddress;
  int _port = 8888;
  bool _isHost = false;

  RoomStateData? _state;
  final List<Participant> _participants = [];
  final List<ChatMessage> _recentChat = [];

  // Callbacks for RoomService consumption
  ValueChanged<RoomStateData>? onRoomStateChanged;
  Function(double position, int executeAtMs)? onPlayReceived;
  Function(double position)? onPauseReceived;
  Function(double position, int executeAtMs)? onSeekReceived;
  Function(String mediaId, String title, String streamUrl, String episodeId, Map<String, String>? headers)? onMediaChanged;
  Function(ChatMessage message)? onChatReceived;
  Function(Participant user)? onUserJoined;
  Function(String userId)? onUserLeft;

  MeshConnectionMode get mode => _mode;
  String? get activeRoomId => _activeRoomId;
  String? get activeRoomCode => _activeRoomCode;
  String? get localIpAddress => _localIpAddress;
  bool get isHost => _isHost;
  bool get isConnected => _mode != MeshConnectionMode.disconnected;
  RoomStateData? get state => _state;

  // --- 1. IP & Code Encoding/Decoding ---
  Future<String?> detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            // Prefer typical private LAN subnets
            if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
              _localIpAddress = ip;
              return ip;
            }
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        _localIpAddress = interfaces.first.addresses.first.address;
        return _localIpAddress;
      }
    } catch (_) {}
    _localIpAddress = '127.0.0.1';
    return _localIpAddress;
  }

  static String encodeIpToCode(String ip) {
    try {
      final parts = ip.split('.').map(int.parse).toList();
      if (parts.length != 4) return ip;
      final val = (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
      return val.toRadixString(36).toUpperCase().padLeft(6, '0');
    } catch (_) {
      return ip.replaceAll('.', '').substring(0, 6).toUpperCase();
    }
  }

  static String? decodeCodeToIp(String code) {
    try {
      final clean = code.trim().toUpperCase();
      if (clean.contains('.')) return clean; // Direct IP entered
      if (clean.length >= 6) {
        final val = int.parse(clean, radix: 36);
        final p0 = (val >> 24) & 0xFF;
        final p1 = (val >> 16) & 0xFF;
        final p2 = (val >> 8) & 0xFF;
        final p3 = val & 0xFF;
        return '$p0.$p1.$p2.$p3';
      }
    } catch (_) {}
    return null;
  }

  // --- 2. Host Direct LAN Party ---
  Future<String?> hostDirectParty({
    required String hostUserId,
    required String hostUsername,
    String title = "Watch Party",
    int? customPort,
  }) async {
    await disconnect();

    _port = customPort ?? LocalStoreService().meshDirectPort;
    final ip = await detectLocalIp() ?? '127.0.0.1';
    _localIpAddress = ip;
    _activeRoomCode = encodeIpToCode(ip);
    _activeRoomId = _activeRoomCode;
    _isHost = true;

    try {
      _localServer = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _mode = MeshConnectionMode.directLanHost;

      final hostParticipant = Participant(
        id: hostUserId,
        username: hostUsername,
        isHost: true,
      );

      _participants.clear();
      _participants.add(hostParticipant);
      _recentChat.clear();

      _state = RoomStateData(
        roomId: _activeRoomCode!,
        hostId: hostUserId,
        mediaId: '',
        title: title,
        streamUrl: '',
        episodeId: '',
        playbackPosition: 0.0,
        isPlaying: false,
        participants: List.from(_participants),
        recentChat: List.from(_recentChat),
        lastUpdated: DateTime.now(),
      );

      // Listen for incoming peer WebSocket connections
      _localServer!.transform(WebSocketTransformer()).listen((WebSocket socket) {
        _handleIncomingPeerSocket(socket);
      });

      notifyListeners();
      return _activeRoomCode;
    } catch (e) {
      _mode = MeshConnectionMode.disconnected;
      notifyListeners();
      return null;
    }
  }

  void _handleIncomingPeerSocket(WebSocket socket) {
    _connectedPeerSockets.add(socket);

    // Send initial room state to the newly connected peer
    if (_state != null) {
      socket.add(jsonEncode({
        'type': 'ROOM_STATE',
        'room_state': {
          'room_id': _state!.roomId,
          'host_id': _state!.hostId,
          'media_id': _state!.mediaId,
          'title': _state!.title,
          'stream_url': _state!.streamUrl,
          'episode_id': _state!.episodeId,
          'headers': _state!.headers,
          'playback_position': _state!.playbackPosition,
          'is_playing': _state!.isPlaying,
          'participants': _state!.participants.map((p) => {
            'id': p.id,
            'username': p.username,
            'is_host': p.isHost,
          }).toList(),
          'recent_chat': _state!.recentChat.map((c) => {
            'id': c.id,
            'user_id': c.userId,
            'username': c.username,
            'message': c.message,
            'timestamp': c.timestamp.toIso8601String(),
          }).toList(),
        },
      }));
    }

    Participant? socketPeer;

    socket.listen(
      (data) {
        try {
          final msg = jsonDecode(data.toString()) as Map<String, dynamic>;
          final type = msg['type'] as String?;

          if (type == 'JOIN') {
            final uid = msg['user_id'] ?? 'peer_${_connectedPeerSockets.length}';
            final uname = msg['username'] ?? 'Peer';
            socketPeer = Participant(id: uid, username: uname, isHost: false);

            _participants.removeWhere((p) => p.id == uid);
            _participants.add(socketPeer!);
            _updateHostRoomState();

            _broadcastToAllPeers({
              'type': 'USER_JOINED',
              'user': {'id': uid, 'username': uname, 'is_host': false},
            });
            onUserJoined?.call(socketPeer!);
            return;
          }

          // Forward event to all other peers & update state
          _processMessageAsHost(msg, socket);
        } catch (_) {}
      },
      onDone: () {
        _connectedPeerSockets.remove(socket);
        if (socketPeer != null) {
          _participants.removeWhere((p) => p.id == socketPeer!.id);
          _updateHostRoomState();
          _broadcastToAllPeers({
            'type': 'USER_LEFT',
            'user': {'id': socketPeer!.id, 'username': socketPeer!.username},
          });
          onUserLeft?.call(socketPeer!.id);
        }
      },
      onError: (_) {
        _connectedPeerSockets.remove(socket);
      },
    );
  }

  void _processMessageAsHost(Map<String, dynamic> msg, [WebSocket? senderSocket]) {
    final type = msg['type'] as String?;
    switch (type) {
      case 'PLAY':
        final pos = (msg['position'] as num?)?.toDouble() ?? 0.0;
        final execAt = (msg['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        if (_state != null) {
          _state = _state!.copyWith(playbackPosition: pos, isPlaying: true, lastUpdated: DateTime.now());
          onRoomStateChanged?.call(_state!);
        }
        onPlayReceived?.call(pos, execAt);
        break;

      case 'PAUSE':
        final pos = (msg['position'] as num?)?.toDouble() ?? 0.0;
        if (_state != null) {
          _state = _state!.copyWith(playbackPosition: pos, isPlaying: false, lastUpdated: DateTime.now());
          onRoomStateChanged?.call(_state!);
        }
        onPauseReceived?.call(pos);
        break;

      case 'SEEK':
        final pos = (msg['position'] as num?)?.toDouble() ?? 0.0;
        final execAt = (msg['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
        if (_state != null) {
          _state = _state!.copyWith(playbackPosition: pos, lastUpdated: DateTime.now());
          onRoomStateChanged?.call(_state!);
        }
        onSeekReceived?.call(pos, execAt);
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
            isPlaying: false,
            lastUpdated: DateTime.now(),
          );
          onRoomStateChanged?.call(_state!);
        }
        onMediaChanged?.call(mediaId, title, streamUrl, episodeId, headers);
        break;

      case 'CHAT':
        final text = msg['message'] ?? '';
        final uid = msg['user_id'] ?? '';
        final uname = msg['username'] ?? 'Peer';
        final chatItem = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: uid,
          username: uname,
          message: text,
          timestamp: DateTime.now(),
        );
        _recentChat.add(chatItem);
        if (_recentChat.length > 100) _recentChat.removeAt(0);
        _updateHostRoomState();
        onChatReceived?.call(chatItem);
        break;

      case 'SYNC_REQUEST':
        if (_state != null && senderSocket != null) {
          senderSocket.add(jsonEncode({
            'type': 'ROOM_STATE',
            'room_state': _serializeState(_state!),
          }));
        }
        return;
    }

    // Broadcast to other peers
    _broadcastToAllPeers(msg, exclude: senderSocket);
  }

  void _broadcastToAllPeers(Map<String, dynamic> data, {WebSocket? exclude}) {
    final raw = jsonEncode(data);
    for (final s in List<WebSocket>.from(_connectedPeerSockets)) {
      if (s != exclude) {
        try {
          s.add(raw);
        } catch (_) {}
      }
    }
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

  // --- 3. Join Direct LAN Party via Code or IP ---
  Future<bool> joinParty({
    required String codeOrAddress,
    required String userId,
    required String username,
  }) async {
    await disconnect();

    String targetIp = '127.0.0.1';
    int targetPort = 8888;

    final trimmed = codeOrAddress.trim();
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      targetIp = parts[0];
      targetPort = int.tryParse(parts[1]) ?? 8888;
    } else {
      final decodedIp = decodeCodeToIp(trimmed);
      if (decodedIp != null) {
        targetIp = decodedIp;
      } else {
        // Fallback to companion backend
        return _connectToCompanionBackend(trimmed, userId, username);
      }
    }

    _activeRoomCode = trimmed.toUpperCase();
    _activeRoomId = _activeRoomCode;
    _isHost = false;

    final uri = Uri.parse('ws://$targetIp:$targetPort/ws/room/$_activeRoomCode?userId=$userId&username=${Uri.encodeComponent(username)}');

    try {
      _clientChannel = WebSocketChannel.connect(uri);
      _mode = MeshConnectionMode.directLanClient;

      // Send initial handshake JOIN message
      _clientChannel!.sink.add(jsonEncode({
        'type': 'JOIN',
        'user_id': userId,
        'username': username,
      }));

      _clientSub = _clientChannel!.stream.listen(
        (data) {
          _handleClientIncoming(data.toString());
        },
        onDone: () {
          disconnect();
        },
        onError: (_) {
          // If direct LAN connection fails, try fallback to companion server
          _connectToCompanionBackend(trimmed, userId, username);
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      return _connectToCompanionBackend(trimmed, userId, username);
    }
  }

  Future<bool> _connectToCompanionBackend(String code, String userId, String username) async {
    final base = LocalStoreService().companionBackendUrl;
    final wsScheme = base.startsWith('https') ? 'wss' : 'ws';
    final host = base.replaceFirst(RegExp(r'^https?:\/\/'), '');
    final uri = Uri.parse('$wsScheme://$host/ws/room/$code?userId=$userId&username=${Uri.encodeComponent(username)}');

    try {
      _clientChannel = WebSocketChannel.connect(uri);
      _mode = MeshConnectionMode.companionServer;
      _activeRoomCode = code;
      _activeRoomId = code;
      _isHost = false;

      _clientSub = _clientChannel!.stream.listen(
        (data) {
          _handleClientIncoming(data.toString());
        },
        onDone: () => disconnect(),
        onError: (_) => disconnect(),
      );

      notifyListeners();
      return true;
    } catch (_) {
      disconnect();
      return false;
    }
  }

  void _handleClientIncoming(String raw) {
    try {
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      final type = jsonMap['type'] as String?;

      switch (type) {
        case 'ROOM_STATE':
          if (jsonMap['room_state'] != null) {
            _state = RoomStateData.fromJson(jsonMap['room_state']);
            onRoomStateChanged?.call(_state!);
            notifyListeners();
          }
          break;

        case 'PLAY':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          final execAt = (jsonMap['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          if (_state != null) {
            _state = _state!.copyWith(playbackPosition: pos, isPlaying: true, lastUpdated: DateTime.now());
            notifyListeners();
          }
          onPlayReceived?.call(pos, execAt);
          break;

        case 'PAUSE':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          if (_state != null) {
            _state = _state!.copyWith(playbackPosition: pos, isPlaying: false, lastUpdated: DateTime.now());
            notifyListeners();
          }
          onPauseReceived?.call(pos);
          break;

        case 'SEEK':
          final pos = (jsonMap['position'] as num?)?.toDouble() ?? 0.0;
          final execAt = (jsonMap['execute_at_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          if (_state != null) {
            _state = _state!.copyWith(playbackPosition: pos, lastUpdated: DateTime.now());
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
          onMediaChanged?.call(mediaId, title, streamUrl, episodeId, headers);
          break;

        case 'CHAT':
          final user = jsonMap['user'] != null ? Participant.fromJson(jsonMap['user']) : null;
          final msg = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: user?.id ?? jsonMap['user_id'] ?? '',
            username: user?.username ?? jsonMap['username'] ?? 'Peer',
            message: jsonMap['message'] ?? '',
            timestamp: DateTime.now(),
          );
          if (_state != null) {
            final updatedChat = List<ChatMessage>.from(_state!.recentChat)..add(msg);
            _state = _state!.copyWith(recentChat: updatedChat);
            notifyListeners();
          }
          onChatReceived?.call(msg);
          break;

        case 'USER_JOINED':
          if (jsonMap['user'] != null && _state != null) {
            final joined = Participant.fromJson(jsonMap['user']);
            final updatedParts = List<Participant>.from(_state!.participants.where((p) => p.id != joined.id))..add(joined);
            _state = _state!.copyWith(participants: updatedParts);
            notifyListeners();
            onUserJoined?.call(joined);
          }
          break;

        case 'USER_LEFT':
          if (jsonMap['user'] != null && _state != null) {
            final leftId = jsonMap['user']['id'];
            final updatedParts = _state!.participants.where((p) => p.id != leftId).toList();
            _state = _state!.copyWith(participants: updatedParts);
            notifyListeners();
            onUserLeft?.call(leftId);
          }
          break;
      }
    } catch (_) {}
  }

  // --- 4. Outgoing Broadcast Commands ---
  void sendPlay(double position) {
    final execAt = DateTime.now().millisecondsSinceEpoch + 50;
    final msg = {
      'type': 'PLAY',
      'position': position,
      'execute_at_ms': execAt,
    };
    if (_mode == MeshConnectionMode.directLanHost) {
      _processMessageAsHost(msg);
    } else {
      _sendClientMessage(msg);
    }
  }

  void sendPause(double position) {
    final msg = {
      'type': 'PAUSE',
      'position': position,
    };
    if (_mode == MeshConnectionMode.directLanHost) {
      _processMessageAsHost(msg);
    } else {
      _sendClientMessage(msg);
    }
  }

  void sendSeek(double position) {
    final execAt = DateTime.now().millisecondsSinceEpoch + 50;
    final msg = {
      'type': 'SEEK',
      'position': position,
      'execute_at_ms': execAt,
    };
    if (_mode == MeshConnectionMode.directLanHost) {
      _processMessageAsHost(msg);
    } else {
      _sendClientMessage(msg);
    }
  }

  void sendChangeMedia(String mediaId, String title, String streamUrl, String episodeId, {Map<String, String>? headers}) {
    final msg = {
      'type': 'CHANGE_MEDIA',
      'media_id': mediaId,
      'title': title,
      'stream_url': streamUrl,
      'episode_id': episodeId,
      if (headers != null) 'headers': headers,
    };
    if (_mode == MeshConnectionMode.directLanHost) {
      _processMessageAsHost(msg);
    } else {
      _sendClientMessage(msg);
    }
  }

  void sendChat(String message, {required String userId, required String username}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final msg = {
      'type': 'CHAT',
      'message': trimmed,
      'user_id': userId,
      'username': username,
      'user': {
        'id': userId,
        'username': username,
        'is_host': _isHost,
      },
    };
    if (_mode == MeshConnectionMode.directLanHost) {
      _processMessageAsHost(msg);
    } else {
      _sendClientMessage(msg);
    }
  }

  void _sendClientMessage(Map<String, dynamic> data) {
    if (_clientChannel != null && _mode != MeshConnectionMode.disconnected) {
      try {
        _clientChannel!.sink.add(jsonEncode(data));
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    _clientSub?.cancel();
    _clientSub = null;
    _clientChannel?.sink.close();
    _clientChannel = null;

    for (final s in _connectedPeerSockets) {
      try {
        s.close();
      } catch (_) {}
    }
    _connectedPeerSockets.clear();

    if (_localServer != null) {
      try {
        await _localServer!.close(force: true);
      } catch (_) {}
      _localServer = null;
    }

    _mode = MeshConnectionMode.disconnected;
    _isHost = false;
    _state = null;
    _activeRoomId = null;
    _activeRoomCode = null;
    _participants.clear();
    _recentChat.clear();
    notifyListeners();
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
      'participants': s.participants.map((p) => {
        'id': p.id,
        'username': p.username,
        'is_host': p.isHost,
      }).toList(),
      'recent_chat': s.recentChat.map((c) => {
        'id': c.id,
        'user_id': c.userId,
        'username': c.username,
        'message': c.message,
        'timestamp': c.timestamp.toIso8601String(),
      }).toList(),
    };
  }
}
