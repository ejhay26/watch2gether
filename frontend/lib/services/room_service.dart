import 'package:flutter/foundation.dart';
import '../models/room_models.dart';
import 'local_store_service.dart';
import 'online_room_service.dart';
import 'p2p_mesh_service.dart';

enum RoomEngineMode {
  onlineCloud,
  localLan,
}

class RoomService extends ChangeNotifier {
  final OnlineRoomService _online = OnlineRoomService();
  final P2PMeshService _mesh = P2PMeshService();

  RoomEngineMode _activeEngine = RoomEngineMode.onlineCloud;
  String? _currentRoomId;
  String? _userId;
  String? _username;
  RoomStateData? _state;
  bool _isConnected = false;

  // Playback sync event callbacks consumed by PlayerScreen
  ValueChanged<RoomStateData>? onRoomStateReceived;
  Function(double position, int executeAtMs)? onPlayReceived;
  Function(double position)? onPauseReceived;
  Function(double position, int executeAtMs)? onSeekReceived;
  Function(String mediaId, String title, String streamUrl)? onMediaChangedReceived;
  Function(String mediaId, String title, String streamUrl, String episodeId, Map<String, String>? headers)? onPartyPlayPrompt;
  String? localActiveMediaId;

  bool get isInParty => _isConnected && _currentRoomId != null;
  String? get currentRoomId => _currentRoomId;
  String? get username => _username ?? LocalStoreService().username;
  RoomStateData? get state => _state;
  bool get isConnected => _isConnected;
  RoomEngineMode get activeEngine => _activeEngine;
  bool get isOnlineCloud => _activeEngine == RoomEngineMode.onlineCloud;
  bool get isHost => _activeEngine == RoomEngineMode.onlineCloud ? _online.isHost : _mesh.isHost;
  double get currentPosition => _state?.currentPosition ?? 0.0;
  String? get hostIpAddress => _mesh.localIpAddress;
  List<String> get availableHostIps => _mesh.availableIps;

  RoomService() {
    _initEngineHooks();
  }

  void _initEngineHooks() {
    // 1. Online Cloud Realtime hooks (Supabase Realtime)
    _online.onRoomStateChanged = (roomState) {
      if (_activeEngine == RoomEngineMode.onlineCloud) {
        _state = roomState;
        _currentRoomId = roomState.roomId;
        _isConnected = true;
        notifyListeners();
        onRoomStateReceived?.call(roomState);
      }
    };

    _online.onPlayReceived = (position, executeAtMs) {
      if (_activeEngine == RoomEngineMode.onlineCloud) {
        if (_state != null) {
          _state = _state!.copyWith(
            playbackPosition: position,
            isPlaying: true,
            lastUpdated: DateTime.now(),
          );
          notifyListeners();
        }
        onPlayReceived?.call(position, executeAtMs);
      }
    };

    _online.onPauseReceived = (position) {
      if (_activeEngine == RoomEngineMode.onlineCloud) {
        if (_state != null) {
          _state = _state!.copyWith(
            playbackPosition: position,
            isPlaying: false,
            lastUpdated: DateTime.now(),
          );
          notifyListeners();
        }
        onPauseReceived?.call(position);
      }
    };

    _online.onSeekReceived = (position, executeAtMs) {
      if (_activeEngine == RoomEngineMode.onlineCloud) {
        if (_state != null) {
          _state = _state!.copyWith(
            playbackPosition: position,
            lastUpdated: DateTime.now(),
          );
          notifyListeners();
        }
        onSeekReceived?.call(position, executeAtMs);
      }
    };

    _online.onMediaChanged = (mediaId, title, streamUrl, episodeId, headers) {
      if (_activeEngine == RoomEngineMode.onlineCloud) {
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
        onMediaChangedReceived?.call(mediaId, title, streamUrl);
        if (localActiveMediaId != mediaId) {
          onPartyPlayPrompt?.call(mediaId, title, streamUrl, episodeId, headers);
        }
      }
    };

    _online.onChatReceived = (chatMsg) {
      if (_activeEngine == RoomEngineMode.onlineCloud && _state != null) {
        final updatedChat = List<ChatMessage>.from(_state!.recentChat)..add(chatMsg);
        _state = _state!.copyWith(recentChat: updatedChat);
        notifyListeners();
      }
    };

    _online.onUserJoined = (participant) {
      if (_activeEngine == RoomEngineMode.onlineCloud && _state != null) {
        final updatedParts = List<Participant>.from(_state!.participants.where((p) => p.id != participant.id))
          ..add(participant);
        _state = _state!.copyWith(participants: updatedParts);
        notifyListeners();
      }
    };

    _online.onUserLeft = (leftId) {
      if (_activeEngine == RoomEngineMode.onlineCloud && _state != null) {
        final updatedParts = _state!.participants.where((p) => p.id != leftId).toList();
        _state = _state!.copyWith(participants: updatedParts);
        notifyListeners();
      }
    };

    // 2. Local LAN Mesh hooks (Direct Wi-Fi / LAN)
    _mesh.onRoomStateChanged = (roomState) {
      if (_activeEngine == RoomEngineMode.localLan) {
        _state = roomState;
        _currentRoomId = roomState.roomId;
        _isConnected = true;
        notifyListeners();
        onRoomStateReceived?.call(roomState);
      }
    };

    _mesh.onPlayReceived = (position, executeAtMs) {
      if (_activeEngine == RoomEngineMode.localLan) {
        if (_state != null) {
          _state = _state!.copyWith(
            playbackPosition: position,
            isPlaying: true,
            lastUpdated: DateTime.now(),
          );
          notifyListeners();
        }
        onPlayReceived?.call(position, executeAtMs);
      }
    };

    _mesh.onPauseReceived = (position) {
      if (_activeEngine == RoomEngineMode.localLan) {
        if (_state != null) {
          _state = _state!.copyWith(
            playbackPosition: position,
            isPlaying: false,
            lastUpdated: DateTime.now(),
          );
          notifyListeners();
        }
        onPauseReceived?.call(position);
      }
    };

    _mesh.onSeekReceived = (position, executeAtMs) {
      if (_activeEngine == RoomEngineMode.localLan) {
        if (_state != null) {
          _state = _state!.copyWith(
            playbackPosition: position,
            lastUpdated: DateTime.now(),
          );
          notifyListeners();
        }
        onSeekReceived?.call(position, executeAtMs);
      }
    };

    _mesh.onMediaChanged = (mediaId, title, streamUrl, episodeId, headers) {
      if (_activeEngine == RoomEngineMode.localLan) {
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
        onMediaChangedReceived?.call(mediaId, title, streamUrl);
        if (localActiveMediaId != mediaId) {
          onPartyPlayPrompt?.call(mediaId, title, streamUrl, episodeId, headers);
        }
      }
    };

    _mesh.onChatReceived = (chatMsg) {
      if (_activeEngine == RoomEngineMode.localLan && _state != null) {
        final updatedChat = List<ChatMessage>.from(_state!.recentChat)..add(chatMsg);
        _state = _state!.copyWith(recentChat: updatedChat);
        notifyListeners();
      }
    };

    _mesh.onUserJoined = (participant) {
      if (_activeEngine == RoomEngineMode.localLan && _state != null) {
        final updatedParts = List<Participant>.from(_state!.participants.where((p) => p.id != participant.id))
          ..add(participant);
        _state = _state!.copyWith(participants: updatedParts);
        notifyListeners();
      }
    };

    _mesh.onUserLeft = (leftId) {
      if (_activeEngine == RoomEngineMode.localLan && _state != null) {
        final updatedParts = _state!.participants.where((p) => p.id != leftId).toList();
        _state = _state!.copyWith(participants: updatedParts);
        notifyListeners();
      }
    };
  }

  void setHostIp(String ip) {
    _mesh.setCustomHostIp(ip);
    if (_activeEngine == RoomEngineMode.localLan && _mesh.activeRoomCode != null) {
      _currentRoomId = _mesh.activeRoomCode;
      notifyListeners();
    }
  }

  /// Start a Watch Party. By default hosts an Online Worldwide room (Supabase Realtime).
  /// If [forceLan] is true, hosts directly on the physical LAN adapter.
  Future<String?> startParty({
    String? username,
    String? userId,
    String title = "Watch Party",
    bool forceLan = false,
  }) async {
    final uname = username ?? _username ?? LocalStoreService().username;
    final uid = userId ?? _userId ?? LocalStoreService().peerId;
    _username = uname;
    _userId = uid;

    if (forceLan) {
      _activeEngine = RoomEngineMode.localLan;
      final code = await _mesh.hostDirectParty(
        hostUserId: uid,
        hostUsername: uname,
        title: title,
      );
      if (code != null) {
        _currentRoomId = code;
        _state = _mesh.state;
        _isConnected = true;
        notifyListeners();
      }
      return code;
    } else {
      _activeEngine = RoomEngineMode.onlineCloud;
      final code = await _online.hostRoom(
        userId: uid,
        username: uname,
        title: title,
      );
      if (code != null) {
        _currentRoomId = code;
        _state = _online.state;
        _isConnected = true;
        notifyListeners();
      }
      return code;
    }
  }

  /// Join a Watch Party.
  /// Automatically detects whether the input is a LAN IP / LAN code or a Worldwide Online code.
  Future<bool> joinParty(String code, {String? username, String? userId}) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    final uname = username ?? _username ?? LocalStoreService().username;
    final uid = userId ?? _userId ?? LocalStoreService().peerId;
    _username = uname;
    _userId = uid;

    // Detect if this is a LAN IP or explicit LAN address
    final isLan = cleanCode.contains('.') ||
        cleanCode.contains(':') ||
        cleanCode.startsWith('LAN-') ||
        (cleanCode.length == 7 && RegExp(r'^[0-9A-Z]{7}$').hasMatch(cleanCode) && P2PMeshService.decodeCodeToIp(cleanCode)?.contains('.') == true);

    if (isLan) {
      _activeEngine = RoomEngineMode.localLan;
      final success = await _mesh.joinParty(
        codeOrAddress: cleanCode,
        userId: uid,
        username: uname,
      );
      if (success) {
        _currentRoomId = cleanCode;
        _isConnected = true;
        _state = _mesh.state;
        notifyListeners();
        return true;
      }
      return false;
    } else {
      _activeEngine = RoomEngineMode.onlineCloud;
      final success = await _online.joinRoom(
        roomCode: cleanCode,
        userId: uid,
        username: uname,
      );
      if (success) {
        _currentRoomId = cleanCode;
        _isConnected = true;
        _state = _online.state;
        notifyListeners();
        return true;
      }
      return false;
    }
  }

  Future<void> connect({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    await joinParty(roomId, userId: userId, username: username);
  }

  void renameUser(String newName) {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    _username = clean;
    LocalStoreService().updateUsername(clean);
    final uid = _userId ?? LocalStoreService().peerId;

    if (_activeEngine == RoomEngineMode.onlineCloud) {
      _online.sendRename(clean, userId: uid);
    } else {
      _mesh.sendRename(clean, userId: uid);
    }

    if (_state != null) {
      final updatedParts = _state!.participants.map((p) {
        if (p.id == uid) {
          return Participant(id: p.id, username: clean, isHost: p.isHost);
        }
        return p;
      }).toList();
      _state = _state!.copyWith(participants: updatedParts);
      notifyListeners();
    }
  }

  void leaveParty() {
    disconnect();
  }

  void sendPlay(double position) {
    if (_state != null) {
      _state = _state!.copyWith(
        playbackPosition: position,
        isPlaying: true,
        lastUpdated: DateTime.now(),
      );
    }
    if (_activeEngine == RoomEngineMode.onlineCloud) {
      _online.sendPlay(position);
    } else {
      _mesh.sendPlay(position);
    }
  }

  void sendPause(double position) {
    if (_state != null) {
      _state = _state!.copyWith(
        playbackPosition: position,
        isPlaying: false,
        lastUpdated: DateTime.now(),
      );
    }
    if (_activeEngine == RoomEngineMode.onlineCloud) {
      _online.sendPause(position);
    } else {
      _mesh.sendPause(position);
    }
  }

  void sendSeek(double position) {
    if (_state != null) {
      _state = _state!.copyWith(
        playbackPosition: position,
        lastUpdated: DateTime.now(),
      );
    }
    if (_activeEngine == RoomEngineMode.onlineCloud) {
      _online.sendSeek(position);
    } else {
      _mesh.sendSeek(position);
    }
  }

  void sendChangeMedia(
    String mediaId,
    String title,
    String streamUrl,
    String episodeId, {
    Map<String, String>? headers,
  }) {
    if (_activeEngine == RoomEngineMode.onlineCloud) {
      _online.sendChangeMedia(mediaId, title, streamUrl, episodeId, headers: headers);
    } else {
      _mesh.sendChangeMedia(mediaId, title, streamUrl, episodeId, headers: headers);
    }
  }

  void sendChat(String message) {
    if (message.trim().isEmpty) return;
    final uid = _userId ?? LocalStoreService().peerId;
    final uname = _username ?? LocalStoreService().username;

    if (_activeEngine == RoomEngineMode.onlineCloud) {
      _online.sendChat(message, userId: uid, username: uname);
    } else {
      _mesh.sendChat(message, userId: uid, username: uname);
    }
  }

  void requestSync() {}

  void disconnect() {
    _online.disconnect();
    _mesh.disconnect();
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
