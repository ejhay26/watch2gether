import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../constants/theme.dart';
import '../../models/media_item.dart' hide SubtitleTrack;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../auth/auth_guard.dart';
import 'desktop_hud.dart';
import 'episodes_drawer.dart';
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
  late String _currentTitle;
  String? _currentSubtitle;
  String? _currentEpisodeId;
  String? _currentRoomCode;
  String _currentQuality = 'Auto';
  String _currentAudioTrack = 'Default';
  String _currentSubtitleTrack = 'Off';
  List<String> _availableAudioTracks = [];
  List<String> _availableSubtitles = ['Off'];
  StreamResult? _currentStreamResult;

  Timer? _hideControlsTimer;
  Timer? _historyTimer;
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  bool _wasMaximizedBeforeFullscreen = false;
  bool _isChatOpen = false;
  bool _isEpisodesOpen = false;
  bool _isBuffering = false;

  // Episodes & Recommended State
  List<Episode> _episodes = [];
  bool _loadingEpisodes = false;
  int _selectedSeason = 1;
  List<int> _availableSeasons = [1];
  List<MediaItem> _recommended = [];
  int _selectedRightTab = 0; // 0: Episodes (or Up Next), 1: Recommended, 2: Chat

  final FocusNode _keyboardFocusNode = FocusNode();

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  bool get _isSeries =>
      widget.mediaId.startsWith('anime-') ||
      widget.mediaId.contains('tv') ||
      widget.episodeId != null ||
      _episodes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _currentStreamUrl = widget.streamUrl;
    _currentTitle = widget.title;
    _currentSubtitle = widget.subtitle;
    _currentEpisodeId = widget.episodeId;
    _currentRoomCode = widget.initialRoomCode;
    _currentStreamResult = widget.streamResult;

    _player = Player();
    _controller = VideoController(_player);

    _openMedia(_currentStreamUrl, headers: widget.streamResult?.headers);

    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _player.stream.tracks.listen((tracks) {
      if (mounted) {
        final audioList = <String>[];
        for (int i = 0; i < tracks.audio.length; i++) {
          final a = tracks.audio[i];
          String lang = a.language ?? '';
          String title = a.title ?? '';
          if (title.isNotEmpty && title.toLowerCase() != 'track') {
            audioList.add('Track ${i + 1}: $title');
            continue;
          }
          String displayLang = lang.isNotEmpty ? lang.toUpperCase() : 'Audio';
          if (lang.toLowerCase() == 'en' || lang.toLowerCase() == 'eng') {
            displayLang = 'English';
          } else if (lang.toLowerCase() == 'es' || lang.toLowerCase() == 'spa') {
            displayLang = 'Spanish';
          } else if (lang.toLowerCase() == 'fr' || lang.toLowerCase() == 'fra') {
            displayLang = 'French';
          } else if (lang.toLowerCase() == 'de' || lang.toLowerCase() == 'deu') {
            displayLang = 'German';
          } else if (lang.toLowerCase() == 'ja' || lang.toLowerCase() == 'jpn') {
            displayLang = 'Japanese';
          }

          String ch = (a.channels != null && a.channels!.toString().isNotEmpty)
              ? ' [${a.channels}]'
              : '';
          audioList.add('Track ${i + 1}: $displayLang$ch');
        }

        final subList = <String>['Off'];
        for (int i = 0; i < tracks.subtitle.length; i++) {
          final s = tracks.subtitle[i];
          final lang = s.language ?? s.title ?? 'Subtitle ${i + 1}';
          subList.add(lang);
        }
        if (_currentStreamResult != null) {
          for (final extSub in _currentStreamResult!.subtitles) {
            if (extSub.lang.isNotEmpty && !subList.contains(extSub.lang)) {
              subList.add(extSub.lang);
            }
          }
        }

        setState(() {
          _availableAudioTracks = audioList;
          _availableSubtitles = subList;
        });
      }
    });

    if (_isDesktop) {
      windowManager.isFullScreen().then((f) {
        if (mounted) setState(() => _isFullscreen = f);
      });
    }

    _startHideControlsTimer();
    _initRoomAndSync();
    _startHistorySaving();
    _loadSeriesData();
    _loadRecommended();
  }

  void _openMedia(String url, {Map<String, String>? headers}) {
    _player.open(Media(url, httpHeaders: headers));
  }

  Future<void> _loadSeriesData() async {
    if (widget.mediaId.isEmpty) return;
    setState(() => _loadingEpisodes = true);
    try {
      final eps = await ApiService().getEpisodes(widget.mediaId, season: _selectedSeason);
      if (mounted) {
        setState(() {
          _episodes = eps;
          _loadingEpisodes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEpisodes = false);
    }
  }

  Future<void> _loadRecommended() async {
    try {
      final items = await ApiService().getTrending();
      if (mounted) {
        setState(() {
          _recommended = items.where((m) => m.id != widget.mediaId).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _selectEpisode(Episode ep) async {
    if (_currentEpisodeId == ep.id) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loading ${ep.title.isNotEmpty ? ep.title : "Episode ${ep.number}"}...'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );

    try {
      final servers = await ApiService().getServers(ep.id);
      if (servers.isEmpty) {
        throw Exception('No streaming servers available for this episode.');
      }

      final srv = servers.first;
      final streamRes = await ApiService().getSources(srv.id, title: ep.title);
      if (streamRes == null || streamRes.sources.isEmpty) {
        throw Exception('Episode stream could not be resolved.');
      }

      final src = streamRes.sources.first;
      if (mounted) {
        setState(() {
          _currentTitle = widget.title;
          _currentSubtitle = ep.title.isNotEmpty ? ep.title : 'Episode ${ep.number}';
          _currentEpisodeId = ep.id;
          _currentStreamUrl = src.url;
          _currentQuality = src.quality;
          _currentStreamResult = streamRes;
        });
        _openMedia(src.url, headers: streamRes.headers);
        _player.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play episode: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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

    _player.open(Media(source.url, httpHeaders: _currentStreamResult?.headers)).then((_) {
      _player.seek(currentPos);
      _player.play();
    });
  }

  void _switchAudioTrack(String trackLabel) {
    setState(() => _currentAudioTrack = trackLabel);
    final tracks = _player.state.tracks.audio;
    for (int i = 0; i < _availableAudioTracks.length; i++) {
      if (_availableAudioTracks[i] == trackLabel && i < tracks.length) {
        _player.setAudioTrack(tracks[i]);
        return;
      }
    }
  }

  void _switchSubtitle(String sub) {
    setState(() => _currentSubtitleTrack = sub);
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
      if (_currentStreamResult != null) {
        for (final s in _currentStreamResult!.subtitles) {
          if (s.lang.toLowerCase() == sub.toLowerCase() && s.url.isNotEmpty) {
            _player.setSubtitleTrack(SubtitleTrack.uri(s.url));
            return;
          }
        }
      }
    }
  }

  Future<void> _toggleFullscreen() async {
    if (_isDesktop) {
      final isFull = await windowManager.isFullScreen();
      if (!isFull) {
        final isMax = await windowManager.isMaximized();
        _wasMaximizedBeforeFullscreen = isMax;
        if (isMax) {
          await windowManager.unmaximize();
          await Future.delayed(const Duration(milliseconds: 50));
        }
        await windowManager.setFullScreen(true);
        await windowManager.focus();
        if (mounted) setState(() => _isFullscreen = true);
      } else {
        await windowManager.setFullScreen(false);
        await Future.delayed(const Duration(milliseconds: 50));
        if (_wasMaximizedBeforeFullscreen) {
          await windowManager.maximize();
          _wasMaximizedBeforeFullscreen = false;
        }
        if (mounted) setState(() => _isFullscreen = false);
      }
    } else {
      if (mounted) setState(() => _isFullscreen = !_isFullscreen);
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
          title: _currentTitle,
          streamUrl: _currentStreamUrl,
          episodeId: _currentEpisodeId ?? '',
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
    _historyTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) return;
      final posSec = _player.state.position.inSeconds;
      final durSec = _player.state.duration.inSeconds;
      if (posSec > 5 && durSec > 0) {
        ApiService().saveWatchHistory(
          mediaId: widget.mediaId,
          title: _currentTitle,
          episodeId: _currentEpisodeId ?? '',
          timestampSeconds: posSec,
          durationSeconds: durSec,
        );
      }
    });
  }

  void _onUserInteraction() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_player.state.playing) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _player.state.playing) {
          setState(() => _controlsVisible = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_player.state.playing) {
      _player.pause();
      final roomService = Provider.of<RoomService>(context, listen: false);
      if (roomService.isConnected) {
        roomService.sendPause(_player.state.position.inMilliseconds / 1000.0);
      }
    } else {
      _player.play();
      final roomService = Provider.of<RoomService>(context, listen: false);
      if (roomService.isConnected) {
        roomService.sendPlay(_player.state.position.inMilliseconds / 1000.0);
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
        _seek(_player.state.position - const Duration(seconds: 5)); // 5s seek
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seek(_player.state.position + const Duration(seconds: 5)); // 5s seek
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _player.setVolume((_player.state.volume + 10).clamp(0.0, 100.0));
        _onUserInteraction();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _player.setVolume((_player.state.volume - 10).clamp(0.0, 100.0));
        _onUserInteraction();
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        _toggleFullscreen();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isFullscreen) {
          _toggleFullscreen();
        }
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

  // --- UI Building Blocks ---

  Widget _buildVideoPlayerWithHUD(RoomService roomService, bool isRoomActive) {
    return MouseRegion(
      onHover: (_) => _onUserInteraction(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileGesturesOverlay(
            onTap: () {
              setState(() => _controlsVisible = !_controlsVisible);
              if (_controlsVisible) _startHideControlsTimer();
            },
            onDoubleTapLeft: () {
              _seek(_player.state.position - const Duration(seconds: 5)); // 5s seek
            },
            onDoubleTapRight: () {
              _seek(_player.state.position + const Duration(seconds: 5)); // 5s seek
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Video(
                    controller: _controller,
                    controls: NoVideoControls,
                    subtitleViewConfiguration: const SubtitleViewConfiguration(
                      style: TextStyle(
                        height: 1.4,
                        fontSize: 24.0,
                        letterSpacing: 0.2,
                        wordSpacing: 1.0,
                        color: Color(0xffffffff),
                        fontWeight: FontWeight.bold,
                        backgroundColor: Color(0xaa000000),
                      ),
                      textAlign: TextAlign.center,
                      padding: EdgeInsets.all(24.0),
                    ),
                  ),
                ),
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
                title: _currentTitle,
                subtitle: _currentSubtitle,
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
                hasEpisodes: _isSeries,
                isEpisodesOpen: _isEpisodesOpen,
                streamResult: _currentStreamResult,
                currentQuality: _currentQuality,
                currentAudioTrack: _currentAudioTrack,
                currentSubtitle: _currentSubtitleTrack,
                availableAudioTracks: _availableAudioTracks,
                availableSubtitles: _availableSubtitles,
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
                onToggleFullscreen: _toggleFullscreen,
                onToggleChat: () {
                  setState(() {
                    _isChatOpen = !_isChatOpen;
                    if (_isChatOpen) _isEpisodesOpen = false;
                  });
                },
                onToggleEpisodes: () {
                  setState(() {
                    _isEpisodesOpen = !_isEpisodesOpen;
                    if (_isEpisodesOpen) _isChatOpen = false;
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
    );
  }

  Widget _buildEpisodesDrawer() {
    return EpisodesDrawer(
      episodes: _episodes,
      currentEpisodeId: _currentEpisodeId,
      selectedSeason: _selectedSeason,
      availableSeasons: _availableSeasons,
      isLoading: _loadingEpisodes,
      onSelectSeason: (s) {
        setState(() => _selectedSeason = s);
        _loadSeriesData();
      },
      onSelectEpisode: _selectEpisode,
      onClose: () {
        setState(() => _isEpisodesOpen = false);
      },
    );
  }

  Widget _buildRecommendedItemCard(MediaItem item) {
    return InkWell(
      onTap: () async {
        try {
          final servers = await ApiService().getServers(item.id);
          if (servers.isNotEmpty) {
            final srv = servers.first;
            final streamRes = await ApiService().getSources(srv.id, title: item.title);
            if (streamRes != null && streamRes.sources.isNotEmpty) {
              setState(() {
                _currentTitle = item.title;
                _currentSubtitle = null;
                _currentEpisodeId = null;
                _currentStreamUrl = streamRes.sources.first.url;
                _currentStreamResult = streamRes;
              });
              _openMedia(streamRes.sources.first.url, headers: streamRes.headers);
              _player.play();
            }
          }
        } catch (_) {}
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 120,
                height: 68,
                color: AppColors.surfaceElevated,
                child: item.poster.isNotEmpty
                    ? Image.network(
                        item.poster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.movie_rounded, color: Colors.white24),
                      )
                    : const Icon(Icons.movie_rounded, color: Colors.white24),
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.year != null)
                        Text(
                          item.year!,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                      if (item.year != null) const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.quality ?? 'HD',
                          style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Layout: Fullscreen Mode ---
  Widget _buildFullscreenLayout(RoomService roomService, bool isRoomActive) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideoPlayerWithHUD(roomService, isRoomActive),

        // Sliding Room Chat Drawer
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            width: isRoomActive && _isChatOpen ? 340 : 0,
            child: OverflowBox(
              minWidth: 340,
              maxWidth: 340,
              alignment: Alignment.topRight,
              child: isRoomActive
                  ? RoomChatDrawer(
                      roomService: roomService,
                      onClose: () => setState(() => _isChatOpen = false),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),

        // Sliding Episodes Drawer
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            width: _isEpisodesOpen ? 340 : 0,
            child: OverflowBox(
              minWidth: 340,
              maxWidth: 340,
              alignment: Alignment.topRight,
              child: _buildEpisodesDrawer(),
            ),
          ),
        ),
      ],
    );
  }

  // --- Layout: YouTube-Style Windowed Desktop ---
  Widget _buildYouTubeDesktopLayout(RoomService roomService, bool isRoomActive) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Video Player + Title & Metadata
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 16:9 Video Player Container
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _buildVideoPlayerWithHUD(roomService, isRoomActive),
                  ),
                ),

                // Video Details Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentSubtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _currentSubtitle!,
                          style: TextStyle(
                            color: AppColors.accent.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '1080p Ultra HD',
                              style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_isSeries)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBorder,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Series / Anime',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                              ),
                            ),
                          const Spacer(),
                          // Watch Party Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceElevated,
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.accent, width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.group_add_rounded, size: 16),
                            label: const Text('Watch Party', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: _createRoomOnDemand,
                          ),
                        ],
                      ),

                      // Quick Season/Episodes Pills
                      if (_isSeries && _episodes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Episodes',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _episodes.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final ep = _episodes[i];
                              final isPlaying = ep.id == _currentEpisodeId || (_currentEpisodeId == null && i == 0);
                              return ActionChip(
                                label: Text(
                                  'EP ${ep.number}',
                                  style: TextStyle(
                                    color: isPlaying ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: isPlaying ? AppColors.accent : AppColors.surfaceElevated,
                                side: BorderSide(
                                  color: isPlaying ? AppColors.accent : AppColors.surfaceBorder,
                                ),
                                onPressed: () => _selectEpisode(ep),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Column: Side Panel (Episodes / Recommended / Chat)
        Container(
          width: 380,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(left: BorderSide(color: AppColors.surfaceBorder)),
          ),
          child: Column(
            children: [
              // Tab Header
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
                ),
                child: Row(
                  children: [
                    if (_isSeries)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedRightTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedRightTab == 0 ? AppColors.accent : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Episodes',
                                style: TextStyle(
                                  color: _selectedRightTab == 0 ? AppColors.accent : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedRightTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _selectedRightTab == 1 ? AppColors.accent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Up Next',
                              style: TextStyle(
                                color: _selectedRightTab == 1 ? AppColors.accent : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isRoomActive)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedRightTab = 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedRightTab == 2 ? AppColors.accent : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Chat',
                                style: TextStyle(
                                  color: _selectedRightTab == 2 ? AppColors.accent : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Tab Body
              Expanded(
                child: _selectedRightTab == 0 && _isSeries
                    ? _buildEpisodesDrawer()
                    : _selectedRightTab == 2 && isRoomActive
                        ? RoomChatDrawer(
                            roomService: roomService,
                            onClose: () => setState(() => _selectedRightTab = 1),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _recommended.length,
                            itemBuilder: (context, i) => _buildRecommendedItemCard(_recommended[i]),
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Layout: YouTube-Style Mobile / Narrow View ---
  Widget _buildYouTubeMobileLayout(RoomService roomService, bool isRoomActive) {
    return Column(
      children: [
        // Top 16:9 Video Player (Sticky)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: _buildVideoPlayerWithHUD(roomService, isRoomActive),
          ),
        ),

        // Scrollable Bottom Body
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentSubtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _currentSubtitle!,
                          style: const TextStyle(color: AppColors.accent, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),

                // Quick Episodes row if series
                if (_isSeries && _episodes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Episodes',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: AppColors.surface,
                              builder: (_) => _buildEpisodesDrawer(),
                            );
                          },
                          child: const Text('View All', style: TextStyle(color: AppColors.accent)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _episodes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final ep = _episodes[i];
                        final isPlaying = ep.id == _currentEpisodeId || (_currentEpisodeId == null && i == 0);
                        return ActionChip(
                          label: Text('EP ${ep.number}'),
                          backgroundColor: isPlaying ? AppColors.accent : AppColors.surfaceElevated,
                          labelStyle: TextStyle(
                            color: isPlaying ? Colors.black : Colors.white,
                            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          ),
                          onPressed: () => _selectEpisode(ep),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Up Next',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recommended.length,
                  itemBuilder: (context, i) => _buildRecommendedItemCard(_recommended[i]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
        body: _isFullscreen
            ? _buildFullscreenLayout(roomService, isRoomActive)
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 950) {
                    return _buildYouTubeDesktopLayout(roomService, isRoomActive);
                  }
                  return _buildYouTubeMobileLayout(roomService, isRoomActive);
                },
              ),
      ),
    );
  }
}
