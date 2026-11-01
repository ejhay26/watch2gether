import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/room_models.dart';
import 'local_store_service.dart';
import 'room_crypto_service.dart';

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
  WebSocket? _directClientSocket;
  StreamSubscription? _clientSub;

  MeshConnectionMode _mode = MeshConnectionMode.disconnected;
  String? _activeRoomId;
  String? _activeRoomCode;
  String? _localIpAddress;
  List<String> _availableIps = [];
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
  List<String> get availableIps => List.unmodifiable(_availableIps);
  bool get isHost => _isHost;
  bool get isConnected => _mode != MeshConnectionMode.disconnected;
  RoomStateData? get state => _state;

  // --- 1. Smart Physical IP & Code Encoding/Decoding ---

  static bool isVirtualInterface(String name) {
    final n = name.toLowerCase();
    return n.contains('vethernet') ||
        n.contains('virtual') ||
        n.contains('vmware') ||
        n.contains('vbox') ||
        n.contains('wsl') ||
        n.contains('docker') ||
        n.contains('teredo') ||
        n.contains('pseudo') ||
        n.contains('isatap') ||
        n.contains('loopback');
  }

  Future<String?> detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final List<String> physicalIps = [];
      String? preferredIp;

      for (final iface in interfaces) {
        if (isVirtualInterface(iface.name)) continue;
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            physicalIps.add(ip);
            // Prefer standard private LAN subnets on primary adapters
            if (ip.startsWith('192.168.') && !iface.name.contains('*')) {
              preferredIp ??= ip;
            } else if (ip.startsWith('10.') && preferredIp == null) {
              preferredIp = ip;
            }
          }
        }
      }

      _availableIps = physicalIps.isNotEmpty ? physicalIps : ['127.0.0.1'];
      _localIpAddress = preferredIp ?? (physicalIps.isNotEmpty ? physicalIps.first : '127.0.0.1');
      return _localIpAddress;
    } catch (_) {
      _availableIps = ['127.0.0.1'];
      _localIpAddress = '127.0.0.1';
      return _localIpAddress;
    }
  }

  void setCustomHostIp(String ip) {
    _localIpAddress = ip;
    if (_isHost && _mode == MeshConnectionMode.directLanHost) {
      _activeRoomCode = encodeIpToCode(ip);
      _activeRoomId = _activeRoomCode;
      notifyListeners();
    }
  }

  static String encodeIpToCode(String ip) {
    try {
      final parts = ip.split('.').map(int.parse).toList();
      if (parts.length != 4) return ip;
      // 64-bit safe arithmetic in Dart
      final val = (parts[0] * 16777216) + (parts[1] * 65536) + (parts[2] * 256) + parts[3];
      return val.toRadixString(36).toUpperCase().padLeft(6, '0');
    } catch (_) {
      return ip.replaceAll('.', '').substring(0, 6).toUpperCase();
    }
  }

  static String? decodeCodeToIp(String code) {
    try {
      final clean = code.trim().toUpperCase();
      if (clean.contains('.')) return clean; // Direct IP entered by user
      final val = int.tryParse(clean, radix: 36);
      if (val != null && val > 0) {
        final p0 = (val ~/ 16777216) & 0xFF;
        final p1 = (val ~/ 65536) & 0xFF;
        final p2 = (val ~/ 256) & 0xFF;
        final p3 = val & 0xFF;
        return '$p0.$p1.$p2.$p3';
      }
    } catch (_) {}
    return null;
  }

  // --- 2. Host Direct Encrypted LAN Party ---
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
    Participant? socketPeer;

    socket.listen(
      (data) {
        try {
          final msg = RoomCryptoService.decryptPayload(data.toString(), _activeRoomCode ?? '');
          final type = msg['type'] as String?;

          if (type == 'JOIN') {
            final uid = msg['user_id'] ?? 'peer_${_connectedPeerSockets.length}';
            final uname = msg['username'] ?? 'Peer';
            socketPeer = Participant(id: uid, username: uname, isHost: false);

            _participants.removeWhere((p) => p.id == uid);
            _participants.add(socketPeer!);
            _updateHostRoomState();

            // Send full encrypted ROOM_STATE to newly joined peer immediately
            _sendEncryptedToSocket(socket, {
              'type': 'ROOM_STATE',
              'room_state': _serializeState(_state!),
            });

            // Broadcast USER_JOINED to all other peers
            _broadcastToAllPeers({
              'type': 'USER_JOINED',
              'user': {'id': uid, 'username': uname, 'is_host': false},
            }, exclude: socket);

            onUserJoined?.call(socketPeer!);
            return;
          }

          if (type == 'RENAME') {
            final uid = msg['user_id'];
            final newName = msg['new_name'] as String?;
            if (uid != null && newName != null && newName.isNotEmpty) {
              final idx = _participants.indexWhere((p) => p.id == uid);
              if (idx != -1) {
                final old = _participants[idx];
                _participants[idx] = Participant(id: old.id, username: newName, isHost: old.isHost);
                _updateHostRoomState();
                _broadcastToAllPeers({
                  'type': 'USER_RENAMED',
                  'user_id': uid,
                  'new_name': newName,
                });
              }
            }
            return;
          }

          // Forward events to all other peers & update state
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
            isPlaying: true,
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
          _sendEncryptedToSocket(senderSocket, {
            'type': 'ROOM_STATE',
            'room_state': _serializeState(_state!),
          });
        }
        return;
    }

    // Broadcast to other peers
    _broadcastToAllPeers(msg, exclude: senderSocket);
  }

  void _sendEncryptedToSocket(WebSocket socket, Map<String, dynamic> data) {
    try {
      final payload = RoomCryptoService.encryptPayload(data, _activeRoomCode ?? '');
      socket.add(payload);
    } catch (_) {}
  }

  void _broadcastToAllPeers(Map<String, dynamic> data, {WebSocket? exclude}) {
    final payload = RoomCryptoService.encryptPayload(data, _activeRoomCode ?? '');
    for (final s in List<WebSocket>.from(_connectedPeerSockets)) {
      if (s != exclude) {
        try {
          s.add(payload);
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

  // --- 3. Join Direct Encrypted LAN Party with Handshake Verification ---
  Future<bool> joinParty({
    required String codeOrAddress,
    required String userId,
    required String username,
  }) async {
    await disconnect();

    String targetIp = '127.0.0.1';
    int targetPort = _port;

    final trimmed = codeOrAddress.trim();
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      targetIp = parts[0];
      targetPort = int.tryParse(parts[1]) ?? _port;
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

    // 1. Attempt Direct LAN Socket Connection with explicit Handshake verification
    final directWsUri = Uri.parse('ws://$targetIp:$targetPort');
    final directSuccess = await _attemptDirectConnection(directWsUri, userId, username);
    if (directSuccess) {
      return true;
    }

    // 2. Dual-Layer Redundancy: Attempt Go Companion Server WebSocket route on Port 8080
    final companionWsUri = Uri.parse('ws://$targetIp:8080/ws/room/$_activeRoomCode?userId=$userId&username=${Uri.encodeComponent(username)}');
    final companionSuccess = await _attemptDirectConnection(companionWsUri, userId, username);
    if (companionSuccess) {
      return true;
    }

    disconnect();
    return false;
  }

  Future<bool> _attemptDirectConnection(Uri uri, String userId, String username) async {
    final completer = Completer<bool>();
    Timer? timeoutTimer;

    try {
      final socket = await WebSocket.connect(uri.toString()).timeout(const Duration(milliseconds: 3500));
      _directClientSocket = socket;
      _mode = MeshConnectionMode.directLanClient;

      timeoutTimer = Timer(const Duration(milliseconds: 4000), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      // Send initial encrypted JOIN message
      _sendEncryptedToSocket(socket, {
        'type': 'JOIN',
        'user_id': userId,
        'username': username,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      socket.listen(
        (data) {
          final msg = RoomCryptoService.decryptPayload(data.toString(), _activeRoomCode ?? '');
          _handleClientIncomingMessage(msg);

          if (!completer.isCompleted) {
            completer.complete(true);
            timeoutTimer?.cancel();
          }
        },
        onDone: () {
          disconnect();
        },
        onError: (_) {
          if (!completer.isCompleted) {
            completer.complete(false);
            timeoutTimer?.cancel();
          }
          disconnect();
        },
      );

      final ok = await completer.future;
      if (ok) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      timeoutTimer?.cancel();
      return false;
    }
  }

  Future<bool> _connectToCompanionBackend(String code, String userId, String username) async {
    final base = LocalStoreService().companionBackendUrl;
    final wsScheme = base.startsWith('https') ? 'wss' : 'ws';
    final host = base.replaceFirst(RegExp(r'^https?:\/\/'), '');
    final uri = Uri.parse('$wsScheme://$host/ws/room/$code?userId=$userId&username=${Uri.encodeComponent(username)}');

    try {
      final socket = await WebSocket.connect(uri.toString()).timeout(const Duration(milliseconds: 3500));
      _directClientSocket = socket;
      _mode = MeshConnectionMode.companionServer;
      _activeRoomCode = code;
      _activeRoomId = code;
      _isHost = false;

      _sendEncryptedToSocket(socket, {
        'type': 'JOIN',
        'user_id': userId,
        'username': username,
      });

      socket.listen(
        (data) {
          final msg = RoomCryptoService.decryptPayload(data.toString(), _activeRoomCode ?? '');
          _handleClientIncomingMessage(msg);
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

  void _handleClientIncomingMessage(Map<String, dynamic> jsonMap) {
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
            isPlaying: true,
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

      case 'USER_RENAMED':
        final uid = jsonMap['user_id'];
        final newName = jsonMap['new_name'] as String?;
        if (uid != null && newName != null && _state != null) {
          final updatedParts = _state!.participants.map((p) {
            if (p.id == uid) return Participant(id: p.id, username: newName, isHost: p.isHost);
            return p;
          }).toList();
          _state = _state!.copyWith(participants: updatedParts);
          notifyListeners();
        }
        break;
    }
  }

  // --- 4. Outgoing Senders (Always Encrypted with Room Code) ---
  void sendPlay(double position, {int? executeAtMs}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final execAt = executeAtMs ?? (now + 120);

    final msg = {
      'type': 'PLAY',
      'position': position,
      'execute_at_ms': execAt,
    };
    _dispatchOutgoing(msg);
  }

  void sendPause(double position) {
    final msg = {
      'type': 'PAUSE',
      'position': position,
    };
    _dispatchOutgoing(msg);
  }

  void sendSeek(double position, {int? executeAtMs}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final execAt = executeAtMs ?? (now + 120);

    final msg = {
      'type': 'SEEK',
      'position': position,
      'execute_at_ms': execAt,
    };
    _dispatchOutgoing(msg);
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

    final msg = {
      'type': 'CHANGE_MEDIA',
      'media_id': mediaId,
      'title': title,
      'stream_url': streamUrl,
      'episode_id': episodeId,
      'headers': headers,
      'playback_position': 0.0,
      'is_playing': true,
    };
    _dispatchOutgoing(msg);
  }

  void sendChat(String text, {required String userId, required String username}) {
    final msg = {
      'type': 'CHAT',
      'message': text,
      'user_id': userId,
      'username': username,
    };
    _dispatchOutgoing(msg);
  }

  void sendRename(String newName, {required String userId}) {
    final msg = {
      'type': 'RENAME',
      'user_id': userId,
      'new_name': newName,
    };
    _dispatchOutgoing(msg);
  }

  void _dispatchOutgoing(Map<String, dynamic> data) {
    if (_mode == MeshConnectionMode.directLanHost) {
      _broadcastToAllPeers(data);
    } else if (_directClientSocket != null) {
      _sendEncryptedToSocket(_directClientSocket!, data);
    }
  }

  // --- 5. Disconnection & Cleanup ---
  Future<void> disconnect() async {
    for (final s in _connectedPeerSockets) {
      try {
        await s.close();
      } catch (_) {}
    }
    _connectedPeerSockets.clear();

    if (_localServer != null) {
      try {
        await _localServer!.close(force: true);
      } catch (_) {}
      _localServer = null;
    }

    if (_directClientSocket != null) {
      try {
        await _directClientSocket!.close();
      } catch (_) {}
      _directClientSocket = null;
    }

    await _clientSub?.cancel();
    _clientSub = null;

    _mode = MeshConnectionMode.disconnected;
    _activeRoomId = null;
    _activeRoomCode = null;
    _isHost = false;
    _state = null;
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
