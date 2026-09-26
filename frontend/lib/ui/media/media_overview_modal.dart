import 'package:provider/provider.dart';
import '../../services/room_service.dart';
import '../../services/playback_service.dart';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/media_item.dart';
import '../../services/api_service.dart';
import '../components/app_toast.dart';
import '../auth/auth_guard.dart';
import '../player/player_screen.dart';

class MediaOverviewModal extends StatefulWidget {
  final MediaItem item;

  const MediaOverviewModal({
    super.key,
    required this.item,
  });

  static void show(BuildContext context, MediaItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (_) => MediaOverviewModal(item: item),
    );
  }

  @override
  State<MediaOverviewModal> createState() => _MediaOverviewModalState();
}

class _MediaOverviewModalState extends State<MediaOverviewModal> {
  final _api = ApiService();
  MediaItem? _details;
  int _selectedSeason = 1;
  List<Episode> _episodes = [];
  bool _isLoadingEpisodes = false;
  bool _isLaunchingPlayer = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final res = await _api.getDetails(widget.item.id);
    if (mounted) {
      setState(() {
        _details = res;
        if (res != null && res.seasons != null && res.seasons!.isNotEmpty) {
          _selectedSeason = res.seasons![0];
        }
      });
      if (_isSeries) {
        _loadEpisodes(_selectedSeason);
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

  bool get _isSeries {
    final id = widget.item.id;
    if (id.contains('movie')) return false;
    final type = _details?.type ?? widget.item.type;
    return type == 'tv' || id.startsWith('anime-');
  }

  bool get _isAnime {
    final id = widget.item.id;
    if (id.startsWith('anime-')) return true;
    final genres = _details?.genres ?? widget.item.genres ?? [];
    if (genres.any((g) => g.toLowerCase().contains('anime'))) return true;
    final year = widget.item.year ?? '';
    return year.toLowerCase().contains('anime');
  }

  Future<void> _playMedia({Episode? episode, bool createRoom = false}) async {
    setState(() => _isLaunchingPlayer = true);

    try {
      if (episode == null && _episodes.isEmpty && (widget.item.type == 'tv' || _isAnime)) {
        final loaded = await _api.getEpisodes(widget.item.id, season: _selectedSeason);
        if (loaded.isNotEmpty) {
          _episodes = loaded;
        }
      }
      final epId = episode?.id ?? (_episodes.isNotEmpty ? _episodes[0].id : widget.item.id);
      final srvs = await _api.getServers(epId, title: widget.item.title);
      String srvId = epId;
      if (srvs.isNotEmpty) {
        srvId = srvs.first.id;
      }

      final streamRes = await _api.getSources(srvId, title: widget.item.title);
      if (streamRes == null || streamRes.sources.isEmpty) {
        if (mounted) {
          setState(() => _isLaunchingPlayer = false);
          AppToast.show(
            context,
            'Unable to locate a stream for "${widget.item.title}". Please select another server or title.',
            type: ToastType.warning,
            duration: const Duration(seconds: 4),
          );
        }
        return;
      }
      final streamUrl = streamRes.sources[0].url;

      if (!mounted) return;
      // Stop previous floating player immediately to prevent audio overlap
      final playback = Provider.of<PlaybackService>(context, listen: false);
      if (playback.isFloating) {
        playback.stopFloating();
      }

      final roomService = Provider.of<RoomService>(context, listen: false);
      String? roomCode;
      bool isPartySynced = true;

      if (roomService.isInParty) {
        final partyState = roomService.state;
        final isPartyWatchingThis = partyState != null && partyState.mediaId == widget.item.id;
        final isPartyWatchingOther = partyState != null && partyState.mediaId.isNotEmpty && partyState.mediaId != widget.item.id;

        if (isPartyWatchingThis) {
          final posSeconds = partyState.currentPosition.toInt();
          final mins = posSeconds ~/ 60;
          final secs = posSeconds % 60;
          final timeStr = "$mins:${secs.toString().padLeft(2, '0')}";

          final shouldSync = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF161928),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
              title: const Text("Party Watching Live", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              content: Text(
                'Your party is currently watching "${widget.item.title}" at $timeStr. Would you like to synchronize with them, or watch from the beginning independently?',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Watch Independently", style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text("Sync with Party", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (shouldSync == null) {
            setState(() => _isLaunchingPlayer = false);
            return;
          }
          if (shouldSync) {
            roomCode = roomService.currentRoomId;
            isPartySynced = true;
          } else {
            roomCode = null;
            isPartySynced = false;
          }
        } else if (isPartyWatchingOther) {
          final shouldSwitch = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF161928),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
              title: const Text("Party Active", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              content: Text(
                'Your party is currently watching "${partyState.title}". Would you like to switch the party to "${widget.item.title}", or watch independently?',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Watch Alone", style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text("Switch for Party", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (shouldSwitch == null) {
            setState(() => _isLaunchingPlayer = false);
            return;
          }
          if (shouldSwitch) {
            roomCode = roomService.currentRoomId;
            isPartySynced = true;
            roomService.sendChangeMedia(
              widget.item.id,
              widget.item.title,
              streamUrl,
              epId,
              headers: streamRes.headers,
            );
          } else {
            roomCode = null;
            isPartySynced = false;
          }
        } else {
          roomCode = roomService.currentRoomId;
          isPartySynced = true;
          roomService.sendChangeMedia(
            widget.item.id,
            widget.item.title,
            streamUrl,
            epId,
            headers: streamRes.headers,
          );
        }
      } else if (createRoom) {
        roomCode = await _api.createRoom(
          mediaId: widget.item.id,
          title: widget.item.title,
          streamUrl: streamUrl,
          episodeId: epId,
          headers: streamRes.headers,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Close overview modal

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: widget.item.title,
            subtitle: episode != null ? 'S${episode.season}:E${episode.number} - ${episode.title}' : null,
            poster: widget.item.poster,
            streamUrl: streamUrl,
            mediaId: widget.item.id,
            episodeId: epId,
            initialRoomCode: roomCode,
            streamResult: streamRes,
            isPartySynced: isPartySynced,
            initialAudioTrack: _isAnime ? '[SUB] Japanese Audio' : 'Original Audio (English)',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLaunchingPlayer = false);
        AppToast.show(
          context,
          'Failed to load video stream: $e',
          type: ToastType.error,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 550;
    final contentPadding = isMobile ? 16.0 : 28.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: isMobile ? 16 : 24),
      child: Center(
        child: Container(
          width: 820,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
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
                        aspectRatio: isMobile ? 16 / 9 : 16 / 7,
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
                                AppColors.surface.withOpacity(0.8),
                                AppColors.surface,
                              ],
                              stops: const [0.0, 0.3, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Close Button
                      Positioned(
                        top: 14,
                        right: 14,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withOpacity(0.65),
                          radius: 17,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 17),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),

                      // Title & Badges overlaid at bottom of banner
                      Positioned(
                        left: contentPadding,
                        right: contentPadding,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              media.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 20 : 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Meta row: Rating + Source, Year, Duration/Seasons, Quality
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Rating + Source badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$ratingSrc $rating',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (media.year != null && media.year!.isNotEmpty)
                                  Text(
                                    media.year!,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),

                                // Movie runtime OR Series season count
                                if (!_isSeries && media.duration != null && media.duration!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      media.duration!,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  )
                                else if (_isSeries && _isAnime)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${media.seasons?.length ?? 1} Seasons',
                                      style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),

                                // Quality badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    media.quality ?? '1080p HD',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Action Buttons (Play Solo + Watch Together + Sub/Dub)
                  Padding(
                    padding: EdgeInsets.fromLTRB(contentPadding, 14, contentPadding, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Action Buttons Row (Responsive with Expanded to guarantee ZERO overflow)
                        Row(
                          children: [
                            // Play Solo Button
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                label: const Text(
                                  'Play Solo',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: _isLaunchingPlayer ? null : () => _playMedia(createRoom: false),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Watch Together Button
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  side: const BorderSide(color: AppColors.accent, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.group_add_rounded, size: 19),
                                label: const Text(
                                  'Watch Together',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                            ),

                            if (_isLaunchingPlayer) ...[
                              const SizedBox(width: 10),
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Overview Description & Genres
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: contentPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          media.overview ?? 'No description available for this title.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Genres Badges
                        if (media.genres != null && media.genres!.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: media.genres!.map((genre) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.surfaceBorder),
                                ),
                                child: Text(
                                  genre,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  // TV Series: Season Dropdown + Episode Grid
                  if (_isSeries) ...[
                    const Divider(color: Colors.white10),
                    Padding(
                      padding: EdgeInsets.fromLTRB(contentPadding, 10, contentPadding, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Episodes',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),

                          // Season Dropdown
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
                      padding: EdgeInsets.fromLTRB(contentPadding, 0, contentPadding, 20),
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
                                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 12),
                                  itemBuilder: (ctx, idx) {
                                    final ep = _episodes[idx];
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _playMedia(episode: ep, createRoom: false),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
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
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    ep.title,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  if (ep.overview != null && ep.overview!.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      ep.overview!,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: AppColors.textSecondary,
                                                        fontSize: 11,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),

                                            IconButton(
                                              icon: const Icon(Icons.play_circle_outline, color: AppColors.accent, size: 24),
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
