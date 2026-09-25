import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../models/history_model.dart';
import '../../models/media_item.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../media/media_overview_modal.dart';
import '../components/liquid_glass.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback onNavigateHome;

  const HistoryScreen({
    super.key,
    required this.onNavigateHome,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  List<WatchHistoryItem> _items = [];
  bool _isLoading = true;
  String? _error;
  int _filterIndex = 0; // 0: All, 1: In Progress, 2: Watched

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _api.getWatchHistory();
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load watch history';
          _isLoading = false;
        });
      }
    }
  }

  List<WatchHistoryItem> get _filteredItems {
    if (_filterIndex == 1) {
      return _items.where((it) => !it.isWatched && it.progressPercent > 0.0).toList();
    } else if (_filterIndex == 2) {
      return _items.where((it) => it.isWatched || it.progressPercent >= 0.90).toList();
    }
    return _items;
  }

  Future<void> _toggleWatched(WatchHistoryItem item) async {
    final newWatched = !item.isWatched;
    final success = await _api.saveWatchHistory(
      mediaId: item.mediaId,
      title: item.title,
      poster: item.poster,
      episodeId: item.episodeId ?? '',
      timestampSeconds: newWatched ? (item.durationSeconds > 0 ? item.durationSeconds : 1) : 0,
      durationSeconds: item.durationSeconds,
      isWatched: newWatched,
    );

    if (success) {
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 84, left: 16, right: 16),
            backgroundColor: const Color(0xFF1E2235),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF334155))),
            content: Text(newWatched ? 'Marked "${item.title}" as Watched ✓' : 'Marked "${item.title}" as Unwatched'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(WatchHistoryItem item) async {
    final success = await _api.deleteWatchHistory(
      mediaId: item.mediaId,
      episodeId: item.episodeId,
    );
    if (success) {
      setState(() {
        _items.removeWhere((i) => i.id == item.id || (i.mediaId == item.mediaId && i.episodeId == item.episodeId));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 84, left: 16, right: 16),
            backgroundColor: const Color(0xFF1E2235),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF334155))),
            content: Text('Removed "${item.title}" from history'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161928),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Text('Clear Watch History?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently remove all watch history records and saved playback positions for your account.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _api.clearAllWatchHistory();
      if (success) {
        setState(() => _items.clear());
      }
    }
  }

  void _openItem(WatchHistoryItem item) {
    // Open media overview modal
    final mediaItem = MediaItem(
      id: item.mediaId,
      title: item.title,
      type: item.episodeId != null ? 'tv' : 'movie',
      poster: item.poster,
      quality: '1080p HD',
      overview: 'Resume from ${item.formattedProgress}',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MediaOverviewModal(item: mediaItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          color: AppColors.accent,
          backgroundColor: AppColors.surfaceElevated,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.history_rounded, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Watch History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              auth.isAuthenticated
                                  ? 'Synced to account (${auth.currentUser?.username ?? "User"})'
                                  : 'Sign in to sync watch history across all devices',
                              style: TextStyle(
                                color: auth.isAuthenticated ? AppColors.accent.withOpacity(0.85) : AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_items.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white60, size: 22),
                          tooltip: 'Clear All History',
                          onPressed: _clearAll,
                        ),
                    ],
                  ),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip('All (${_items.length})', 0),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'In Progress (${_items.where((i) => !i.isWatched && i.progressPercent > 0).length})',
                        1,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Watched (${_items.where((i) => i.isWatched || i.progressPercent >= 0.9).length})',
                        2,
                      ),
                    ],
                  ),
                ),
              ),

              // Body content
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 15)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadHistory,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            'No Watch History Yet',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _filterIndex == 0
                                ? 'Movies and anime episodes you play will automatically appear here with progress bars so you can resume anytime.'
                                : 'No items match the selected filter.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.explore_rounded, size: 18),
                            label: const Text('Discover Movies & Anime', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: widget.onNavigateHome,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 24,
                    8,
                    isMobile ? 12 : 24,
                    90, // Leave room for floating navigation bar
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _filteredItems[index];
                        return _buildHistoryCard(item, isMobile);
                      },
                      childCount: _filteredItems.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.accent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(WatchHistoryItem item, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: LiquidGlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Poster with Progress Bar Overlay
            GestureDetector(
              onTap: () => _openItem(item),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: isMobile ? 86 : 110,
                      height: isMobile ? 120 : 140,
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
                  // Progress indicator on poster
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 5,
                      color: Colors.black45,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: item.progressPercent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: item.isWatched ? Colors.greenAccent : AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Play button overlay on hover/tap
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Information Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (item.isWatched)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.greenAccent, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 10),
                              SizedBox(width: 3),
                              Text('WATCHED', style: TextStyle(color: Colors.greenAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else if (item.progressPercent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.accent, width: 0.8),
                          ),
                          child: Text(
                            '${(item.progressPercent * 100).toInt()}%',
                            style: const TextStyle(color: AppColors.accent, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (item.episodeId != null && item.episodeId!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('SERIES', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.formattedProgress,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                  const SizedBox(height: 10),

                  // Action Buttons Row
                  Row(
                    children: [
                      // Resume Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: Text(
                          item.progressPercent > 0 && !item.isWatched ? 'Resume' : 'Watch',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _openItem(item),
                      ),
                      const SizedBox(width: 8),

                      // Mark as Watched Toggle
                      IconButton(
                        icon: Icon(
                          item.isWatched ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                          color: item.isWatched ? Colors.greenAccent : Colors.white60,
                          size: 20,
                        ),
                        tooltip: item.isWatched ? 'Mark as Unwatched' : 'Mark as Watched',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _toggleWatched(item),
                      ),

                      // Delete from History
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54, size: 19),
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _deleteItem(item),
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
}
