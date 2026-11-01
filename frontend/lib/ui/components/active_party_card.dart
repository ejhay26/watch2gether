import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../models/media_item.dart';
import '../../services/api_service.dart';
import '../../services/local_store_service.dart';
import '../../services/room_service.dart';
import '../player/player_screen.dart';
import 'app_toast.dart';
import 'profile_name_modal.dart';

class ActivePartyCard extends StatelessWidget {
  final bool isCompact;

  const ActivePartyCard({super.key, this.isCompact = false});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(context, '$label copied to clipboard!', type: ToastType.success);
  }

  void _joinActiveStream(BuildContext context, RoomService roomService) async {
    final state = roomService.state;
    if (state == null || state.streamUrl.isEmpty) {
      AppToast.show(context, 'No active stream to join yet.', type: ToastType.info);
      return;
    }

    StreamResult? streamRes;
    try {
      final srvId = state.episodeId.isNotEmpty ? state.episodeId : state.mediaId;
      if (srvId.isNotEmpty) {
        final servers = await ApiService().getServers(srvId, title: state.title);
        if (servers.isNotEmpty) {
          streamRes = await ApiService().getSources(servers.first.id, title: state.title);
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: state.title,
          streamUrl: (streamRes != null && streamRes.sources.isNotEmpty)
              ? streamRes.sources.first.url
              : state.streamUrl,
          mediaId: state.mediaId,
          episodeId: state.episodeId,
          initialRoomCode: roomService.currentRoomId,
          streamResult: streamRes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomService = Provider.of<RoomService>(context);
    final localStore = Provider.of<LocalStoreService>(context);

    if (!roomService.isInParty) {
      return const SizedBox.shrink();
    }

    final code = roomService.currentRoomId ?? '------';
    final state = roomService.state;
    final parts = state?.participants ?? [];
    final hasStream = state != null && state.streamUrl.isNotEmpty;
    final hostIp = roomService.hostIpAddress ?? '127.0.0.1';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131726).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasStream ? AppColors.accent.withValues(alpha: 0.6) : Colors.white12,
          width: hasStream ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasStream
                ? AppColors.accent.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Party Header Row
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'WATCH PARTY ACTIVE',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, color: AppColors.accent, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'AES-256',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Room Code & Direct IP Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0E1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROOM CODE',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Copy Code',
                        icon: const Icon(Icons.copy_rounded, color: AppColors.accent, size: 18),
                        onPressed: () => _copy(context, code, 'Room Code'),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'LAN ADDRESS',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$hostIp:8888',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Copy LAN IP',
                        icon: const Icon(Icons.link_rounded, color: Colors.white70, size: 18),
                        onPressed: () => _copy(context, '$hostIp:8888', 'LAN Address'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Live Stream Status Box
                if (hasStream) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'STREAMING NOW',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (state.isPlaying)
                              const Text(
                                'Playing',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              )
                            else
                              const Text(
                                'Paused',
                                style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.title.isNotEmpty ? state.title : 'Media Stream',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text(
                              'JOIN STREAM (SYNCED)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () => _joinActiveStream(context, roomService),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0C16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.movie_outlined, color: Colors.white38, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            roomService.isHost
                                ? 'Pick a film to start playing for everyone in the room.'
                                : 'Waiting for host to select and play a movie...',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // 4. Connected Members List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Members Online (${parts.length})',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.accent,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: Text(
                        'You: ${localStore.username}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => ProfileNameModal.show(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: parts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final p = parts[i];
                      final isMe = p.username == localStore.username;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E111E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isMe ? AppColors.accent.withValues(alpha: 0.3) : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: p.isHost ? AppColors.accent : Colors.white24,
                              child: Text(
                                p.username.isNotEmpty ? p.username[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      p.username,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    const Text(
                                      '(You)',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (p.isHost)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'HOST',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Leave Party Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                    label: const Text('Leave Party', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      roomService.leaveParty();
                      AppToast.show(context, 'Left the watch party', type: ToastType.info);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
