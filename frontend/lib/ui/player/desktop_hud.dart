import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import '../../models/media_item.dart';

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
    required this.participantCount,
    required this.isChatOpen,
    this.streamResult,
    this.currentQuality = 'Auto',
    this.currentAudioTrack = 'Default',
    this.currentSubtitle = 'Off',
    this.availableAudioTracks = const [],
    this.availableSubtitles = const [],
    required this.onPlayPause,
    required this.onSeek,
    required this.onVolumeChange,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onToggleChat,
    required this.onBack,
    this.onCreateRoom,
    this.onSelectQuality,
    this.onSelectAudioTrack,
    this.onSelectSubtitle,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC000000),
                Colors.transparent,
                Colors.transparent,
                Color(0xEE000000),
              ],
              stops: [0.0, 0.2, 0.7, 1.0],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // TOP BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: onBack,
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
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    // Room Indicator or "Watch Together" Button
                    if (isRoom) ...[
                      InkWell(
                        onTap: () {
                          if (roomCode != null) {
                            Clipboard.setData(ClipboardData(text: roomCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Room code $roomCode copied to clipboard!'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.liveIndicator,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ROOM: ${roomCode ?? ""}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy, color: AppColors.textSecondary, size: 14),
                              const SizedBox(width: 8),
                              const Icon(Icons.people_outline, color: AppColors.textSecondary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$participantCount',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          isChatOpen ? Icons.chat : Icons.chat_bubble_outline,
                          color: isChatOpen ? AppColors.accent : Colors.white,
                          size: 20,
                        ),
                        onPressed: onToggleChat,
                      ),
                    ] else if (onCreateRoom != null) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.group_add_rounded, size: 18),
                        label: const Text(
                          'Watch Together',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: onCreateRoom,
                      ),
                    ],
                  ],
                ),
              ),

              // BOTTOM CONTROLS BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrub Bar
                    Row(
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              activeTrackColor: AppColors.accent,
                              inactiveTrackColor: AppColors.surfaceBorder,
                              thumbColor: AppColors.accent,
                              overlayColor: AppColors.accentGlow,
                            ),
                            child: Slider(
                              value: duration.inMilliseconds > 0
                                  ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                                  : 0.0,
                              onChanged: (val) {
                                onSeek(Duration(milliseconds: (val * duration.inMilliseconds).toInt()));
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Controls Row
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: onPlayPause,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 22),
                          onPressed: () {
                            final target = position - const Duration(seconds: 10);
                            onSeek(target < Duration.zero ? Duration.zero : target);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 22),
                          onPressed: () {
                            final target = position + const Duration(seconds: 10);
                            onSeek(target > duration ? duration : target);
                          },
                        ),

                        const SizedBox(width: 16),

                        // Volume Control
                        IconButton(
                          icon: Icon(
                            isMuted || volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: onToggleMute,
                        ),
                        SizedBox(
                          width: 75,
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

                        // Audio Dub / Track Selector
                        PopupMenuButton<String>(
                          tooltip: 'Audio Dub / Languages',
                          icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 20),
                          color: const Color(0xFF1B1E28),
                          itemBuilder: (ctx) {
                            final tracks = availableAudioTracks.isNotEmpty
                                ? availableAudioTracks
                                : ['English (Default)', 'Spanish Dub', 'French Dub', 'German Dub', 'Japanese'];
                            return tracks.map((track) {
                              final isSelected = track == currentAudioTrack || (currentAudioTrack == 'Default' && track.contains('Default'));
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
                                    Text(
                                      track,
                                      style: TextStyle(
                                        color: isSelected ? AppColors.accent : Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
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
                          color: const Color(0xFF1B1E28),
                          itemBuilder: (ctx) {
                            final subs = ['Off', 'English', 'Spanish', 'French', 'German'];
                            return subs.map((s) {
                              final isSelected = s == currentSubtitle;
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
                                    Text(
                                      s,
                                      style: TextStyle(
                                        color: isSelected ? AppColors.accent : Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          onSelected: onSelectSubtitle,
                        ),

                        // Quality / Source Selector
                        if (streamResult != null && streamResult!.sources.isNotEmpty)
                          PopupMenuButton<StreamSource>(
                            tooltip: 'Stream Quality & Sources',
                            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                            color: const Color(0xFF1B1E28),
                            itemBuilder: (ctx) {
                              return streamResult!.sources.map((src) {
                                final isSelected = src.quality == currentQuality;
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
                                      Text(
                                        src.quality,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.accent : Colors.white,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList();
                            },
                            onSelected: onSelectQuality,
                          ),

                        // Fullscreen
                        IconButton(
                          icon: Icon(
                            isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
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
