import '../components/app_toast.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import '../../models/media_item.dart' hide SubtitleTrack;

class DesktopHUD extends StatefulWidget {
  final bool isPartySynced;
  final VoidCallback? onTogglePartySync;
  final bool isVisible;
  final bool isBuffering;
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
  final VoidCallback? onBackgroundTap;

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
    this.isBuffering = false,
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
    this.isPartySynced = true,
    this.onTogglePartySync,
    this.onBackgroundTap,
  });

  @override
  State<DesktopHUD> createState() => _DesktopHUDState();
}

class _DesktopHUDState extends State<DesktopHUD> {
  double? _dragPercent;

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

  void _showMobileSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13151F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Quality tile
                if (widget.streamResult != null && widget.streamResult!.sources.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.tune_rounded, color: AppColors.accent),
                    title: const Text('Video Quality', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(widget.currentQuality, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showQualitySubSheet(context);
                    },
                  ),

                // Audio Dub tile
                ListTile(
                  leading: const Icon(Icons.audiotrack_rounded, color: AppColors.accent),
                  title: const Text('Audio Dub / Language', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(widget.currentAudioTrack, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAudioSubSheet(context);
                  },
                ),

                // Subtitles tile
                ListTile(
                  leading: const Icon(Icons.subtitles_rounded, color: AppColors.accent),
                  title: const Text('Subtitles / Captions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(widget.currentSubtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSubtitleSubSheet(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQualitySubSheet(BuildContext context) {
    if (widget.streamResult == null || widget.streamResult!.sources.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13151F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select Quality', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ...widget.streamResult!.sources.map((src) {
                final isSelected = src.quality == widget.currentQuality || (widget.currentQuality == 'Auto' && src == widget.streamResult!.sources.first);
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: isSelected ? AppColors.accent : Colors.white38,
                  ),
                  title: Text(src.quality, style: TextStyle(color: isSelected ? AppColors.accent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSelectQuality?.call(src);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showAudioSubSheet(BuildContext context) {
    final tracks = widget.availableAudioTracks.isNotEmpty
        ? widget.availableAudioTracks
        : ['Audio 1: English (Stereo)', 'Audio 2: Multi-Audio'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13151F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Select Audio Track', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ...tracks.map((track) {
                  final isSelected = track == widget.currentAudioTrack || (widget.currentAudioTrack == 'Default' && track.contains('1'));
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: isSelected ? AppColors.accent : Colors.white38,
                    ),
                    title: Text(track, style: TextStyle(color: isSelected ? AppColors.accent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onSelectAudioTrack?.call(track);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSubtitleSubSheet(BuildContext context) {
    final subs = widget.availableSubtitles.isNotEmpty
        ? widget.availableSubtitles
        : ['Off', 'English [CC]', 'Spanish', 'French', 'German'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13151F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Select Subtitles', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ...subs.map((s) {
                  final isSelected = s == widget.currentSubtitle || (widget.currentSubtitle == 'Off' && s == 'Off');
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: isSelected ? AppColors.accent : Colors.white38,
                    ),
                    title: Text(s, style: TextStyle(color: isSelected ? AppColors.accent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onSelectSubtitle?.call(s);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPartySynced = widget.isPartySynced;
    final onTogglePartySync = widget.onTogglePartySync;
    final isVisible = widget.isVisible;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final isPlaying = widget.isPlaying;
    final position = widget.position;
    final duration = widget.duration;
    final volume = widget.volume;
    final isMuted = widget.isMuted;
    final isFullscreen = widget.isFullscreen;
    final isRoom = widget.isRoom;
    final roomCode = widget.roomCode;
    final participantCount = widget.participantCount;
    final isChatOpen = widget.isChatOpen;
    final hasEpisodes = widget.hasEpisodes;
    final isEpisodesOpen = widget.isEpisodesOpen;
    final streamResult = widget.streamResult;
    final availableAudioTracks = widget.availableAudioTracks;
    final availableSubtitles = widget.availableSubtitles;
    final onPlayPause = widget.onPlayPause;
    final onSeek = widget.onSeek;
    final onVolumeChange = widget.onVolumeChange;
    final onToggleMute = widget.onToggleMute;
    final onToggleFullscreen = widget.onToggleFullscreen;
    final onToggleChat = widget.onToggleChat;
    final onToggleEpisodes = widget.onToggleEpisodes;
    final onBack = widget.onBack;
    final onCreateRoom = widget.onCreateRoom;
    final onSelectQuality = widget.onSelectQuality;
    final onSelectAudioTrack = widget.onSelectAudioTrack;
    final onSelectSubtitle = widget.onSelectSubtitle;
    final onBackgroundTap = widget.onBackgroundTap;
    final isMobilePlatform = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = isMobilePlatform || screenWidth < 650;

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
              stops: const [0.0, 0.22, 0.70, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gesture Background (Tapping hides/shows HUD or toggles playback)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (onBackgroundTap != null) {
                      onBackgroundTap();
                    } else {
                      onPlayPause();
                    }
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),

              // Concentric Center Play/Pause & Buffering Spinner (Exact Screen & Viewport Center)
              Center(
                child: widget.isBuffering
                    ? Container(
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
                      )
                    : Material(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onPlayPause,
                          child: Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 38,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),

              // Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: isFullscreen,
                bottom: false,
                left: isFullscreen,
                right: isFullscreen,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8.0 : 16.0,
                    vertical: isMobile ? 2.0 : 6.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: onBack,
                        tooltip: 'Back',
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 14.5 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: isMobile ? 11 : 12,
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
                        if (isMobile) ...[
                          // Mobile compact room pill
                          InkWell(
                            onTap: () {
                              if (roomCode != null) {
                                Clipboard.setData(ClipboardData(text: roomCode!));
                                AppToast.show(context, 'Room code copied: $roomCode', type: ToastType.success, duration: const Duration(seconds: 2));
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_alt_rounded, color: AppColors.accent, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$participantCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  if (roomCode != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '• $roomCode',
                                      style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          // Desktop full room badge
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
                                      AppToast.show(context, 'Room code copied: $roomCode', type: ToastType.success, duration: const Duration(seconds: 2));
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
                                  if (onTogglePartySync != null) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: onTogglePartySync,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPartySynced ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isPartySynced ? Colors.greenAccent : Colors.orangeAccent, width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPartySynced ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                                              color: isPartySynced ? Colors.greenAccent : Colors.orangeAccent,
                                              size: 13,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isPartySynced ? 'SYNCED' : 'ALONE',
                                              style: TextStyle(
                                                color: isPartySynced ? Colors.greenAccent : Colors.orangeAccent,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        // Chat Button
                        IconButton(
                          icon: Icon(
                            isChatOpen ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                            color: isChatOpen ? AppColors.accent : Colors.white,
                            size: 20,
                          ),
                          tooltip: isChatOpen ? 'Close Chat' : 'Open Chat',
                          visualDensity: VisualDensity.compact,
                          onPressed: onToggleChat,
                        ),
                      ] else if (isFullscreen) ...[
                        // Solo Mode: Button to initiate a room on demand
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent.withOpacity(0.15),
                            foregroundColor: AppColors.accent,
                            elevation: 0,
                            side: const BorderSide(color: AppColors.accent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 6),
                          ),
                          icon: const Icon(Icons.group_add_rounded, size: 16),
                          label: Text(
                            isMobile ? 'Party' : 'Watch Party',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: onCreateRoom,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

              // Bottom Bar (Progress Bar + Controls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                bottom: isFullscreen,
                left: isFullscreen,
                right: isFullscreen,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8.0 : 16.0,
                    vertical: isMobile ? 0.0 : 4.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seek Bar Row
                      Row(
                        children: [
                          Text(
                            _formatDuration(_dragPercent != null && duration.inMilliseconds > 0
                                ? Duration(milliseconds: (_dragPercent! * duration.inMilliseconds).toInt())
                                : position),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 10.5 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                activeTrackColor: AppColors.accent,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: AppColors.accent,
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                trackShape: const RectangularSliderTrackShape(),
                              ),
                              child: Slider(
                                value: _dragPercent ?? (duration.inMilliseconds > 0
                                    ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                                    : 0.0),
                                onChangeStart: (p) {
                                  setState(() => _dragPercent = p);
                                },
                                onChanged: (p) {
                                  setState(() => _dragPercent = p);
                                },
                                onChangeEnd: (percent) {
                                  final targetMs = (percent * duration.inMilliseconds).toInt();
                                  onSeek(Duration(milliseconds: targetMs));
                                  setState(() => _dragPercent = null);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isMobile ? 10.5 : 12,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Controls Row - Responsive LayoutBuilder (Guarantees 0 Overflow)
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final availW = constraints.maxWidth;
                          final showVolSlider = !isMobilePlatform && availW > 680;
                          final showIndividualMenus = !isMobilePlatform && availW > 560;

                          return Row(
                            children: [
                              // Play/Pause
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: onPlayPause,
                              ),

                              // Rewind 5s
                              IconButton(
                                icon: const Icon(Icons.replay_5_rounded, color: Colors.white70, size: 20),
                                tooltip: 'Rewind 5s',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  final target = position - const Duration(seconds: 5);
                                  onSeek(target < Duration.zero ? Duration.zero : target);
                                },
                              ),

                              // Fast Forward 5s
                              IconButton(
                                icon: const Icon(Icons.forward_5_rounded, color: Colors.white70, size: 20),
                                tooltip: 'Fast Forward 5s',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  final target = position + const Duration(seconds: 5);
                                  onSeek(target > duration ? duration : target);
                                },
                              ),

                              // Volume (Desktop only when space permits)
                              if (!isMobilePlatform) ...[
                                IconButton(
                                  icon: Icon(
                                    isMuted || volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  tooltip: isMuted ? 'Unmute' : 'Mute',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onToggleMute,
                                ),
                                if (showVolSlider)
                                  SizedBox(
                                    width: 110,
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
                              ],

                              const Spacer(),

                              // Seasons & Episodes Button (fullscreen series)
                              if (isFullscreen && hasEpisodes && onToggleEpisodes != null)
                                IconButton(
                                  icon: Icon(
                                    Icons.video_library_rounded,
                                    color: isEpisodesOpen ? AppColors.accent : Colors.white,
                                    size: 20,
                                  ),
                                  tooltip: isEpisodesOpen ? 'Close Episodes' : 'Seasons & Episodes',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onToggleEpisodes,
                                ),

                              // Quick Settings Button (Mobile or constrained width)
                              if (!showIndividualMenus) ...[
                                IconButton(
                                  icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 21),
                                  tooltip: 'Quality & Audio Settings',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showMobileSettingsSheet(context),
                                ),
                              ] else ...[
                            // Desktop: Individual Upward Popup Menus
                            // Audio Dub / Track Selector
                            PopupMenuButton<String>(
                              tooltip: 'Audio Dub / Languages',
                              icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 20),
                              color: AppColors.surfaceElevated,
                              elevation: 8,
                              position: PopupMenuPosition.over,
                              offset: const Offset(0, -220),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.surfaceBorder)),
                              constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                              itemBuilder: (ctx) {
                                final tracks = availableAudioTracks.isNotEmpty
                                    ? availableAudioTracks
                                    : ['Audio 1: English (Stereo)', 'Audio 2: Multi-Audio'];
                                return tracks.map((track) {
                                  final isSelected = track == widget.currentAudioTrack || (widget.currentAudioTrack == 'Default' && track.contains('1'));
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
                              offset: const Offset(0, -220),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.surfaceBorder)),
                              constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                              itemBuilder: (ctx) {
                                final subs = availableSubtitles.isNotEmpty
                                    ? availableSubtitles
                                    : ['Off', 'English [CC]', 'Spanish', 'French', 'German'];
                                return subs.map((s) {
                                  final isSelected = s == widget.currentSubtitle || (widget.currentSubtitle == 'Off' && s == 'Off');
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
                            if (widget.streamResult != null && widget.streamResult!.sources.isNotEmpty)
                              PopupMenuButton<StreamSource>(
                                tooltip: 'Dynamic Sources & Quality',
                                icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                                color: AppColors.surfaceElevated,
                                elevation: 8,
                                position: PopupMenuPosition.over,
                                offset: const Offset(0, -220),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.surfaceBorder)),
                                constraints: const BoxConstraints(minWidth: 240, maxWidth: 380),
                                itemBuilder: (ctx) {
                                  return streamResult!.sources.map((src) {
                                    final isSelected = src.quality == widget.currentQuality || (widget.currentQuality == 'Auto' && src == widget.streamResult!.sources.first);
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
                          ],

                          // Fullscreen Toggle Button - ALWAYS VISIBLE
                          IconButton(
                            icon: Icon(
                              isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: isFullscreen ? 'Exit Fullscreen (F / Esc)' : 'Fullscreen (F)',
                            visualDensity: VisualDensity.compact,
                            onPressed: onToggleFullscreen,
                          ),
                        ],
                      );
                    },
                  ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
