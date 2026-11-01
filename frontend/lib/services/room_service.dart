import 'package:flutter/foundation.dart';
import '../models/room_models.dart';
import 'local_store_service.dart';
import 'p2p_mesh_service.dart';

class RoomService extends ChangeNotifier {
  final P2PMeshService _mesh = P2PMeshService();

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
  bool get isHost => _mesh.isHost;
  double get currentPosition => _state?.currentPosition ?? 0.0;
  String? get hostIpAddress => _mesh.localIpAddress;

  RoomService() {
    _initMeshHooks();
  }

  void _initMeshHooks() {
    _mesh.onRoomStateChanged = (roomState) {
      _state = roomState;
      _currentRoomId = roomState.roomId;
      _isConnected = true;
      notifyListeners();
      onRoomStateReceived?.call(roomState);
    };

    _mesh.onPlayReceived = (position, executeAtMs) {
      if (_state != null) {
        _state = _state!.copyWith(
          playbackPosition: position,
          isPlaying: true,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
      }
      onPlayReceived?.call(position, executeAtMs);
    };

    _mesh.onPauseReceived = (position) {
      if (_state != null) {
        _state = _state!.copyWith(
          playbackPosition: position,
          isPlaying: false,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
      }
      onPauseReceived?.call(position);
    };

    _mesh.onSeekReceived = (position, executeAtMs) {
      if (_state != null) {
        _state = _state!.copyWith(
          playbackPosition: position,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
      }
      onSeekReceived?.call(position, executeAtMs);
    };

    _mesh.onMediaChanged = (mediaId, title, streamUrl, episodeId, headers) {
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
      if (localActiveMediaId != mediaId && onMediaChangedReceived == null) {
        onPartyPlayPrompt?.call(mediaId, title, streamUrl, episodeId, headers);
      }
    };

    _mesh.onChatReceived = (chatMsg) {
      if (_state != null) {
        final updatedChat = List<ChatMessage>.from(_state!.recentChat)..add(chatMsg);
        _state = _state!.copyWith(recentChat: updatedChat);
        notifyListeners();
      }
    };

    _mesh.onUserJoined = (participant) {
      if (_state != null) {
        final updatedParts = List<Participant>.from(_state!.participants.where((p) => p.id != participant.id))..add(participant);
        _state = _state!.copyWith(participants: updatedParts);
        notifyListeners();
      }
    };

    _mesh.onUserLeft = (leftId) {
      if (_state != null) {
        final updatedParts = _state!.participants.where((p) => p.id != leftId).toList();
        _state = _state!.copyWith(participants: updatedParts);
        notifyListeners();
      }
    };
  }

  Future<String?> startParty({String? username, String? userId, String title = "Watch Party"}) async {
    final uname = username ?? _username ?? LocalStoreService().username;
    final uid = userId ?? _userId ?? LocalStoreService().peerId;
    _username = uname;
    _userId = uid;

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
  }

  Future<bool> joinParty(String code, {String? username, String? userId}) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    final uname = username ?? _username ?? LocalStoreService().username;
    final uid = userId ?? _userId ?? LocalStoreService().peerId;
    _username = uname;
    _userId = uid;

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
  }

  Future<void> connect({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    await joinParty(roomId, userId: userId, username: username);
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
    _mesh.sendPlay(position);
  }

  void sendPause(double position) {
    if (_state != null) {
      _state = _state!.copyWith(
        playbackPosition: position,
        isPlaying: false,
        lastUpdated: DateTime.now(),
      );
    }
    _mesh.sendPause(position);
  }

  void sendSeek(double position) {
    if (_state != null) {
      _state = _state!.copyWith(
        playbackPosition: position,
        lastUpdated: DateTime.now(),
      );
    }
    _mesh.sendSeek(position);
  }

  void sendChangeMedia(String mediaId, String title, String streamUrl, String episodeId, {Map<String, String>? headers}) {
    _mesh.sendChangeMedia(mediaId, title, streamUrl, episodeId, headers: headers);
  }

  void sendChat(String message) {
    if (message.trim().isEmpty) return;
    final uid = _userId ?? LocalStoreService().peerId;
    final uname = _username ?? LocalStoreService().username;
    _mesh.sendChat(message, userId: uid, username: uname);
  }

  void requestSync() {
    // When peer connects, sync is sent automatically by host
  }

  void disconnect() {
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
