import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import '../../models/media_item.dart' hide SubtitleTrack;

class DesktopHUD extends StatelessWidget {
  final bool isVisible;
  final String title;
  final String? subtitle;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final bool isFullscreen;
  final bool isRoom;
  final String? roomCode;
  final int participantCount;
  final bool isChatOpen;
  final bool hasEpisodes;
  final bool isEpisodesOpen;
  final StreamResult? streamResult;
  final String currentQuality;
  final String currentAudioTrack;
  final String currentSubtitle;
  final List<String> availableAudioTracks;
  final List<String> availableSubtitles;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolumeChange;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleChat;
  final VoidCallback? onToggleEpisodes;
  final VoidCallback onBack;
  final VoidCallback? onCreateRoom;
  final ValueChanged<StreamSource>? onSelectQuality;
  final ValueChanged<String>? onSelectAudioTrack;
  final ValueChanged<String>? onSelectSubtitle;

  const DesktopHUD({
    super.key,
    required this.isVisible,
    required this.title,
    this.subtitle,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.volume,
    required this.isMuted,
    required this.isFullscreen,
    required this.isRoom,
    this.roomCode,
    this.participantCount = 1,
    required this.isChatOpen,
    this.hasEpisodes = false,
    this.isEpisodesOpen = false,
    this.streamResult,
    this.currentQuality = 'Auto',
    this.currentAudioTrack = 'Default',
    this.currentSubtitle = 'Off',
    this.availableAudioTracks = const [],
    this.availableSubtitles = const ['Off'],
    required this.onPlayPause,
    required this.onSeek,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onToggleChat,
    this.onToggleEpisodes,
    required this.onBack,
    this.onCreateRoom,
    this.onSelectQuality,
    this.onSelectAudioTrack,
    this.onSelectSubtitle,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.85),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.92),
              ],
              stops: const [0.0, 0.22, 0.72, 1.0],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: onBack,
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Room Mode or Create Watch Party
                      if (isRoom) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_rounded, color: AppColors.accent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$participantCount online',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              if (roomCode != null) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: roomCode!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Room code copied: $roomCode'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'ROOM: $roomCode',
                                          style: const TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy_rounded, color: AppColors.accent, size: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Chat Drawer Toggle Button
                        IconButton(
                          icon: Icon(
                            isChatOpen ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                            color: isChatOpen ? AppColors.accent : Colors.white,
                            size: 20,
                          ),
                          tooltip: isChatOpen ? 'Close Chat' : 'Open Chat',
                          onPressed: onToggleChat,
                        ),
                      ] else if (isFullscreen) ...[
                        // Solo Mode (Fullscreen only): Button to initiate a room on demand
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated.withOpacity(0.85),
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent, width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.group_add_rounded, size: 16),
                          label: const Text(
                            'Watch Together',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: onCreateRoom,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Controls Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrubber Bar
                    Row(
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: AppColors.accent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppColors.accent,
                              overlayColor: AppColors.accent.withOpacity(0.3),
                            ),
                            child: Slider(
                              value: duration.inMilliseconds > 0
                                  ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                                  : 0.0,
                              onChanged: (percent) {
                                final targetMs = (percent * duration.inMilliseconds).toInt();
                                onSeek(Duration(milliseconds: targetMs));
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Controls Row
                    Row(
                      children: [
                        // Play/Pause
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: onPlayPause,
                        ),

                        // Rewind 5s (updated from 10s)
                        IconButton(
                          icon: const Icon(Icons.replay_5_rounded, color: Colors.white70, size: 20),
                          tooltip: 'Rewind 5s',
                          onPressed: () {
                            final target = position - const Duration(seconds: 5);
                            onSeek(target < Duration.zero ? Duration.zero : target);
                          },
                        ),

                        // Fast Forward 5s (updated from 10s)
                        IconButton(
                          icon: const Icon(Icons.forward_5_rounded, color: Colors.white70, size: 20),
                          tooltip: 'Fast Forward 5s',
                          onPressed: () {
                            final target = position + const Duration(seconds: 5);
                            onSeek(target > duration ? duration : target);
                          },
                        ),

                        // Volume Slider (Expanded from 75px to 140px width)
                        IconButton(
                          icon: Icon(
                            isMuted || volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: isMuted ? 'Unmute' : 'Mute',
                          onPressed: onToggleMute,
                        ),
                        SizedBox(
                          width: 140, // Wider volume slider
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: AppColors.surfaceBorder,
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: isMuted ? 0.0 : volume,
                              onChanged: onVolumeChange,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Seasons & Episodes Button (if series/anime)
                        if (hasEpisodes && onToggleEpisodes != null)
                          IconButton(
                            icon: Icon(
                              Icons.video_library_rounded,
                              color: isEpisodesOpen ? AppColors.accent : Colors.white,
                              size: 20,
                            ),
                            tooltip: isEpisodesOpen ? 'Close Episodes' : 'Seasons & Episodes',
                            onPressed: onToggleEpisodes,
                          ),

                        // Audio Dub / Track Selector
                        PopupMenuButton<String>(
                          tooltip: 'Audio Dub / Languages',
                          icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 20),
                          color: AppColors.surfaceElevated,
                          elevation: 8,
                          position: PopupMenuPosition.over,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.surfaceBorder)),
                          constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                          itemBuilder: (ctx) {
                            final tracks = availableAudioTracks.isNotEmpty
                                ? availableAudioTracks
                                : ['Audio 1: English (Stereo)', 'Audio 2: Multi-Audio'];
                            return tracks.map((track) {
                              final isSelected = track == currentAudioTrack || (currentAudioTrack == 'Default' && track.contains('1'));
                              return PopupMenuItem<String>(
                                value: track,
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check : Icons.volume_up_outlined,
                                      size: 16,
                                      color: isSelected ? AppColors.accent : Colors.white54,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        track,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.accent : Colors.white,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          onSelected: onSelectAudioTrack,
                        ),

                        // Subtitle Track Selector
                        PopupMenuButton<String>(
                          tooltip: 'Subtitles / Captions',
                          icon: const Icon(Icons.subtitles_rounded, color: Colors.white, size: 20),
                          color: AppColors.surfaceElevated,
                          elevation: 8,
                          position: PopupMenuPosition.over,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.surfaceBorder)),
                          constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                          itemBuilder: (ctx) {
                            final subs = availableSubtitles.isNotEmpty
                                ? availableSubtitles
                                : ['Off', 'English [CC]', 'Spanish (Español)', 'French (Français)', 'German (Deutsch)'];
                            return subs.map((s) {
                              final isSelected = s == currentSubtitle || (currentSubtitle == 'Off' && s == 'Off');
                              return PopupMenuItem<String>(
                                value: s,
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check : Icons.subtitles_outlined,
                                      size: 16,
                                      color: isSelected ? AppColors.accent : Colors.white54,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        s,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.accent : Colors.white,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          onSelected: onSelectSubtitle,
                        ),

                        // Dynamic Quality & Sources Selector
                        if (streamResult != null && streamResult!.sources.isNotEmpty)
                          PopupMenuButton<StreamSource>(
                            tooltip: 'Dynamic Sources & Quality',
                            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                            color: AppColors.surfaceElevated,
                            elevation: 8,
                            position: PopupMenuPosition.over,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.surfaceBorder)),
                            constraints: const BoxConstraints(minWidth: 240, maxWidth: 380),
                            itemBuilder: (ctx) {
                              return streamResult!.sources.map((src) {
                                final isSelected = src.quality == currentQuality || (currentQuality == 'Auto' && src == streamResult!.sources.first);
                                return PopupMenuItem<StreamSource>(
                                  value: src,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check : Icons.hd_outlined,
                                        size: 16,
                                        color: isSelected ? AppColors.accent : Colors.white54,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          src.quality,
                                          style: TextStyle(
                                            color: isSelected ? AppColors.accent : Colors.white,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList();
                            },
                            onSelected: onSelectQuality,
                          ),

                        // Fullscreen Toggle Button
                        IconButton(
                          icon: Icon(
                            isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: isFullscreen ? 'Exit Fullscreen (F / Esc)' : 'Fullscreen (F)',
                          onPressed: onToggleFullscreen,
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
}
