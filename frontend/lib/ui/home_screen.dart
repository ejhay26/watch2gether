import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../constants/theme.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/playback_service.dart';
import 'auth/auth_modal.dart';
import 'auth/profile_dialog.dart';
import 'media/media_overview_modal.dart';
import 'player/player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  List<MediaItem> _items = [];
  bool _isLoading = true;
  String? _error;
  int _selectedFilter = 0; // 0: All / Trending, 1: Anime & Animation, 2: Movies, 3: TV Series

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _loadTrending();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Keybind: Slash '/' focuses search bar (only on explore page, when not already focused)
      if (event.logicalKey == LogicalKeyboardKey.slash) {
        if (!_searchFocusNode.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchFocusNode.requestFocus();
            _searchController.selection = TextSelection.fromPosition(
              TextPosition(offset: _searchController.text.length),
            );
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.f11) {
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          windowManager.isFullScreen().then((isFull) {
            windowManager.setFullScreen(!isFull);
          });
        }
      }
    }
  }

  Future<void> _selectFilter(int index) async {
    setState(() {
      _selectedFilter = index;
      _isLoading = true;
      _error = null;
    });
    try {
      if (index == 0) {
        final items = await _api.getTrending();
        setState(() {
          _items = items;
          _isLoading = false;
        });
      } else if (index == 1) {
        final results = await _api.search('Anime');
        setState(() {
          _items = results;
          _isLoading = false;
        });
      } else if (index == 2) {
        final items = await _api.getTrending();
        setState(() {
          _items = items.where((it) => it.type == 'movie').toList();
          _isLoading = false;
        });
      } else if (index == 3) {
        final items = await _api.getTrending();
        setState(() {
          _items = items.where((it) => it.type == 'tv' || it.id.startsWith('anime-')).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load content';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTrending() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _api.getTrending();
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load content';
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final results = await _api.search(query);
      setState(() {
        _items = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showJoinRoomDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Join Watch Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-character room code:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 20,
                letterSpacing: 4.0,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'ABC123',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.length == 6) {
                Navigator.of(ctx).pop();
                final room = await _api.getRoom(code);
                if (room != null && mounted) {
                  if (room.streamUrl.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Watch room has no active stream URL.')),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(
                        title: room.title,
                        streamUrl: room.streamUrl,
                        mediaId: room.mediaId,
                        episodeId: room.episodeId,
                        initialRoomCode: code,
                      ),
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Room not found or expired')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return InkWell(
      onTap: () => _selectFilter(index),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.surfaceBorder,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _restoreFromFloating(PlaybackService playbackService) {
    final player = playbackService.player;
    final controller = playbackService.controller;
    final mediaId = playbackService.mediaId ?? '';
    final epId = playbackService.episodeId;
    final title = playbackService.title ?? '';
    final subtitle = playbackService.subtitle;
    final streamUrl = playbackService.streamUrl ?? '';
    final streamResult = playbackService.streamResult;

    playbackService.restore();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: title,
          subtitle: subtitle,
          streamUrl: streamUrl,
          mediaId: mediaId,
          episodeId: epId,
          streamResult: streamResult,
          existingPlayer: player,
          existingController: controller,
        ),
      ),
    );
  }

  Widget _buildFloatingMiniPlayer(PlaybackService playbackService) {
    if (!playbackService.isFloating || playbackService.controller == null) {
      return const SizedBox.shrink();
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;
    final double playerWidth = isNarrow ? 260.0 : 330.0;
    final double playerHeight = isNarrow ? 146.0 : 185.0;

    return Positioned(
      bottom: isNarrow ? 16 : 24,
      right: isNarrow ? 16 : 24,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: playerWidth,
        height: playerHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.75),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video surface - tap anywhere to restore full screen player
            GestureDetector(
              onTap: () => _restoreFromFloating(playbackService),
              child: Video(
                controller: playbackService.controller!,
                controls: NoVideoControls,
              ),
            ),

            // Top Header overlay (title & action buttons)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        playbackService.title ?? 'Playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Expand / Restore button
                    InkWell(
                      onTap: () => _restoreFromFloating(playbackService),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Close button
                    InkWell(
                      onTap: () => playbackService.stopFloating(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Play/Pause quick button (bottom-right)
            Positioned(
              bottom: 8,
              right: 8,
              child: StreamBuilder<bool>(
                stream: playbackService.player?.stream.playing,
                initialData: playbackService.player?.state.playing ?? true,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? true;
                  return InkWell(
                    onTap: () {
                      playbackService.player?.playOrPause();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final playbackService = Provider.of<PlaybackService>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: isMobile ? 12 : 20,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'WATCHHUB',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                const Text(
                  'STREAMING THEATER',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            // Join Room Button
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.meeting_room_rounded, color: AppColors.accent, size: 20),
                tooltip: 'Join Room',
                onPressed: _showJoinRoomDialog,
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.meeting_room_rounded, size: 18),
                label: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _showJoinRoomDialog,
              ),

            const SizedBox(width: 8),

            // User Account Button
            if (auth.isAuthenticated)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => ProfileDialog.show(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.accent,
                        child: Text(
                          (auth.username ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 8),
                        Text(
                          auth.username ?? 'User',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else if (isMobile)
              IconButton(
                icon: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                tooltip: 'Sign In',
                onPressed: () => AuthModal.show(context),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => AuthModal.show(context),
              ),

            SizedBox(width: isMobile ? 12 : 16),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Search Bar with slash shortcut hint
                Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 12, isMobile ? 12 : 20, 8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isMobile
                          ? 'Search titles, movies, series...'
                          : 'Search movies, TV series, anime (Press / to focus)...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMobile && !_searchFocusNode.hasFocus)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Text(
                                '/',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                _loadTrending();
                              },
                            ),
                        ],
                      ),
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),

                // Category Filters (Trending, Anime, Movies, TV)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 20.0, vertical: 2.0),
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryChip(0, 'All'),
                        const SizedBox(width: 8),
                        _buildCategoryChip(1, 'Anime & Animation'),
                        const SizedBox(width: 8),
                        _buildCategoryChip(2, 'Movies'),
                        const SizedBox(width: 8),
                        _buildCategoryChip(3, 'TV Series'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Content Area: Grid view with responsive columns
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _loadTrending,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _items.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No titles found.',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                )
                              : GridView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    isMobile ? 12 : 20,
                                    10,
                                    isMobile ? 12 : 20,
                                    playbackService.isFloating ? 200 : 20,
                                  ),
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: isMobile ? 180 : 220,
                                    childAspectRatio: 0.65,
                                    crossAxisSpacing: isMobile ? 10 : 16,
                                    mainAxisSpacing: isMobile ? 10 : 16,
                                  ),
                                  itemCount: _items.length,
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return _buildMediaCard(item);
                                  },
                                ),
                ),
              ],
            ),

            // Floating Mini-Player (PiP on Explore screen)
            _buildFloatingMiniPlayer(playbackService),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(MediaItem item) {
    final rating = item.rating ?? '7.5';

    return InkWell(
      onTap: () => MediaOverviewModal.show(context, item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.poster.isNotEmpty
                      ? Image.network(
                          item.poster,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.surfaceElevated,
                            child: const Icon(Icons.movie, color: AppColors.textMuted, size: 40),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceElevated,
                          child: const Icon(Icons.movie, color: AppColors.textMuted, size: 40),
                        ),

                  // Overlay gradient
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.transparent, Color(0xDD000000)],
                        ),
                      ),
                    ),
                  ),

                  // Quality Tag (bottom-left to avoid colliding with top rating badge on narrow cards)
                  if (item.quality != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          item.quality!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  // Rating badge (top left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            rating,
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Play Button hint
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.accent,
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Title & Meta Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.year != null && item.year!.isNotEmpty)
                        Text(
                          item.year!,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      if (item.duration != null && item.duration!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          item.duration!,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ] else if (item.type == 'tv') ...[
                        const SizedBox(width: 6),
                        const Text(
                          'Series',
                          style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
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
}
