import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import 'desktop_hud.dart';
import 'mobile_gestures.dart';
import 'room_chat_drawer.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String streamUrl;
  final String mediaId;
  final String? episodeId;
  final String? initialRoomCode;

  const PlayerScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.streamUrl,
    required this.mediaId,
    this.episodeId,
    this.initialRoomCode,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  Timer? _hideControlsTimer;
  Timer? _historyTimer;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  bool _isChatOpen = false;

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _player = Player();
    _controller = VideoController(_player);

    _player.open(Media(widget.streamUrl));

    _startHideControlsTimer();
    _initRoomAndSync();
    _startHistorySaving();
  }

  void _initRoomAndSync() {
    final roomService = Provider.of<RoomService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (widget.initialRoomCode != null && widget.initialRoomCode!.isNotEmpty) {
      roomService.connect(
        roomId: widget.initialRoomCode!,
        userId: authService.userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
        username: authService.username ?? 'Viewer',
      );
      _isChatOpen = true;
    }

    roomService.onPlayReceived = (position, executeAtMs) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final delay = executeAtMs - now;
      if (delay > 0) {
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted) {
            _player.seek(Duration(milliseconds: (position * 1000).toInt()));
            _player.play();
          }
        });
      } else {
        _player.seek(Duration(milliseconds: (position * 1000).toInt()));
        _player.play();
      }
    };

    roomService.onPauseReceived = (position) {
      _player.seek(Duration(milliseconds: (position * 1000).toInt()));
      _player.pause();
    };

    roomService.onSeekReceived = (position, executeAtMs) {
      _player.seek(Duration(milliseconds: (position * 1000).toInt()));
    };
  }

  void _startHistorySaving() {
    _historyTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final pos = _player.state.position.inSeconds;
      final dur = _player.state.duration.inSeconds;
      if (dur > 0 && pos > 0) {
        ApiService().saveWatchHistory(
          mediaId: widget.mediaId,
          title: widget.title,
          episodeId: widget.episodeId ?? '',
          timestampSeconds: pos,
          durationSeconds: dur,
        );
      }
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _player.state.playing) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _onUserInteraction() {
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
    _startHideControlsTimer();
  }

  void _togglePlayPause() {
    final roomService = Provider.of<RoomService>(context, listen: false);
    final nextPlaying = !_player.state.playing;

    if (nextPlaying) {
      _player.play();
      if (roomService.isConnected) {
        roomService.sendPlay(_player.state.position.inMilliseconds / 1000.0);
      }
    } else {
      _player.pause();
      if (roomService.isConnected) {
        roomService.sendPause(_player.state.position.inMilliseconds / 1000.0);
      }
    }
    _onUserInteraction();
  }

  void _seek(Duration target) {
    _player.seek(target);
    final roomService = Provider.of<RoomService>(context, listen: false);
    if (roomService.isConnected) {
      roomService.sendSeek(target.inMilliseconds / 1000.0);
    }
    _onUserInteraction();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seek(_player.state.position - const Duration(seconds: 10));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seek(_player.state.position + const Duration(seconds: 10));
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _player.setVolume((_player.state.volume + 10).clamp(0.0, 100.0));
        _onUserInteraction();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _player.setVolume((_player.state.volume - 10).clamp(0.0, 100.0));
        _onUserInteraction();
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        setState(() {
          _isFullscreen = !_isFullscreen;
        });
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        _player.setVolume(_player.state.volume > 0 ? 0.0 : 100.0);
        _onUserInteraction();
      }
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _historyTimer?.cancel();
    _keyboardFocusNode.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomService = Provider.of<RoomService>(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) => _onUserInteraction(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Row holding Video player + optional side-docked chat panel
              Row(
                children: [
                  Expanded(
                    child: MobileGesturesOverlay(
                      onTap: () {
                        setState(() {
                          _controlsVisible = !_controlsVisible;
                        });
                        if (_controlsVisible) _startHideControlsTimer();
                      },
                      onDoubleTapLeft: () {
                        _seek(_player.state.position - const Duration(seconds: 10));
                      },
                      onDoubleTapRight: () {
                        _seek(_player.state.position + const Duration(seconds: 10));
                      },
                      child: Center(
                        child: Video(
                          controller: _controller,
                          controls: NoVideoControls,
                        ),
                      ),
                    ),
                  ),

                  if (roomService.isConnected && _isChatOpen)
                    RoomChatDrawer(
                      roomService: roomService,
                      onClose: () {
                        setState(() {
                          _isChatOpen = false;
                        });
                      },
                    ),
                ],
              ),

              // HUD Overlay
              StreamBuilder<Duration>(
                stream: _player.stream.position,
                builder: (context, snapshotPos) {
                  final position = snapshotPos.data ?? Duration.zero;
                  final duration = _player.state.duration;
                  final isPlaying = _player.state.playing;
                  final volume = _player.state.volume / 100.0;

                  return DesktopHUD(
                    isVisible: _controlsVisible,
                    title: widget.title,
                    subtitle: widget.subtitle,
                    isPlaying: isPlaying,
                    position: position,
                    duration: duration,
                    volume: volume,
                    isMuted: volume == 0.0,
                    isFullscreen: _isFullscreen,
                    isRoom: roomService.isConnected,
                    roomCode: roomService.currentRoomId,
                    participantCount: roomService.state?.participants.length ?? 1,
                    isChatOpen: _isChatOpen,
                    onPlayPause: _togglePlayPause,
                    onSeek: _seek,
                    onVolumeChange: (val) {
                      _player.setVolume(val * 100.0);
                      _onUserInteraction();
                    },
                    onToggleMute: () {
                      _player.setVolume(volume > 0 ? 0.0 : 100.0);
                      _onUserInteraction();
                    },
                    onToggleFullscreen: () {
                      setState(() {
                        _isFullscreen = !_isFullscreen;
                      });
                    },
                    onToggleChat: () {
                      setState(() {
                        _isChatOpen = !_isChatOpen;
                      });
                    },
                    onBack: () => Navigator.of(context).pop(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

