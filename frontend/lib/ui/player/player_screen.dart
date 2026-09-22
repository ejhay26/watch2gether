import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../constants/theme.dart';
import '../../models/media_item.dart' hide SubtitleTrack;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../auth/auth_guard.dart';
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
  final StreamResult? streamResult;

  const PlayerScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.streamUrl,
    required this.mediaId,
    this.episodeId,
    this.initialRoomCode,
    this.streamResult,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  late String _currentStreamUrl;
  String? _currentRoomCode;
  String _currentQuality = 'Auto';
  String _currentAudioTrack = 'Default';
  String _currentSubtitle = 'Off';
  List<String> _availableAudioTracks = [];

  Timer? _hideControlsTimer;
  Timer? _historyTimer;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  bool _isChatOpen = false;
  bool _isBuffering = false;

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentStreamUrl = widget.streamUrl;
    _currentRoomCode = widget.initialRoomCode;

    _player = Player();
    _controller = VideoController(_player);

    _openMedia(_currentStreamUrl);

    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _player.stream.tracks.listen((tracks) {
      if (mounted) {
        setState(() {
          _availableAudioTracks = tracks.audio.map((a) => a.language ?? a.title ?? 'Track').toList();
        });
      }
    });

    _startHideControlsTimer();
    _initRoomAndSync();
    _startHistorySaving();
  }

  void _openMedia(String url) {
    _player.open(Media(url));
  }

  void _initRoomAndSync() {
    final roomService = Provider.of<RoomService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_currentRoomCode != null && _currentRoomCode!.isNotEmpty) {
      roomService.connect(
        roomId: _currentRoomCode!,
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

  void _switchSource(StreamSource source) {
    final currentPos = _player.state.position;
    setState(() {
      _currentQuality = source.quality;
      _currentStreamUrl = source.url;
    });

    _player.open(Media(source.url)).then((_) {
      _player.seek(currentPos);
      _player.play();
    });
  }

  void _switchAudioTrack(String trackName) {
    setState(() => _currentAudioTrack = trackName);
    final tracks = _player.state.tracks.audio;
    for (final t in tracks) {
      if ((t.language != null && t.language!.toLowerCase() == trackName.toLowerCase()) ||
          (t.title != null && t.title!.toLowerCase().contains(trackName.toLowerCase()))) {
        _player.setAudioTrack(t);
        return;
      }
    }
  }

  void _switchSubtitle(String sub) {
    setState(() => _currentSubtitle = sub);
    if (sub == 'Off') {
      _player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      final tracks = _player.state.tracks.subtitle;
      for (final t in tracks) {
        if ((t.language != null && t.language!.toLowerCase() == sub.toLowerCase()) ||
            (t.title != null && t.title!.toLowerCase().contains(sub.toLowerCase()))) {
          _player.setSubtitleTrack(t);
          return;
        }
      }
      if (widget.streamResult != null) {
        for (final s in widget.streamResult!.subtitles) {
          if (s.lang.toLowerCase() == sub.toLowerCase()) {
            _player.setSubtitleTrack(SubtitleTrack.uri(s.url));
            return;
          }
        }
      }
    }
  }

  Future<void> _createRoomOnDemand() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    AuthGuard.runGuarded(
      context,
      message: 'Sign in to create a watch party and invite friends.',
      onAuthorized: () async {
        final roomCode = await ApiService().createRoom(
          mediaId: widget.mediaId,
          title: widget.title,
          streamUrl: _currentStreamUrl,
          episodeId: widget.episodeId ?? '',
        );

        if (roomCode != null && mounted) {
          setState(() {
            _currentRoomCode = roomCode;
            _isChatOpen = true;
          });
          final roomService = Provider.of<RoomService>(context, listen: false);
          roomService.connect(
            roomId: roomCode,
            userId: auth.userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
            username: auth.username ?? 'Host',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Watch Room created! Code: $roomCode')),
          );
        }
      },
    );
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
    final isRoomActive = roomService.isConnected || (_currentRoomCode != null && _currentRoomCode!.isNotEmpty);

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
              // Row holding Video player + smoothly animated side-docked chat panel
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
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: Video(
                              controller: _controller,
                              controls: NoVideoControls,
                            ),
                          ),

                          // Buffering Indicator
                          if (_isBuffering)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const CircularProgressIndicator(
                                color: AppColors.accent,
                                strokeWidth: 3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Animated sliding Room Chat Drawer
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isRoomActive && _isChatOpen ? 340 : 0,
                    child: OverflowBox(
                      minWidth: 340,
                      maxWidth: 340,
                      alignment: Alignment.topRight,
                      child: isRoomActive
                          ? RoomChatDrawer(
                              roomService: roomService,
                              onClose: () {
                                setState(() {
                                  _isChatOpen = false;
                                });
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
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
                    isRoom: isRoomActive,
                    roomCode: _currentRoomCode ?? roomService.currentRoomId,
                    participantCount: roomService.state?.participants.length ?? 1,
                    isChatOpen: _isChatOpen,
                    streamResult: widget.streamResult,
                    currentQuality: _currentQuality,
                    currentAudioTrack: _currentAudioTrack,
                    currentSubtitle: _currentSubtitle,
                    availableAudioTracks: _availableAudioTracks,
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
                    onCreateRoom: _createRoomOnDemand,
                    onSelectQuality: _switchSource,
                    onSelectAudioTrack: _switchAudioTrack,
                    onSelectSubtitle: _switchSubtitle,
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
