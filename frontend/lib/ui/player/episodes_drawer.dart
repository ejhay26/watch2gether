import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/media_item.dart';

class EpisodesDrawer extends StatelessWidget {
  final List<Episode> episodes;
  final String? currentEpisodeId;
  final int selectedSeason;
  final List<int> availableSeasons;
  final ValueChanged<int> onSelectSeason;
  final ValueChanged<Episode> onSelectEpisode;
  final VoidCallback onClose;
  final bool isLoading;

  const EpisodesDrawer({
    super.key,
    required this.episodes,
    this.currentEpisodeId,
    required this.selectedSeason,
    required this.availableSeasons,
    required this.onSelectSeason,
    required this.onSelectEpisode,
    required this.onClose,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.video_library_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Episodes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Season Selector Dropdown
                if (availableSeasons.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedSeason,
                        dropdownColor: AppColors.surfaceElevated,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        items: availableSeasons.map((s) {
                          return DropdownMenuItem<int>(
                            value: s,
                            child: Text('Season $s'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) onSelectSeason(val);
                        },
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: onClose,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Episodes List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2.5,
                    ),
                  )
                : episodes.isEmpty
                    ? Center(
                        child: Text(
                          'No episodes available',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: episodes.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: AppColors.surfaceBorder,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final ep = episodes[index];
                          final isPlaying = ep.id == currentEpisodeId ||
                              (currentEpisodeId == null && index == 0);

                          return InkWell(
                            onTap: () => onSelectEpisode(ep),
                            child: Container(
                              color: isPlaying ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Number / Icon Box
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isPlaying ? AppColors.accent : AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: isPlaying
                                          ? const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20)
                                          : Text(
                                              '${ep.number}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Title & Overview
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ep.title.isNotEmpty ? ep.title : 'Episode ${ep.number}',
                                                style: TextStyle(
                                                  color: isPlaying ? AppColors.accent : Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isPlaying)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent.withOpacity(0.25),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'PLAYING',
                                                  style: TextStyle(
                                                    color: AppColors.accent,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (ep.overview != null && ep.overview!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            ep.overview!,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.55),
                                              fontSize: 11,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
