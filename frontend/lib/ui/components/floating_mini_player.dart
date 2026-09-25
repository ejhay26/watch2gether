import "package:flutter/material.dart";
import "package:media_kit_video/media_kit_video.dart";
import "../../constants/theme.dart";
import "../../services/playback_service.dart";
import "../player/player_screen.dart";

class FloatingMiniPlayer extends StatelessWidget {
  final PlaybackService playbackService;

  const FloatingMiniPlayer({
    super.key,
    required this.playbackService,
  });

  void _restoreFromFloating(BuildContext context) {
    final player = playbackService.player;
    final controller = playbackService.controller;
    final mediaId = playbackService.mediaId ?? "";
    final epId = playbackService.episodeId;
    final title = playbackService.title ?? "";
    final subtitle = playbackService.subtitle;
    final streamUrl = playbackService.streamUrl ?? "";
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
          initialAudioTrack: playbackService.audioTrack,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!playbackService.isFloating || playbackService.controller == null) {
      return const SizedBox.shrink();
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;
    final double playerWidth = isNarrow ? 260.0 : 330.0;
    final double playerHeight = isNarrow ? 146.0 : 185.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomOffset = bottomPadding + (isNarrow ? 84.0 : 76.0);

    return Positioned(
      bottom: bottomOffset,
      right: isNarrow ? 14 : 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: playerWidth,
        height: playerHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video surface - tap to restore full screen player
            GestureDetector(
              onTap: () => _restoreFromFloating(context),
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
                        playbackService.title ?? "Playing",
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
                      onTap: () => _restoreFromFloating(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
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
                        decoration: const BoxDecoration(
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
                        color: Colors.black.withValues(alpha: 0.7),
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
}
