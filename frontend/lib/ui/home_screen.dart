import 'package:url_launcher/url_launcher.dart';
import '../models/room_models.dart';
import '../services/room_service.dart';
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
  String _selectedGenre = "All";
  String _selectedYear = "All Years";

  final List<String> _genres = const [
    "All",
    "Horror",
    "Zombie",
    "Survival",
    "Action",
    "Sci-Fi",
    "Thriller",
    "Comedy",
    "Romance",
    "Drama",
  ];

  final List<String> _years = const [
    "All Years",
    "2026",
    "2025",
    "2024",
    "2023",
    "2020-2022",
    "2010s",
    "2000s",
  ];

  List<MediaItem> get _filteredItems {
    return _items.where((it) {
      // 1. Genre filter
      if (_selectedGenre != "All") {
        final query = _selectedGenre.toLowerCase();
        final title = it.title.toLowerCase();
        final overview = (it.overview ?? "").toLowerCase();
        if (!title.contains(query) && !overview.contains(query)) {
          return false;
        }
      }

      // 2. Year filter
      if (_selectedYear != "All Years") {
        final y = int.tryParse(it.year ?? "");
        if (y == null) return false;
        if (_selectedYear == "2026" && y != 2026) return false;
        if (_selectedYear == "2025" && y != 2025) return false;
        if (_selectedYear == "2024" && y != 2024) return false;
        if (_selectedYear == "2023" && y != 2023) return false;
        if (_selectedYear == "2020-2022" && (y < 2020 || y > 2022)) return false;
        if (_selectedYear == "2010s" && (y < 2010 || y > 2019)) return false;
        if (_selectedYear == "2000s" && (y < 2000 || y > 2009)) return false;
      }

      return true;
    }).toList();
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomService = Provider.of<RoomService>(context, listen: false);
      roomService.onPartyPlayPrompt = (mediaId, title, streamUrl, episodeId, headers) {
        if (!mounted) return;
        _showPartyPromptBanner(mediaId, title, streamUrl, episodeId, headers);
      };
      _checkForAppUpdate();
    });
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


  void _showPartyPromptBanner(String mediaId, String title, String streamUrl, String episodeId, Map<String, String>? headers) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 15),
        backgroundColor: const Color(0xFF1E2235),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        content: Row(
          children: [
            const Icon(Icons.movie_filter_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Party Started Watching!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: "JOIN STREAM",
          textColor: AppColors.accent,
          onPressed: () {
            final rs = Provider.of<RoomService>(context, listen: false);
            final streamRes = StreamResult(
              sources: [StreamSource(url: streamUrl, quality: "1080p", isM3U8: true)],
              subtitles: [],
              headers: headers ?? {},
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerScreen(
                  title: title,
                  streamUrl: streamUrl,
                  mediaId: mediaId,
                  episodeId: episodeId,
                  initialRoomCode: rs.currentRoomId,
                  streamResult: streamRes,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPartyDialog() {
    final roomService = Provider.of<RoomService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final controller = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161928),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Row(
            children: [
              Icon(Icons.groups_rounded, color: AppColors.accent, size: 22),
              SizedBox(width: 10),
              Text("Watch Party", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Parties stay connected across films like Roblox groups. When anyone starts a film, everyone gets prompted to join.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Start Party Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isCreating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: Text(
                  isCreating ? "Initializing Party..." : "Start New Watch Party",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: isCreating ? null : () async {
                  setDialogState(() => isCreating = true);
                  final code = await roomService.startParty(
                    username: authService.username,
                    userId: authService.userId,
                    title: "Watch Party",
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (code != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Party $code created",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        backgroundColor: const Color(0xFF1E2235),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                    );
                  }
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR JOIN PARTY", style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                    Expanded(child: Divider(color: Colors.white12)),
                  ],
                ),
              ),

              // Join Code Input with Enter submit
              TextField(
                controller: controller,
                autofocus: false,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) async {
                  final code = controller.text.trim().toUpperCase();
                  if (code.length == 6) {
                    Navigator.of(ctx).pop();
                    await _handleJoinPartyCode(code);
                  }
                },
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 18,
                  letterSpacing: 4.0,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "ENTER CODE",
                  counterText: "",
                  prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.textSecondary, size: 18),
                  filled: true,
                  fillColor: const Color(0xFF0F111D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Join with Code", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final code = controller.text.trim().toUpperCase();
                  if (code.length == 6) {
                    Navigator.of(ctx).pop();
                    await _handleJoinPartyCode(code);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinActivePartyStream(RoomStateData room) async {
    final roomService = Provider.of<RoomService>(context, listen: false);
    StreamResult? streamRes;
    if (room.headers != null && room.headers!.isNotEmpty) {
      streamRes = StreamResult(
        sources: [StreamSource(url: room.streamUrl, quality: "1080p", isM3U8: true)],
        subtitles: [],
        headers: room.headers!,
      );
    } else if (room.mediaId.isNotEmpty) {
      try {
        final srvId = room.episodeId.isNotEmpty ? room.episodeId : room.mediaId;
        final servers = await _api.getServers(srvId, title: room.title);
        if (servers.isNotEmpty) {
          streamRes = await _api.getSources(servers.first.id, title: room.title);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: room.title,
          streamUrl: (streamRes != null && streamRes.sources.isNotEmpty) ? streamRes.sources.first.url : room.streamUrl,
          mediaId: room.mediaId,
          episodeId: room.episodeId,
          initialRoomCode: roomService.currentRoomId,
          streamResult: streamRes,
        ),
      ),
    );
  }

  Widget _buildActivePartyStreamBanner(BuildContext context, RoomService roomService, bool isMobile) {
    final room = roomService.state;
    if (!roomService.isInParty || room == null || room.streamUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161928),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.movie_filter_rounded, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "CURRENTLY STREAMING IN PARTY",
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  room.title.isNotEmpty ? room.title : "Movie",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text(
              "Rejoin Stream",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: () => _joinActivePartyStream(room),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final info = await _api.checkAppVersion();
      if (info == null || !mounted) return;
      final latestVersion = info['version'] as String? ?? '';
      const currentVersion = "1.0.0";
      if (latestVersion.isNotEmpty && latestVersion != currentVersion) {
        final apkUrl = info['android_apk'] as String? ?? '';
        final releaseNotes = info['release_notes'] as String? ?? 'A new version of WatchTogether is available.';
        if (mounted) {
          _showUpdateDialog(latestVersion, releaseNotes, apkUrl);
        }
      }
    } catch (_) {}
  }

  void _showUpdateDialog(String version, String releaseNotes, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161928),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: AppColors.accent, size: 24),
            const SizedBox(width: 10),
            Text("Update v$version Available", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Release Notes:", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F111D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                releaseNotes,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Later", style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text("Download Update", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (apkUrl.isNotEmpty) {
                final uri = Uri.parse(apkUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleJoinPartyCode(String code) async {
    final roomService = Provider.of<RoomService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    final success = await roomService.joinParty(
      code,
      username: authService.username,
      userId: authService.userId,
    );

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Party not found or expired")),
        );
      }
      return;
    }

    final room = roomService.state;
    if (room != null && room.streamUrl.isNotEmpty && mounted) {
      StreamResult? streamRes;
      if (room.headers != null && room.headers!.isNotEmpty) {
        streamRes = StreamResult(
          sources: [StreamSource(url: room.streamUrl, quality: "1080p", isM3U8: true)],
          subtitles: [],
          headers: room.headers!,
        );
      } else if (room.mediaId.isNotEmpty) {
        try {
          final srvId = room.episodeId.isNotEmpty ? room.episodeId : room.mediaId;
          final servers = await _api.getServers(srvId, title: room.title);
          if (servers.isNotEmpty) {
            streamRes = await _api.getSources(servers.first.id, title: room.title);
          }
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: room.title,
            streamUrl: (streamRes != null && streamRes.sources.isNotEmpty) ? streamRes.sources.first.url : room.streamUrl,
            mediaId: room.mediaId,
            episodeId: room.episodeId,
            initialRoomCode: code,
            streamResult: streamRes,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Joined party $code",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          backgroundColor: const Color(0xFF1E2235),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
      );
    }
  }

  void _showActivePartySheet(BuildContext context, RoomService roomService) {
    final code = roomService.currentRoomId ?? "";
    final parts = roomService.state?.participants ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161928),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: AppColors.accent, size: 24),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Party Session", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        Text("Party Code: $code", style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                  tooltip: "Copy Party Code",
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Party Code $code copied to clipboard!")),
                    );
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            if (roomService.state != null && roomService.state!.streamUrl.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F111D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.movie_filter_rounded, color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "CURRENTLY STREAMING",
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            roomService.state!.title.isNotEmpty ? roomService.state!.title : "Film",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text(
                        "Rejoin",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _joinActivePartyStream(roomService.state!);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text("Members Online (${parts.length})", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: parts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final p = parts[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F111D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: p.isHost ? AppColors.accent : Colors.white24,
                          child: Text(p.username.isNotEmpty ? p.username[0].toUpperCase() : "U", style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        if (p.isHost)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text("HOST", style: TextStyle(color: AppColors.accent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                label: const Text("Leave Party", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  roomService.leaveParty();
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Left watch party")),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileFiltersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161928),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Filter Content", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = 0;
                        _selectedGenre = "All";
                        _selectedYear = "All Years";
                      });
                      setSheetState(() {});
                      _loadTrending();
                      Navigator.of(ctx).pop();
                    },
                    child: const Text("Reset All", style: TextStyle(color: AppColors.accent, fontSize: 13)),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              const Text("Category", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSheetFilterChip(0, "All", _selectedFilter == 0, () {
                    setState(() => _selectedFilter = 0);
                    setSheetState(() {});
                    _selectFilter(0);
                  }),
                  _buildSheetFilterChip(1, "Anime & Animation", _selectedFilter == 1, () {
                    setState(() => _selectedFilter = 1);
                    setSheetState(() {});
                    _selectFilter(1);
                  }),
                  _buildSheetFilterChip(2, "Movies", _selectedFilter == 2, () {
                    setState(() => _selectedFilter = 2);
                    setSheetState(() {});
                    _selectFilter(2);
                  }),
                  _buildSheetFilterChip(3, "TV Series", _selectedFilter == 3, () {
                    setState(() => _selectedFilter = 3);
                    setSheetState(() {});
                    _selectFilter(3);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Genre", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _genres.map((g) {
                  final sel = _selectedGenre == g;
                  return _buildSheetFilterChip(0, g, sel, () {
                    setState(() => _selectedGenre = g);
                    setSheetState(() {});
                    if (g != "All") {
                      _api.search(g).then((res) {
                        if (mounted) setState(() => _items = res);
                      });
                    }
                  });
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text("Release Year", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _years.map((y) {
                  final sel = _selectedYear == y;
                  return _buildSheetFilterChip(0, y, sel, () {
                    setState(() => _selectedYear = y);
                    setSheetState(() {});
                  });
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Apply Filters", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetFilterChip(int idx, String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : const Color(0xFF0F111D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.accent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPartyWidget(BuildContext context, bool isMobile) {
    final roomService = Provider.of<RoomService>(context);

    if (roomService.isInParty) {
      final code = roomService.currentRoomId ?? "";
      final memberCount = roomService.state?.participants.length ?? 1;

      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showActivePartySheet(context, roomService),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A2D4A), Color(0xFF1E2135)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.groups_rounded, color: AppColors.accent, size: 16),
              const SizedBox(width: 4),
              Text(
                "Party: $code ($memberCount)",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return IconButton(
        icon: const Icon(Icons.group_add_rounded, color: AppColors.accent, size: 21),
        tooltip: "Watch Party",
        onPressed: _showPartyDialog,
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      icon: const Icon(Icons.group_add_rounded, size: 18),
      label: const Text("Watch Party", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      onPressed: _showPartyDialog,
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
            _buildPartyWidget(context, isMobile),
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

                // Active Party Stream Rejoin Banner
                Consumer<RoomService>(
                  builder: (context, rs, _) {
                    return _buildActivePartyStreamBanner(context, rs, isMobile);
                  },
                ),

                // Category & Genre Filters (Desktop vs Mobile Heuristic)
                if (isMobile)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedGenre != "All"
                              ? "$_selectedGenre Titles"
                              : _selectedFilter == 1
                                  ? "Anime & Animation"
                                  : _selectedFilter == 2
                                      ? "Movies"
                                      : _selectedFilter == 3
                                          ? "TV Series"
                                          : "Featured & Trending",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: (_selectedGenre != "All" || _selectedYear != "All Years" || _selectedFilter != 0)
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : AppColors.surfaceElevated,
                            foregroundColor: (_selectedGenre != "All" || _selectedYear != "All Years" || _selectedFilter != 0)
                                ? AppColors.accent
                                : Colors.white,
                            side: BorderSide(
                              color: (_selectedGenre != "All" || _selectedYear != "All Years" || _selectedFilter != 0)
                                  ? AppColors.accent
                                  : Colors.white12,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: Icon(
                            Icons.tune_rounded,
                            size: 15,
                            color: (_selectedGenre != "All" || _selectedYear != "All Years" || _selectedFilter != 0)
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                          label: Text(
                            (_selectedGenre != "All" || _selectedYear != "All Years" || _selectedFilter != 0)
                                ? "Filters • Active"
                                : "Filters",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _showMobileFiltersSheet,
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
                    child: Row(
                      children: [
                        // Categories
                        _buildCategoryChip(0, "All"),
                        const SizedBox(width: 8),
                        _buildCategoryChip(1, "Anime"),
                        const SizedBox(width: 8),
                        _buildCategoryChip(2, "Movies"),
                        const SizedBox(width: 8),
                        _buildCategoryChip(3, "TV Series"),
                        const SizedBox(width: 12),
                        Container(height: 20, width: 1, color: Colors.white12),
                        const SizedBox(width: 12),

                        // Genre Dropdown / Chips
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _genres.map((g) {
                                final isSel = _selectedGenre == g;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    label: Text(g),
                                    selected: isSel,
                                    selectedColor: AppColors.accent,
                                    backgroundColor: AppColors.surfaceElevated,
                                    labelStyle: TextStyle(
                                      color: isSel ? Colors.black : Colors.white,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11.5,
                                    ),
                                    onSelected: (val) {
                                      setState(() => _selectedGenre = val ? g : "All");
                                      if (val && g != "All") {
                                        _api.search(g).then((res) {
                                          if (mounted) setState(() => _items = res);
                                        });
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        // Year Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedYear,
                              dropdownColor: AppColors.surfaceElevated,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.accent),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              items: _years.map((y) {
                                return DropdownMenuItem(value: y, child: Text(y));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedYear = val);
                              },
                            ),
                          ),
                        ),
                      ],
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
                          : _filteredItems.isEmpty
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
                                  itemCount: _filteredItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredItems[index];
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
