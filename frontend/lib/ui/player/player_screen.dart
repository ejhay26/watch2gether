import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../constants/theme.dart';
import '../../models/media_item.dart' hide SubtitleTrack;
import '../../models/media_item.dart' as models show SubtitleTrack;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_store_service.dart';
import '../../services/room_service.dart';
import '../../services/playback_service.dart';
import '../../services/settings_service.dart';
import '../auth/auth_guard.dart';
import 'desktop_hud.dart';
import 'episodes_drawer.dart';
import 'mobile_gestures.dart';
import 'player_settings_modal.dart';
import 'room_chat_drawer.dart';
import '../components/app_toast.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String streamUrl;
  final String mediaId;
  final String? poster;
  final String? episodeId;
  final String? initialRoomCode;
  final StreamResult? streamResult;
  final Player? existingPlayer;
  final VideoController? existingController;
  final bool isPartySynced;
  final String? initialAudioTrack;

  const PlayerScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.streamUrl,
    required this.mediaId,
    this.poster,
    this.episodeId,
    this.initialRoomCode,
    this.streamResult,
    this.existingPlayer,
    this.existingController,
    this.isPartySynced = true,
    this.initialAudioTrack,
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
  bool _isPlayerSettingsOpen = false;
  PlayerSettingsTab _playerSettingsTab = PlayerSettingsTab.subs;
  final Map<String, ServerStateStatus> _serverStatuses = {};
  final Set<String> _favoriteServers = {};
  Server? _currentServer;
  final Map<String, AudioTrack> _nativeAudioTrackMap = {};
  final Map<String, Server> _serverAudioTrackMap = {};
  final Map<String, SubtitleTrack> _nativeSubtitleTrackMap = {};
  final Map<String, String> _externalSubtitleUrlMap = {};
  Offset? _lastPointerPosition;
  StreamResult? _currentStreamResult;
  MediaItem? _details;
  bool _disposedForPiP = false;
  bool _isPartySynced = true;

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
  Timer? _bufferingWatchdog;
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
    _isPartySynced = widget.isPartySynced;
    if (widget.initialAudioTrack != null && widget.initialAudioTrack!.isNotEmpty) {
      _currentAudioTrack = widget.initialAudioTrack!;
    }

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
      if (buffering) {
        _bufferingWatchdog?.cancel();
        _bufferingWatchdog = Timer(const Duration(seconds: 35), () {
          if (mounted && _isBuffering && _player.state.position == Duration.zero) {
            // Player has been stuck buffering for 35 seconds without playback progress
            if (_currentServer != null) {
              setState(() {
                _serverStatuses[_currentServer!.id] = ServerStateStatus.failed;
              });
              AppToast.show(
                context,
                'Stream stalled on ${_currentServer!.name}. Auto-fetching next server...',
                type: ToastType.warning,
              );
              _autoFetchNextSource(_currentServer!);
            }
          }
        });
      } else {
        _bufferingWatchdog?.cancel();
      }
    });

    _player.stream.position.listen((pos) {
      if (pos > Duration.zero) {
        _bufferingWatchdog?.cancel();
      }
    });

    _player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        if (_currentServer != null) {
          setState(() {
            _serverStatuses[_currentServer!.id] = ServerStateStatus.failed;
          });
          AppToast.show(
            context,
            'Playback error on ${_currentServer!.name}. Switching server...',
            type: ToastType.warning,
          );
          _autoFetchNextSource(_currentServer!);
        }
      }
    });

    _player.stream.playing.listen((playing) {
      if (mounted) {
        if (playing) {
          if (_controlsVisible) {
            _startHideControlsTimer();
          }
        } else {
          _hideControlsTimer?.cancel();
        }
      }
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

    final playback = Provider.of<PlaybackService>(context, listen: false);
    if (playback.isFloating && playback.player != null) {
      if (playback.streamUrl != widget.streamUrl) {
        playback.stopFloating();
      }
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

  bool _isPlayableMediaUrl(String url) {
    if (url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();
    if (clean.contains('.m3u8') || clean.contains('.mp4') || clean.contains('/hls/')) {
      return true;
    }
    if (clean.endsWith('.html') || clean.endsWith('.htm') || clean.contains('/embed/') || clean.contains('player.php') || clean.contains('iframe')) {
      return false;
    }
    return true;
  }

  void _openMedia(String url, {Map<String, String>? headers}) {
    if (!_isPlayableMediaUrl(url)) {
      if (mounted) {
        AppToast.show(
          context,
          'Direct video stream is unavailable for this mirror. Please select another source.',
          type: ToastType.warning,
        );
      }
      return;
    }
    _bufferingWatchdog?.cancel();
    _player.stop();
    _player.open(Media(url, httpHeaders: headers));

    final roomService = Provider.of<RoomService>(context, listen: false);
    if (roomService.isInParty && roomService.isHost) {
      roomService.sendChangeMedia(
        widget.mediaId,
        _currentTitle,
        url,
        _currentEpisodeId ?? widget.episodeId ?? '',
        headers: headers,
      );
    }
  }

  Future<void> _loadAvailableServers() async {
    try {
      final epId = _currentEpisodeId ?? widget.episodeId ?? widget.mediaId;
      final srvs = await ApiService().getServers(epId, title: _currentTitle);
      if (mounted) {
        setState(() {
          _availableServers = srvs;
          if (_currentServer == null && srvs.isNotEmpty) {
            _currentServer = srvs.first;
            _serverStatuses[srvs.first.id] = ServerStateStatus.active;
          }
        });
        _refreshAudioTracks();
      }
    } catch (_) {}
  }

  void _openPlayerSettings(PlayerSettingsTab tab) {
    setState(() {
      _playerSettingsTab = tab;
      _isPlayerSettingsOpen = true;
      _isChatOpen = false;
      _isEpisodesOpen = false;
    });
  }

  Future<void> _loadServerAndStream(Server srv, {bool isAutoFailover = false}) async {
    _bufferingWatchdog?.cancel();
    setState(() {
      _currentServer = srv;
      _serverStatuses[srv.id] = ServerStateStatus.loading;
    });

    try {
      final res = await ApiService().getSources(srv.id, title: _currentTitle);
      if (res == null || res.sources.isEmpty) {
        throw Exception('Server returned no valid stream sources');
      }

      final src = res.sources.first;
      final currentPos = _player.state.position;

      if (mounted) {
        setState(() {
          _serverStatuses[srv.id] = ServerStateStatus.active;
          _currentStreamUrl = src.url;
          _currentQuality = src.quality;
          _currentStreamResult = res;
        });

        _openMedia(src.url, headers: res.headers);
        if (currentPos > Duration.zero) {
          await _player.seek(currentPos);
        }
        await _player.play();
        _refreshAudioTracks();

        _autoSelectLanguageAudio(srv);

        AppToast.show(
          context,
          'Connected to ${srv.name} (${srv.audio ?? srv.flag ?? "Stream Active"})',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverStatuses[srv.id] = ServerStateStatus.failed;
        });
        _autoFetchNextSource(srv);
      }
    }
  }

  void _autoFetchNextSource(Server failedServer) {
    final idx = _availableServers.indexWhere((s) => s.id == failedServer.id);
    if (idx != -1 && idx + 1 < _availableServers.length) {
      final nextServer = _availableServers[idx + 1];
      AppToast.show(
        context,
        '${failedServer.name} unavailable. Auto-switching to ${nextServer.name}...',
        type: ToastType.warning,
        duration: const Duration(seconds: 3),
      );
      _loadServerAndStream(nextServer, isAutoFailover: true);
    } else {
      AppToast.show(
        context,
        'All stream sources exhausted for this media item.',
        type: ToastType.error,
      );
    }
  }

  void _autoSelectLanguageAudio(Server srv) {
    final nameLower = srv.name.toLowerCase();
    final audioLower = (srv.audio ?? '').toLowerCase();

    String? targetLang;
    if (nameLower.contains('killjoy') || audioLower.contains('german')) {
      targetLang = 'de';
    } else if (nameLower.contains('fade') || audioLower.contains('hindi')) {
      targetLang = 'hi';
    } else if (nameLower.contains('omen') || audioLower.contains('spanish')) {
      targetLang = 'es';
    } else if (nameLower.contains('raze') || audioLower.contains('portuguese')) {
      targetLang = 'pt';
    } else if (nameLower.contains('chamber') || audioLower.contains('french')) {
      targetLang = 'fr';
    } else if (nameLower.contains('jett') || audioLower.contains('japanese')) {
      targetLang = 'ja';
    }

    if (targetLang != null) {
      final tracks = _player.state.tracks.audio;
      for (final t in tracks) {
        final lang = (t.language ?? '').toLowerCase();
        final title = (t.title ?? '').toLowerCase();
        if (lang.contains(targetLang) || title.contains(targetLang)) {
          _player.setAudioTrack(t);
          break;
        }
      }
    }
  }

  Future<void> _applyUploadedSubtitle(String fileName, String content) async {
    try {
      String formattedContent = content;
      if (!formattedContent.trimLeft().startsWith('WEBVTT')) {
        final reSRT = RegExp(r'(\d{2}:\d{2}:\d{2}),(\d{3})');
        formattedContent = 'WEBVTT\n\n${formattedContent.replaceAllMapped(reSRT, (m) => '${m[1]}.${m[2]}')}';
      }
      await _player.setSubtitleTrack(SubtitleTrack.data(formattedContent, title: fileName, language: 'Custom'));
      if (mounted) {
        setState(() {
          _currentSubtitleTrack = fileName;
          if (!_availableSubtitles.contains(fileName)) {
            _availableSubtitles.add(fileName);
          }
        });
        AppToast.show(context, 'Subtitle applied: $fileName', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to apply uploaded subtitle', type: ToastType.error);
      }
    }
  }

  Future<void> _selectOnlineSubtitle(models.SubtitleTrack item) async {
    String label = item.lang.trim();
    if (label.isEmpty) label = 'External Subtitle';
    if (_availableSubtitles.contains(label) && !_externalSubtitleUrlMap.containsKey(label)) {
      label = '$label (Online)';
    }

    String fetchUrl = item.url.trim();
    if (fetchUrl.startsWith('/')) {
      final base = ApiService().baseUrl;
      fetchUrl = '$base$fetchUrl';
    }

    try {
      final dio = Dio();
      final resp = await dio.get<String>(
        fetchUrl,
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (resp.data != null && resp.data!.trim().isNotEmpty) {
        String content = resp.data!;
        if (!content.trimLeft().startsWith('WEBVTT')) {
          final reSRT = RegExp(r'(\d{2}:\d{2}:\d{2}),(\d{3})');
          content = 'WEBVTT\n\n${content.replaceAllMapped(reSRT, (m) => '${m[1]}.${m[2]}')}';
        }

        await _player.setSubtitleTrack(SubtitleTrack.data(content, title: label, language: label));
        if (mounted) {
          setState(() {
            _currentSubtitleTrack = label;
            _externalSubtitleUrlMap[label] = item.url.trim();
            if (!_availableSubtitles.contains(label)) {
              _availableSubtitles.add(label);
            }
          });
          AppToast.show(context, 'Subtitles loaded: $label', type: ToastType.success);
        }
        return;
      }
    } catch (e) {
      // Fallback: direct URI in media_kit
      try {
        await _player.setSubtitleTrack(SubtitleTrack.uri(fetchUrl, title: label, language: label));
        if (mounted) {
          setState(() {
            _currentSubtitleTrack = label;
            _externalSubtitleUrlMap[label] = item.url.trim();
            if (!_availableSubtitles.contains(label)) {
              _availableSubtitles.add(label);
            }
          });
          AppToast.show(context, 'Subtitles loaded: $label', type: ToastType.info);
        }
        return;
      } catch (err) {
        if (mounted) {
          AppToast.show(context, 'Failed to download subtitle: $err', type: ToastType.error);
        }
        rethrow;
      }
    }
  }

  String _formatAudioTrackName(AudioTrack track, int index, int total) {
    final title = track.title?.trim() ?? '';
    final lang = track.language?.trim().toLowerCase() ?? '';

    if (title.isNotEmpty && !title.toLowerCase().startsWith('track')) {
      return total > 1 ? '$title (Track ${index + 1})' : title;
    }

    String langName = 'Track ${index + 1}';
    if (lang == 'en' || lang == 'eng') {
      langName = 'English';
    } else if (lang == 'zh' || lang == 'zho' || lang == 'chi' || lang == 'yue') {
      langName = 'Chinese / Cantonese';
    } else if (lang == 'ja' || lang == 'jpn') {
      langName = 'Japanese';
    } else if (lang == 'ko' || lang == 'kor') {
      langName = 'Korean';
    } else if (lang == 'es' || lang == 'spa') {
      langName = 'Spanish';
    } else if (lang == 'fr' || lang == 'fra' || lang == 'fre') {
      langName = 'French';
    } else if (lang == 'de' || lang == 'deu' || lang == 'ger') {
      langName = 'German';
    } else if (lang == 'it' || lang == 'ita') {
      langName = 'Italian';
    } else if (lang == 'pt' || lang == 'por') {
      langName = 'Portuguese';
    } else if (lang == 'ru' || lang == 'rus') {
      langName = 'Russian';
    } else if (lang == 'hi' || lang == 'hin') {
      langName = 'Hindi';
    } else if (lang.isNotEmpty) {
      langName = lang.toUpperCase();
    }

    return total > 1 ? '$langName (Track ${index + 1})' : langName;
  }

  void _refreshAudioTracks() {
    _nativeAudioTrackMap.clear();
    _serverAudioTrackMap.clear();
    _nativeSubtitleTrackMap.clear();
    _externalSubtitleUrlMap.clear();

    final audioList = <String>[];

    // 1. Native player audio streams
    final nativeAudio = _player.state.tracks.audio.where((a) => a.id != 'no').toList();
    for (int i = 0; i < nativeAudio.length; i++) {
      final a = nativeAudio[i];
      final label = _formatAudioTrackName(a, i, nativeAudio.length);
      _nativeAudioTrackMap[label] = a;
      if (!audioList.contains(label)) {
        audioList.add(label);
      }
    }

    // 2. Alternative server audio feeds (e.g. dubs/subs)
    bool hasSubServer = false;
    bool hasDubServer = false;
    for (final s in _availableServers) {
      final up = s.name.toUpperCase();
      if (up.contains('[DUB]') && !hasDubServer) {
        hasDubServer = true;
        const dubLabel = '[DUB] English Dub (Server)';
        _serverAudioTrackMap[dubLabel] = s;
        if (!audioList.contains(dubLabel)) audioList.add(dubLabel);
      } else if (up.contains('[SUB]') && !hasSubServer) {
        hasSubServer = true;
        final subLabel = _isAnime ? '[SUB] Japanese Audio (Server)' : '[SUB] Original Audio (Server)';
        _serverAudioTrackMap[subLabel] = s;
        if (!audioList.contains(subLabel)) audioList.add(subLabel);
      }
    }

    if (audioList.isEmpty) {
      audioList.add('Default');
    }

    // 3. Subtitles
    final subList = <String>['Off'];

    // Native embedded subtitle tracks
    final nativeSubs = _player.state.tracks.subtitle.where((s) => s.id != 'no').toList();
    for (int i = 0; i < nativeSubs.length; i++) {
      final s = nativeSubs[i];
      String label = s.title?.trim() ?? '';
      if (label.isEmpty) {
        final lang = s.language?.trim().toLowerCase() ?? '';
        if (lang == 'en' || lang == 'eng') {
          label = 'English (Embedded)';
        } else if (lang.isNotEmpty) {
          label = '${lang.toUpperCase()} (Embedded)';
        } else {
          label = 'Subtitle ${i + 1} (Embedded)';
        }
      }
      _nativeSubtitleTrackMap[label] = s;
      if (!subList.contains(label)) subList.add(label);
    }

    // External WebVTT / SRT subtitles from stream result
    if (_currentStreamResult != null) {
      for (final extSub in _currentStreamResult!.subtitles) {
        if (extSub.url.trim().isEmpty || extSub.lang.toLowerCase() == 'off') continue;
        String label = extSub.lang.trim();
        if (subList.contains(label)) {
          label = '$label (External)';
        }
        _externalSubtitleUrlMap[label] = extSub.url.trim();
        if (!subList.contains(label)) {
          subList.add(label);
        }
      }
    }

    setState(() {
      _availableAudioTracks = audioList;
      _availableSubtitles = subList;
      if ((_currentAudioTrack == 'Default' || !_availableAudioTracks.contains(_currentAudioTrack)) &&
          audioList.isNotEmpty) {
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

    AppToast.show(
      context,
      'Loading ${ep.title.isNotEmpty ? ep.title : "Episode ${ep.number}"}...',
      type: ToastType.info,
      duration: const Duration(seconds: 2),
    );

    try {
      final servers = await ApiService().getServers(ep.id, title: _currentTitle);
      if (servers.isEmpty) {
        throw Exception('No streaming servers available for this episode.');
      }

      final wantsDub = _currentAudioTrack.toUpperCase().contains('[DUB]');
      Server srv = servers.first;
      if (wantsDub) {
        srv = servers.firstWhere(
          (s) => s.name.toUpperCase().contains('[DUB]'),
          orElse: () => servers.first,
        );
      } else {
        srv = servers.firstWhere(
          (s) => s.name.toUpperCase().contains('[SUB]'),
          orElse: () => servers.first,
        );
      }

      final streamRes = await ApiService().getSources(srv.id, title: _currentTitle);
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
        AppToast.show(
          context,
          'Failed to play episode: ${e.toString()}',
          type: ToastType.error,
        );
      }
    }
  }

  void _initRoomAndSync() {
    final roomService = Provider.of<RoomService>(context, listen: false);
    final localStore = Provider.of<LocalStoreService>(context, listen: false);

    if (_currentRoomCode != null && _currentRoomCode!.isNotEmpty && !roomService.isConnected) {
      roomService.connect(
        roomId: _currentRoomCode!,
        userId: localStore.peerId,
        username: localStore.username,
      );
      _isChatOpen = true;
    }

    // If host enters player and room is already connected, broadcast media immediately!
    if (roomService.isInParty && roomService.isHost && _currentStreamUrl.isNotEmpty) {
      roomService.sendChangeMedia(
        widget.mediaId,
        _currentTitle,
        _currentStreamUrl,
        _currentEpisodeId ?? widget.episodeId ?? '',
        headers: widget.streamResult?.headers,
      );
    }

    // Handlers for incoming sync events (respecting _isPartySynced)
    roomService.onRoomStateReceived = (roomState) {
      if (!mounted || !_isPartySynced) return;
      if (roomState.streamUrl.isNotEmpty && roomState.streamUrl != _currentStreamUrl) {
        setState(() {
          _currentTitle = roomState.title;
          _currentStreamUrl = roomState.streamUrl;
        });
        _player.stop();
        _player.open(Media(roomState.streamUrl, httpHeaders: roomState.headers));
      }
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
      if (!mounted || !_isPartySynced) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final delay = executeAtMs - now;
      if (delay > 0) {
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted && _isPartySynced) {
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
      if (!mounted || !_isPartySynced) return;
      _player.seek(Duration(milliseconds: (position * 1000).toInt()));
      _player.pause();
    };

    roomService.onSeekReceived = (position, executeAtMs) {
      if (!mounted || !_isPartySynced) return;
      _player.seek(Duration(milliseconds: (position * 1000).toInt()));
    };

    roomService.onMediaChangedReceived = (mediaId, title, streamUrl) {
      if (!mounted) return;
      setState(() {
        _currentTitle = title;
        _currentStreamUrl = streamUrl;
      });
      roomService.localActiveMediaId = mediaId;
      final headers = roomService.state?.headers;
      _player.stop();
      _player.open(Media(streamUrl, httpHeaders: headers));
      _player.play();
      AppToast.show(
        context,
        'Now playing with party: $title',
        type: ToastType.info,
      );
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

  void _syncWithParty() {
    final roomService = Provider.of<RoomService>(context, listen: false);
    final room = roomService.state;
    if (room == null || !roomService.isInParty) return;

    setState(() {
      _isPartySynced = true;
    });

    if (room.streamUrl.isNotEmpty && room.streamUrl != _currentStreamUrl) {
      setState(() {
        _currentTitle = room.title;
        _currentStreamUrl = room.streamUrl;
      });
      roomService.localActiveMediaId = room.mediaId;
      final headers = room.headers;
      final media = Media(
        room.streamUrl,
        httpHeaders: (headers != null && headers.isNotEmpty) ? headers : null,
      );
      _player.open(media, play: room.isPlaying);
    } else {
      if (room.isPlaying != _player.state.playing) {
        if (room.isPlaying) {
          _player.play();
        } else {
          _player.pause();
        }
      }
    }

    if (room.currentPosition > 0) {
      _player.seek(Duration(milliseconds: (room.currentPosition * 1000).round()));
    }

    AppToast.show(
      context,
      'Synced with watch party playback',
      type: ToastType.success,
      duration: const Duration(seconds: 2),
    );
  }

  void _togglePartySync() {
    setState(() {
      _isPartySynced = !_isPartySynced;
    });

    if (_isPartySynced) {
      _syncWithParty();
    } else {
      AppToast.show(
        context,
        'Watching independently (Party playback unlinked)',
        type: ToastType.warning,
        duration: const Duration(seconds: 2),
      );
    }
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

    // 1. If it's a native mpv audio stream
    if (_nativeAudioTrackMap.containsKey(trackLabel)) {
      final targetTrack = _nativeAudioTrackMap[trackLabel]!;
      await _player.setAudioTrack(targetTrack);
      if (mounted) {
        AppToast.show(context, 'Audio switched: $trackLabel', type: ToastType.info);
      }
      return;
    }

    // 2. If it's a server switch (e.g. DUB vs SUB mirror)
    if (_serverAudioTrackMap.containsKey(trackLabel)) {
      final srv = _serverAudioTrackMap[trackLabel]!;
      final currentPos = _player.state.position;
      final res = await ApiService().getSources(srv.id, title: _currentTitle);
      if (res != null && res.sources.isNotEmpty && mounted) {
        setState(() {
          _currentStreamUrl = res.sources.first.url;
          _currentStreamResult = res;
        });
        _openMedia(res.sources.first.url, headers: res.headers);
        await _player.seek(currentPos);
        _player.play();
        AppToast.show(context, 'Audio feed switched: $trackLabel', type: ToastType.success);
        return;
      }
    }

    // Fallback: check tracks directly
    final tracks = _player.state.tracks.audio;
    for (final t in tracks) {
      if (t.title == trackLabel || t.language == trackLabel) {
        await _player.setAudioTrack(t);
        return;
      }
    }
  }

  Future<void> _switchSubtitle(String sub) async {
    setState(() => _currentSubtitleTrack = sub);

    if (sub == 'Off') {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      if (mounted) {
        AppToast.show(context, 'Subtitles turned off', type: ToastType.info);
      }
      return;
    }

    // 1. If it's a native mpv subtitle track
    if (_nativeSubtitleTrackMap.containsKey(sub)) {
      await _player.setSubtitleTrack(_nativeSubtitleTrackMap[sub]!);
      if (mounted) {
        AppToast.show(context, 'Subtitles: $sub', type: ToastType.success);
      }
      return;
    }

    // 2. If it's an external WebVTT / SRT subtitle
    if (_externalSubtitleUrlMap.containsKey(sub)) {
      final rawUrl = _externalSubtitleUrlMap[sub]!;
      String fetchUrl = rawUrl;
      if (fetchUrl.startsWith('/')) {
        final base = ApiService().baseUrl;
        fetchUrl = '$base$fetchUrl';
      }
      try {
        final dio = Dio();
        final resp = await dio.get<String>(
          fetchUrl,
          options: Options(
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
            responseType: ResponseType.plain,
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        if (resp.data != null && resp.data!.isNotEmpty) {
          String content = resp.data!;
          // Ensure standard WebVTT formatting if incoming is SRT
          if (!content.trimLeft().startsWith('WEBVTT')) {
            final reSRT = RegExp(r'(\d{2}:\d{2}:\d{2}),(\d{3})');
            content = 'WEBVTT\n\n${content.replaceAllMapped(reSRT, (m) => '${m[1]}.${m[2]}')}';
          }
          await _player.setSubtitleTrack(SubtitleTrack.data(content, title: sub, language: sub));
          if (mounted) {
            AppToast.show(context, 'Subtitles: $sub', type: ToastType.success);
          }
          return;
        }
      } catch (e) {
        // Fallback: load as direct URI in media_kit
        try {
          await _player.setSubtitleTrack(SubtitleTrack.uri(fetchUrl, title: sub, language: sub));
          if (mounted) {
            AppToast.show(context, 'Subtitles: $sub', type: ToastType.info);
          }
          return;
        } catch (_) {}
      }
    }

    // Fallback: scan tracks
    final tracks = _player.state.tracks.subtitle;
    for (final t in tracks) {
      if ((t.language != null && t.language!.toLowerCase() == sub.toLowerCase()) ||
          (t.title != null && t.title!.toLowerCase().contains(sub.toLowerCase()))) {
        await _player.setSubtitleTrack(t);
        return;
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
        await _restoreMobileOrientation();
      }
    }
  }

  Future<void> _restoreMobileOrientation() async {
    if (_isDesktop) return;
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
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
          AppToast.show(
            context,
            'Watch Room created! Code: $roomCode',
            type: ToastType.success,
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

  void _handleBackgroundTap() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _onUserInteraction() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_player.state.playing && mounted) {
      double durSecs = 3.5;
      try {
        durSecs = Provider.of<SettingsService>(context, listen: false).autoHideControlsSeconds;
      } catch (_) {}
      if (durSecs <= 0) {
        return; // 'Never' option selected
      }
      _hideControlsTimer = Timer(Duration(milliseconds: (durSecs * 1000).round()), () {
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
    if (_isFullscreen) {
      await _toggleFullscreen();
      return;
    }

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

    // Hand off active playback seamlessly to floating mini-player
    final playbackService = Provider.of<PlaybackService>(context, listen: false);
    _disposedForPiP = true;
    playbackService.startFloating(
      activePlayer: _player,
      activeController: _controller,
      activeMediaId: widget.mediaId,
      activeEpisodeId: _currentEpisodeId,
      activeTitle: _currentTitle,
      activeSubtitle: _currentSubtitle,
      activeStreamUrl: _currentStreamUrl,
      activeStreamResult: _currentStreamResult,
      activeAudioTrack: _currentAudioTrack,
    );

    if (!_isDesktop) {
      await _restoreMobileOrientation();
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _bufferingWatchdog?.cancel();
    _hideControlsTimer?.cancel();
    _historyTimer?.cancel();
    _syncCheckTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);

    final roomService = Provider.of<RoomService>(context, listen: false);
    roomService.localActiveMediaId = null;
    roomService.onRoomStateReceived = null;
    roomService.onPlayReceived = null;
    roomService.onPauseReceived = null;
    roomService.onSeekReceived = null;
    roomService.onMediaChangedReceived = null;

    if (!_disposedForPiP) {
      _player.stop();
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
      _restoreMobileOrientation();
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
      onHover: (event) {
        if (_lastPointerPosition == null) {
          _lastPointerPosition = event.position;
          return;
        }
        final distSq = (event.position - _lastPointerPosition!).distanceSquared;
        if (distSq > 16.0) {
          _lastPointerPosition = event.position;
          _onUserInteraction();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Consumer<SettingsService>(
            builder: (context, settings, _) {
              return MobileGesturesOverlay(
                seekDurationSeconds: settings.seekDurationSeconds,
                onTap: _handleBackgroundTap,
                onDoubleTapLeft: () {
                  _seek(_player.state.position - Duration(seconds: settings.seekDurationSeconds));
                },
                onDoubleTapRight: () {
                  _seek(_player.state.position + Duration(seconds: settings.seekDurationSeconds));
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Video(
                        controller: _controller,
                        controls: NoVideoControls,
                        subtitleViewConfiguration: SubtitleViewConfiguration(
                          style: TextStyle(
                            height: 1.4,
                            fontSize: settings.subtitleFontSize + (_isDesktop ? 4 : 0),
                            letterSpacing: 0.2,
                            wordSpacing: 1.0,
                            color: Color(settings.subtitleTextColor),
                            fontWeight: FontWeight.bold,
                            backgroundColor: Colors.black.withValues(alpha: settings.subtitleBackgroundOpacity),
                          ),
                          textAlign: TextAlign.center,
                          padding: const EdgeInsets.all(24.0),
                        ),
                      ),
                    ),
                    if (_isBuffering && !_controlsVisible)
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 3.5,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // HUD Overlay with Reactive Play/Pause stream
          StreamBuilder<bool>(
            stream: _player.stream.playing,
            initialData: _player.state.playing,
            builder: (context, snapshotPlaying) {
              final isPlaying = snapshotPlaying.data ?? _player.state.playing;

              return StreamBuilder<Duration>(
                stream: _player.stream.duration,
                initialData: _player.state.duration,
                builder: (context, snapshotDur) {
                  final duration = snapshotDur.data ?? _player.state.duration;

                  return StreamBuilder<Duration>(
                    stream: _player.stream.position,
                    builder: (context, snapshotPos) {
                      final position = snapshotPos.data ?? Duration.zero;
                      final volume = _player.state.volume / 100.0;

                      return DesktopHUD(
                        isVisible: _controlsVisible,
                        title: _currentTitle,
                        subtitle: _currentSubtitle,
                        isPlaying: isPlaying,
                        isBuffering: _isBuffering,
                        position: position,
                        duration: duration,
                        volume: volume,
                        isMuted: volume == 0.0,
                        isFullscreen: _isFullscreen,
                        isRoom: isRoomActive,
                        roomCode: _currentRoomCode ?? roomService.currentRoomId,
                        participantCount: roomService.state?.participants.length ?? 1,
                        isPartySynced: _isPartySynced,
                        onTogglePartySync: isRoomActive ? _togglePartySync : null,
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
                    onBackgroundTap: _handleBackgroundTap,
                    onOpenPlayerSettings: _openPlayerSettings,
                      );
                    },
                  );
                },
              );
            },
          ),
          if (_isPlayerSettingsOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _isPlayerSettingsOpen = false),
                child: Container(
                  color: Colors.black45,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(
                    right: _isDesktop ? 32 : 12,
                    top: 24,
                    bottom: 24,
                    left: _isDesktop ? 0 : 12,
                  ),
                  child: GestureDetector(
                    onTap: () {}, // absorb inner tap
                    child: PlayerSettingsModal(
                      player: _player,
                      title: _currentTitle,
                      servers: _availableServers,
                      currentServer: _currentServer,
                      sources: _currentStreamResult?.sources ?? [],
                      currentQuality: _currentQuality,
                      availableSubtitles: _availableSubtitles,
                      currentSubtitle: _currentSubtitleTrack,
                      availableAudioTracks: _availableAudioTracks,
                      currentAudioTrack: _currentAudioTrack,
                      serverStatuses: _serverStatuses,
                      favoriteServers: _favoriteServers,
                      initialTab: _playerSettingsTab,
                      onSelectServer: (srv) => _loadServerAndStream(srv),
                      onSelectQuality: _switchSource,
                      onSelectSubtitle: _switchSubtitle,
                      onSelectAudioTrack: _switchAudioTrack,
                      onToggleFavoriteServer: (srvId) {
                        setState(() {
                          if (_favoriteServers.contains(srvId)) {
                            _favoriteServers.remove(srvId);
                          } else {
                            _favoriteServers.add(srvId);
                          }
                        });
                      },
                      onUploadSubtitle: (fileName, content) async {
                        await _applyUploadedSubtitle(fileName, content);
                      },
                      onSelectOnlineSubtitle: _selectOnlineSubtitle,
                      onClose: () => setState(() => _isPlayerSettingsOpen = false),
                    ),
                  ),
                ),
              ),
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

  Future<void> _handleSelectRecommended(MediaItem item) async {
    final roomService = Provider.of<RoomService>(context, listen: false);
    bool playForParty = false;

    if (roomService.isInParty) {
      final shouldParty = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161928),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
          title: Text('Watch "${item.title}"', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: const Text(
            'Would you like to play this for the entire party, or watch it independently?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Watch Alone', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Play for Party', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (shouldParty == null) return;
      playForParty = shouldParty;
    }

    AppToast.show(
      context,
      'Loading "${item.title}"...',
      type: ToastType.info,
      duration: const Duration(seconds: 2),
    );

    try {
      final servers = await ApiService().getServers(item.id);
      if (servers.isEmpty) {
        if (mounted) {
          AppToast.show(
            context,
            'No stream found for "${item.title}"',
            type: ToastType.warning,
          );
        }
        return;
      }
      final srv = servers.first;
      final streamRes = await ApiService().getSources(srv.id, title: item.title);
      if (streamRes == null || streamRes.sources.isEmpty) {
        if (mounted) {
          AppToast.show(
            context,
            'Stream unavailable for "${item.title}"',
            type: ToastType.warning,
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _currentTitle = item.title;
        _currentSubtitle = null;
        _currentEpisodeId = null;
        _currentStreamUrl = streamRes.sources.first.url;
        _currentStreamResult = streamRes;
        _isPartySynced = playForParty;
      });

      roomService.localActiveMediaId = item.id;
      _openMedia(streamRes.sources.first.url, headers: streamRes.headers);
      _player.play();

      if (playForParty) {
        roomService.sendChangeMedia(
          item.id,
          item.title,
          streamRes.sources.first.url,
          item.id,
          headers: streamRes.headers,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Failed to load stream: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Widget _buildRecommendedItemCard(MediaItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _handleSelectRecommended(item),
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
          if (hasSidebar) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _isChatOpen = false;
                  _isEpisodesOpen = false;
                }),
                child: Container(color: Colors.black54),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: (screenWidth * 0.82).clamp(260.0, 320.0),
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

                // Seasons & Episodes Grid (Inline below player - NO modal)
                if (_isSeries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Episodes',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (_availableSeasons.isNotEmpty)
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _loadingEpisodes
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.accent)))
                        : _episodes.isEmpty
                            ? const Padding(padding: EdgeInsets.all(12), child: Text('No episodes found.', style: TextStyle(color: AppColors.textSecondary)))
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  childAspectRatio: 1.3,
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
                                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
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

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _isFullscreen) {
          await _toggleFullscreen();
          return;
        }
        if (didPop && !_disposedForPiP) {
          final playbackService = Provider.of<PlaybackService>(context, listen: false);
          _disposedForPiP = true;
          playbackService.startFloating(
            activePlayer: _player,
            activeController: _controller,
            activeMediaId: widget.mediaId,
            activeEpisodeId: _currentEpisodeId,
            activeTitle: _currentTitle,
            activeSubtitle: _currentSubtitle,
            activeStreamUrl: _currentStreamUrl,
            activeStreamResult: _currentStreamResult,
            activeAudioTrack: _currentAudioTrack,
          );
          await _restoreMobileOrientation();
        }
      },
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
