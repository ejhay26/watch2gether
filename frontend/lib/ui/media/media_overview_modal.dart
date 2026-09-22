import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/media_item.dart';
import '../../services/api_service.dart';
import '../auth/auth_guard.dart';
import '../player/player_screen.dart';

class MediaOverviewModal extends StatefulWidget {
  final MediaItem item;

  const MediaOverviewModal({super.key, required this.item});

  static void show(BuildContext context, MediaItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => MediaOverviewModal(item: item),
    );
  }

  @override
  State<MediaOverviewModal> createState() => _MediaOverviewModalState();
}

class _MediaOverviewModalState extends State<MediaOverviewModal> {
  final ApiService _api = ApiService();

  MediaItem? _details;
  List<Episode> _episodes = [];
  int _selectedSeason = 1;
  bool _isLoadingEpisodes = false;
  bool _isLaunchingPlayer = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final det = await _api.getDetails(widget.item.id);
    if (mounted) {
      setState(() {
        _details = det ?? widget.item;
      });

      if (_isSeries) {
        _loadEpisodes(1);
      }
    }
  }

  Future<void> _loadEpisodes(int season) async {
    setState(() {
      _selectedSeason = season;
      _isLoadingEpisodes = true;
    });

    final eps = await _api.getEpisodes(widget.item.id, season: season);
    if (mounted) {
      setState(() {
        _episodes = eps;
        _isLoadingEpisodes = false;
      });
    }
  }

  bool get _isSeries => (_details?.type ?? widget.item.type) == 'tv';

  Future<void> _playMedia({Episode? episode, bool createRoom = false}) async {
    setState(() => _isLaunchingPlayer = true);

    try {
      final epId = episode?.id ?? (_episodes.isNotEmpty ? _episodes[0].id : widget.item.id);
      final srvs = await _api.getServers(epId);
      final srvId = srvs.isNotEmpty ? srvs[0].id : epId;

      final streamRes = await _api.getSources(srvId);
      final streamUrl = streamRes != null && streamRes.sources.isNotEmpty
          ? streamRes.sources[0].url
          : "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8";

      String? roomCode;
      if (createRoom) {
        roomCode = await _api.createRoom(
          mediaId: widget.item.id,
          title: widget.item.title,
          streamUrl: streamUrl,
          episodeId: epId,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Close overview modal

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: widget.item.title,
            subtitle: episode != null ? 'S${episode.season}:E${episode.number} - ${episode.title}' : null,
            streamUrl: streamUrl,
            mediaId: widget.item.id,
            episodeId: epId,
            initialRoomCode: roomCode,
            streamResult: streamRes,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLaunchingPlayer = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video stream: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = _details ?? widget.item;
    final bannerUrl = media.banner ?? media.poster;
    final ratingSrc = media.ratingSource ?? 'TMDB';
    final rating = media.rating ?? '8.0';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: 820,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF111319),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.85),
                blurRadius: 40,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Banner with Backdrop + Gradient + Close Button
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 7,
                        child: bannerUrl.isNotEmpty
                            ? Image.network(
                                bannerUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: AppColors.surface),
                              )
                            : Container(color: AppColors.surface),
                      ),

                      // Gradient overlays
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                                const Color(0xFF111319).withOpacity(0.8),
                                const Color(0xFF111319),
                              ],
                              stops: const [0.0, 0.3, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Close Button
                      Positioned(
                        top: 16,
                        right: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.6),
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),

                      // Title & Badges overlaid at bottom of banner
                      Positioned(
                        left: 28,
                        right: 28,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              media.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Meta row: Rating + Source, Year, Duration/Seasons, Quality
                            Row(
                              children: [
                                // Rating + Source badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$ratingSrc $rating',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                if (media.year != null && media.year!.isNotEmpty) ...[
                                  Text(
                                    media.year!,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 10),
                                ],

                                // Movie runtime OR Series season count
                                if (!_isSeries && media.duration != null && media.duration!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      media.duration!,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ] else if (_isSeries) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${media.seasons?.length ?? 1} Seasons',
                                      style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],

                                // Quality badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    media.quality ?? '1080p HD',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Action Buttons (Play Solo + Watch Together)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
                    child: Row(
                      children: [
                        // Play Solo Button (Primary)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: const Text(
                            'Play Solo',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                          onPressed: _isLaunchingPlayer ? null : () => _playMedia(createRoom: false),
                        ),
                        const SizedBox(width: 14),

                        // Watch Together Button (Secondary)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.group_add_rounded, size: 20),
                          label: const Text(
                            'Watch Together',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isLaunchingPlayer
                              ? null
                              : () {
                                  AuthGuard.runGuarded(
                                    context,
                                    message: 'Sign in to host a synchronized Watch Party with friends.',
                                    onAuthorized: () => _playMedia(createRoom: true),
                                  );
                                },
                        ),

                        if (_isLaunchingPlayer) ...[
                          const SizedBox(width: 16),
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Overview Description & Genres
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          media.overview ?? 'No description available for this title.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (media.genres != null && media.genres!.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: media.genres!.map((g) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  g,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),

                  // TV Series: Season Dropdown + Episode Grid
                  if (_isSeries) ...[
                    const Divider(color: Colors.white10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Episodes',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),

                          // Season Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1E28),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedSeason,
                                dropdownColor: const Color(0xFF1B1E28),
                                icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                items: (media.seasons ?? [1]).map((s) {
                                  return DropdownMenuItem<int>(
                                    value: s,
                                    child: Text('Season $s'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null && val != _selectedSeason) {
                                    _loadEpisodes(val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Episodes Grid / List
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                      child: _isLoadingEpisodes
                          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.accent)))
                          : _episodes.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('No episodes found for this season.', style: TextStyle(color: AppColors.textSecondary)),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _episodes.length,
                                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 16),
                                  itemBuilder: (ctx, idx) {
                                    final ep = _episodes[idx];
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _playMedia(episode: ep, createRoom: false),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Episode number square
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${ep.number}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Title and description
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    ep.title,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (ep.overview != null && ep.overview!.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      ep.overview!,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: AppColors.textSecondary,
                                                        fontSize: 12,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),

                                            IconButton(
                                              icon: const Icon(Icons.play_circle_outline, color: AppColors.accent, size: 26),
                                              onPressed: () => _playMedia(episode: ep, createRoom: false),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
