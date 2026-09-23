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
import '../../services/playback_service.dart';
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
  final Player? existingPlayer;
  final VideoController? existingController;

  const PlayerScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.streamUrl,
    required this.mediaId,
    this.episodeId,
    this.initialRoomCode,
    this.streamResult,
    this.existingPlayer,
    this.existingController,
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
  List<Server> _availableServers = [];
  List<String> _availableSubtitles = ['Off'];
  StreamResult? _currentStreamResult;
  MediaItem? _details;
  bool _disposedForPiP = false;

  bool get _isAnime {
    if (widget.mediaId.startsWith('anime-')) return true;
    final genres = _details?.genres ?? [];
    if (genres.any((g) => g.toLowerCase().contains('anime'))) return true;
    final yr = _details?.year ?? '';
    return yr.toLowerCase().contains('anime');
  }

  Timer? _hideControlsTimer;
  Timer? _historyTimer;
  Timer? _syncCheckTimer;
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
  int _selectedRightTab = 0; // 0: Episodes/Up Next, 1: Recommended, 2: Chat

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  bool get _isSeries {
    if (widget.mediaId.contains('movie')) return false;
    return widget.mediaId.startsWith('anime-') || widget.mediaId.contains('tv');
  }

  @override
  void initState() {
    super.initState();
    _currentStreamUrl = widget.streamUrl;
    _currentTitle = widget.title;
    _currentSubtitle = widget.subtitle;
    _currentEpisodeId = widget.episodeId;
    _currentRoomCode = widget.initialRoomCode;
    _currentStreamResult = widget.streamResult;

    if (widget.existingPlayer != null && widget.existingController != null) {
      _player = widget.existingPlayer!;
      _controller = widget.existingController!;
    } else {
      _player = Player();
      _controller = VideoController(_player);
      _openMedia(_currentStreamUrl, headers: widget.streamResult?.headers);
    }

    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _player.stream.tracks.listen((tracks) {
      if (mounted) {
        _refreshAudioTracks();
      }
    });

    if (_isDesktop) {
      windowManager.isFullScreen().then((f) {
        if (mounted) setState(() => _isFullscreen = f);
      });
    }

    // Register global hardware key listener (independent of widget focus)
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);

    _startHideControlsTimer();
    _initRoomAndSync();
    _startHistorySaving();
    _loadSeriesData();
    _loadRecommended();
    _loadAvailableServers();
  }

  void _openMedia(String url, {Map<String, String>? headers}) {
    _player.open(Media(url, httpHeaders: headers));
  }

  Future<void> _loadAvailableServers() async {
    try {
      final epId = _currentEpisodeId ?? widget.episodeId ?? widget.mediaId;
      final srvs = await ApiService().getServers(epId, title: _currentTitle);
      if (mounted) {
        setState(() => _availableServers = srvs);
        _refreshAudioTracks();
      }
    } catch (_) {}
  }

  void _refreshAudioTracks() {
    final audioSet = <String>{};

    if (_isAnime) {
      bool hasSub = false;
      bool hasDub = false;
      for (final s in _availableServers) {
        if (s.name.toUpperCase().contains('[DUB]')) hasDub = true;
        if (s.name.toUpperCase().contains('[SUB]')) hasSub = true;
      }
      if (hasSub) audioSet.add('[SUB] Japanese Audio');
      if (hasDub) audioSet.add('[DUB] English Dub');
    } else {
      audioSet.add('Original Audio (English)');
    }

    // Native player audio streams
    final tracks = _player.state.tracks.audio;
    for (int i = 0; i < tracks.length; i++) {
      final a = tracks[i];
      String lang = a.language ?? '';
      String title = a.title ?? '';
      if (title.isNotEmpty && title.toLowerCase() != 'track') {
        audioSet.add(title);
        continue;
      }
      String displayLang = 'English';
      if (lang.toLowerCase() == 'en' || lang.toLowerCase() == 'eng') {
        displayLang = 'English';
      } else if (lang.toLowerCase() == 'ja' || lang.toLowerCase() == 'jpn') {
        displayLang = 'Japanese';
      } else if (lang.toLowerCase() == 'es' || lang.toLowerCase() == 'spa') {
        displayLang = 'Spanish';
      } else if (lang.toLowerCase() == 'fr' || lang.toLowerCase() == 'fra') {
        displayLang = 'French';
      } else if (lang.toLowerCase() == 'de' || lang.toLowerCase() == 'deu') {
        displayLang = 'German';
      }
      if (tracks.length > 1) {
        audioSet.add('$displayLang (Track ${i + 1})');
      } else {
        audioSet.add(displayLang);
      }
    }

    final audioList = audioSet.toList();
    if (audioList.isEmpty) {
      audioList.add('Default');
    }

    final subList = <String>['Off'];
    for (int i = 0; i < _player.state.tracks.subtitle.length; i++) {
      final s = _player.state.tracks.subtitle[i];
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
      if (_currentAudioTrack == 'Default' && audioList.isNotEmpty) {
        _currentAudioTrack = audioList.first;
      }
    });
  }

  Future<void> _loadSeriesData() async {
    if (widget.mediaId.isEmpty) return;
    setState(() => _loadingEpisodes = true);
    try {
      if (_details == null) {
        final d = await ApiService().getDetails(widget.mediaId);
        if (d != null && mounted) {
          setState(() {
            _details = d;
            if (d.seasons != null && d.seasons!.isNotEmpty) {
              _availableSeasons = d.seasons!;
            }
          });
          _refreshAudioTracks();
        }
      }
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
      final items = await ApiService().getRecommendations(widget.mediaId);
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
        _loadAvailableServers();
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

    // Handlers for incoming sync events
    roomService.onRoomStateReceived = (roomState) {
      if (!mounted) return;
      // Synchronize join playtime immediately using the live dynamic room position
      final currentPos = roomState.currentPosition;
      if (currentPos > 0) {
        final target = Duration(milliseconds: (currentPos * 1000).toInt());
        _player.seek(target);
      }
      if (roomState.isPlaying) {
        _player.play();
      } else {
        _player.pause();
      }
    };

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
        _loadAvailableServers();
      }
    };

    roomService.onPauseReceived = (position) {
      _player.seek(Duration(milliseconds: (position * 1000).toInt()));
      _player.pause();
    };

    roomService.onSeekReceived = (position, executeAtMs) {
      _player.seek(Duration(milliseconds: (position * 1000).toInt()));
    };

    roomService.onMediaChangedReceived = (mediaId, title, streamUrl) {
      if (!mounted) return;
      setState(() {
        _currentTitle = title;
        _currentStreamUrl = streamUrl;
      });
      _player.open(Media(streamUrl));
    };

    // Continuous Sync Drift Guard: Checks every 4 seconds to correct drift > 2.5s
    _syncCheckTimer?.cancel();
    _syncCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final rs = Provider.of<RoomService>(context, listen: false);
      if (!rs.isConnected || rs.state == null) return;
      final st = rs.state!;
      if (st.isPlaying) {
        final targetPos = st.currentPosition;
        final localPos = _player.state.position.inMilliseconds / 1000.0;
        final drift = (localPos - targetPos).abs();
        if (drift > 3.0) {
          _player.seek(Duration(milliseconds: (targetPos * 1000).toInt()));
        }
      }
    });
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

  Future<void> _switchAudioTrack(String trackLabel) async {
    setState(() => _currentAudioTrack = trackLabel);

    if (trackLabel.toUpperCase().contains('[DUB]') || trackLabel.toUpperCase().contains('[SUB]')) {
      final isDub = trackLabel.toUpperCase().contains('[DUB]');
      Server? targetSrv;
      for (final s in _availableServers) {
        if (isDub && s.name.toUpperCase().contains('[DUB]')) {
          targetSrv = s;
          break;
        } else if (!isDub && s.name.toUpperCase().contains('[SUB]')) {
          targetSrv = s;
          break;
        }
      }
      if (targetSrv != null) {
        final currentPos = _player.state.position;
        final res = await ApiService().getSources(targetSrv.id, title: _currentTitle);
        if (res != null && res.sources.isNotEmpty) {
          setState(() {
            _currentStreamUrl = res.sources.first.url;
            _currentStreamResult = res;
          });
          _openMedia(res.sources.first.url, headers: res.headers);
          await _player.seek(currentPos);
          _player.play();
          return;
        }
      }
    }

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
      final targetFullscreen = !_isFullscreen;
      setState(() => _isFullscreen = targetFullscreen);
      if (targetFullscreen) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    final roomService = Provider.of<RoomService>(context, listen: false);
    if (_player.state.playing) {
      _player.pause();
      if (roomService.isConnected) {
        roomService.sendPause(_player.state.position.inMilliseconds / 1000.0);
      }
    } else {
      _player.play();
      if (roomService.isConnected) {
        roomService.sendPlay(_player.state.position.inMilliseconds / 1000.0);
      }
    }
    setState(() {});
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

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // If an editable text field is currently focused (like typing in chat), let it handle the key
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      final w = primaryFocus.context!.widget;
      if (w is EditableText) {
        return false;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.keyF || event.logicalKey == LogicalKeyboardKey.f11) {
      _toggleFullscreen();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _toggleFullscreen();
        return true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
      _player.setVolume(_player.state.volume > 0 ? 0.0 : 100.0);
      _onUserInteraction();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seek(_player.state.position - const Duration(seconds: 5));
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seek(_player.state.position + const Duration(seconds: 5));
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _player.setVolume((_player.state.volume + 10).clamp(0.0, 100.0));
      _onUserInteraction();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _player.setVolume((_player.state.volume - 10).clamp(0.0, 100.0));
      _onUserInteraction();
      return true;
    }
    return false;
  }

  Future<void> _handleBack() async {
    final playbackService = Provider.of<PlaybackService>(context, listen: false);

    if (_isDesktop) {
      final isFull = await windowManager.isFullScreen();
      if (isFull) {
        await windowManager.setFullScreen(false);
        await Future.delayed(const Duration(milliseconds: 50));
        if (_wasMaximizedBeforeFullscreen) {
          await windowManager.maximize();
        }
      }
    }

    // Hand over active player to floating mini-player if playing
    if (_player.state.playing && mounted) {
      playbackService.startFloating(
        activePlayer: _player,
        activeController: _controller,
        activeMediaId: widget.mediaId,
        activeEpisodeId: _currentEpisodeId,
        activeTitle: _currentTitle,
        activeSubtitle: _currentSubtitle,
        activeStreamUrl: _currentStreamUrl,
        activeStreamResult: _currentStreamResult,
      );
      _disposedForPiP = true;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _historyTimer?.cancel();
    _syncCheckTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);

    if (!_disposedForPiP) {
      _player.dispose();
    }
    if (_isDesktop) {
      windowManager.isFullScreen().then((f) {
        if (f) {
          windowManager.setFullScreen(false);
          if (_wasMaximizedBeforeFullscreen) windowManager.maximize();
        }
      });
    } else {
      // Restore mobile orientations
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _openMobileChatSheet(RoomService roomService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13151F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: RoomChatDrawer(
            roomService: roomService,
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
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
              _seek(_player.state.position - const Duration(seconds: 5));
            },
            onDoubleTapRight: () {
              _seek(_player.state.position + const Duration(seconds: 5));
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

          // HUD Overlay with Reactive Play/Pause stream
          StreamBuilder<bool>(
            stream: _player.stream.playing,
            initialData: _player.state.playing,
            builder: (context, snapshotPlaying) {
              final isPlaying = snapshotPlaying.data ?? _player.state.playing;

              return StreamBuilder<Duration>(
                stream: _player.stream.position,
                builder: (context, snapshotPos) {
                  final position = snapshotPos.data ?? Duration.zero;
                  final duration = _player.state.duration;
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
                      final isMobile = MediaQuery.of(context).size.width < 700;
                      if (isMobile && !_isFullscreen) {
                        _openMobileChatSheet(roomService);
                      } else if (!_isFullscreen && _isDesktop) {
                        setState(() {
                          _selectedRightTab = (_selectedRightTab == 2 ? 1 : 2);
                        });
                      } else {
                        setState(() {
                          _isChatOpen = !_isChatOpen;
                          if (_isChatOpen) _isEpisodesOpen = false;
                        });
                      }
                    },
                    onToggleEpisodes: () {
                      setState(() {
                        _isEpisodesOpen = !_isEpisodesOpen;
                        if (_isEpisodesOpen) _isChatOpen = false;
                      });
                    },
                    onBack: _handleBack,
                    onCreateRoom: _createRoomOnDemand,
                    onSelectQuality: _switchSource,
                    onSelectAudioTrack: _switchAudioTrack,
                    onSelectSubtitle: _switchSubtitle,
                  );
                },
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
    final showChat = isRoomActive && _isChatOpen;
    final showEpisodes = _isEpisodesOpen;
    final hasSidebar = showChat || showEpisodes;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    if (isMobile) {
      // Mobile Overlay Drawer (does not squeeze 16:9 video or overflow)
      return Stack(
        children: [
          Positioned.fill(
            child: _buildVideoPlayerWithHUD(roomService, isRoomActive),
          ),
          if (hasSidebar)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 300,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF13151F).withOpacity(0.96),
                  border: const Border(left: BorderSide(color: AppColors.surfaceBorder)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: showEpisodes
                    ? _buildEpisodesDrawer()
                    : RoomChatDrawer(
                        roomService: roomService,
                        onClose: () => setState(() => _isChatOpen = false),
                      ),
              ),
            ),
        ],
      );
    }

    // Desktop Two-Pane Side-by-Side in Fullscreen
    return Row(
      children: [
        Expanded(
          child: _buildVideoPlayerWithHUD(roomService, isRoomActive),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          width: hasSidebar ? 360 : 0,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(left: BorderSide(color: AppColors.surfaceBorder)),
          ),
          child: ClipRect(
            child: OverflowBox(
              minWidth: 360,
              maxWidth: 360,
              alignment: Alignment.topRight,
              child: hasSidebar
                  ? (showEpisodes
                      ? _buildEpisodesDrawer()
                      : RoomChatDrawer(
                          roomService: roomService,
                          onClose: () => setState(() => _isChatOpen = false),
                        ))
                  : const SizedBox.shrink(),
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
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _buildVideoPlayerWithHUD(roomService, isRoomActive),
                  ),
                ),
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
                          const Spacer(),
                          if (!isRoomActive)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent.withOpacity(0.15),
                                foregroundColor: AppColors.accent,
                                elevation: 0,
                                side: const BorderSide(color: AppColors.accent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.group_add_rounded, size: 18),
                              label: const Text('Watch Party'),
                              onPressed: _createRoomOnDemand,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // TV Series Seasons & Episodes Grid
                if (_isSeries) ...[
                  const Divider(color: Colors.white10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        const Text(
                          'Seasons & Episodes',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedSeason,
                              dropdownColor: AppColors.surfaceElevated,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              items: _availableSeasons.map((s) {
                                return DropdownMenuItem<int>(
                                  value: s,
                                  child: Text('Season $s'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && val != _selectedSeason) {
                                  setState(() => _selectedSeason = val);
                                  _loadSeriesData();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _loadingEpisodes
                        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.accent)))
                        : _episodes.isEmpty
                            ? const Padding(padding: EdgeInsets.all(16), child: Text('No episodes found.', style: TextStyle(color: AppColors.textSecondary)))
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  childAspectRatio: 1.4,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _episodes.length,
                                itemBuilder: (ctx, idx) {
                                  final ep = _episodes[idx];
                                  final isPlaying = ep.id == _currentEpisodeId || (_currentEpisodeId == null && idx == 0);
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _selectEpisode(ep),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isPlaying ? AppColors.accent : AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isPlaying ? AppColors.accent : Colors.white12,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'EP ${ep.number}',
                                        style: TextStyle(
                                          color: isPlaying ? Colors.black : Colors.white,
                                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),

        // Right Sidebar: Tabs for Recommended & Chat
        Container(
          width: 360,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(left: BorderSide(color: AppColors.surfaceBorder)),
          ),
          child: Column(
            children: [
              Container(
                height: 48,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedRightTab = 1),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _selectedRightTab == 1 ? AppColors.accent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Recommended',
                            style: TextStyle(
                              color: _selectedRightTab == 1 ? AppColors.accent : Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
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
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedRightTab == 2 ? AppColors.accent : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
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
                  ],
                ),
              ),

              // Sidebar Body
              Expanded(
                child: _selectedRightTab == 2 && isRoomActive
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
    return SafeArea(
      bottom: false,
      child: Column(
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

                // Live Chat Bar on Mobile if Room is Active
                if (isRoomActive)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openMobileChatSheet(roomService),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Watch Party Chat (${roomService.state?.recentChat.length ?? 0})',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            const Text('Open', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Quick Episodes row if series
                if (_isSeries && _episodes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    'Recommended',
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
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomService = Provider.of<RoomService>(context);
    final isRoomActive = roomService.isConnected || (_currentRoomCode != null && _currentRoomCode!.isNotEmpty);

    return Scaffold(
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
    );
  }
}
