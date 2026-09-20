import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'player/player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<MediaItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
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

  Future<void> _playMedia(MediaItem item, {bool createRoom = false}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );

    try {
      // 1. Get episodes
      final eps = await _api.getEpisodes(item.id);
      final epId = eps.isNotEmpty ? eps[0].id : item.id;

      // 2. Get servers
      final srvs = await _api.getServers(epId);
      final srvId = srvs.isNotEmpty ? srvs[0].id : epId;

      // 3. Get stream sources
      final streamRes = await _api.getSources(srvId);
      final streamUrl = streamRes != null && streamRes.sources.isNotEmpty
          ? streamRes.sources[0].url
          : "https://test-streams.mux.dev/tos_full/master.m3u8";

      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      String? roomCode;
      if (createRoom) {
        roomCode = await _api.createRoom(
          mediaId: item.id,
          title: item.title,
          streamUrl: streamUrl,
          episodeId: epId,
        );
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: item.title,
            subtitle: eps.isNotEmpty ? eps[0].title : null,
            streamUrl: streamUrl,
            mediaId: item.id,
            episodeId: epId,
            initialRoomCode: roomCode,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stream: $e')),
        );
      }
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerScreen(
                        title: room.title,
                        streamUrl: room.streamUrl.isNotEmpty
                            ? room.streamUrl
                            : "https://test-streams.mux.dev/tos_full/master.m3u8",
                        mediaId: room.mediaId,
                        episodeId: room.episodeId,
                        initialRoomCode: code,
                      ),
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Room not found')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'W2G',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'WATCH2GETHER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Join Room Button
          OutlinedButton.icon(
            icon: const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.accent),
            label: const Text('Join Room', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: _showJoinRoomDialog,
          ),
          const SizedBox(width: 12),
          // User Badge
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceElevated,
              child: Text(
                auth.username != null && auth.username!.isNotEmpty ? auth.username![0].toUpperCase() : 'U',
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search movies, open cinema, documentaries...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          _loadTrending();
                        },
                      )
                    : null,
              ),
              onSubmitted: _performSearch,
            ),
          ),

          // Content
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
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
    );
  }

  Widget _buildMediaCard(MediaItem item) {
    return InkWell(
      onTap: () => _playMedia(item),
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
                          colors: [Colors.transparent, Colors.transparent, Color(0xCC000000)],
                        ),
                      ),
                    ),
                  ),

                  // Quality Tag
                  if (item.quality != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Text(
                          item.quality!,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  // Quick Play & Watch Together Button on Hover / Bottom
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.accent,
                          child: const Icon(Icons.play_arrow, color: Colors.black, size: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.group_add, color: Colors.white, size: 20),
                          tooltip: 'Start Watch Room',
                          onPressed: () => _playMedia(item, createRoom: true),
                        ),
                      ],
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
                      if (item.duration != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${item.duration!}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
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

