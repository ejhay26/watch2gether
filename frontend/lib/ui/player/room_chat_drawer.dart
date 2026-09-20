import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import '../../models/room_models.dart';
import '../../services/room_service.dart';

class RoomChatDrawer extends StatefulWidget {
  final RoomService roomService;
  final VoidCallback onClose;

  const RoomChatDrawer({
    super.key,
    required this.roomService,
    required this.onClose,
  });

  @override
  State<RoomChatDrawer> createState() => _RoomChatDrawerState();
}

class _RoomChatDrawerState extends State<RoomChatDrawer> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showParticipants = false;

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.roomService.sendChat(text);
      _textController.clear();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _copyRoomCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code $code copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.roomService.state;
    final chat = state?.recentChat ?? [];
    final participants = state?.participants ?? [];
    final roomCode = widget.roomService.currentRoomId ?? '';

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _copyRoomCode(roomCode),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            roomCode,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showParticipants ? Icons.chat : Icons.people_outline,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  tooltip: _showParticipants ? 'Show Chat' : 'Show Participants',
                  onPressed: () {
                    setState(() {
                      _showParticipants = !_showParticipants;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Main body
          Expanded(
            child: _showParticipants
                ? _buildParticipantsList(participants)
                : _buildChatList(chat),
          ),

          // Message Input Field
          if (!_showParticipants)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.accent, size: 20),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(List<Participant> participants) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceElevated,
                child: Text(
                  p.username.isNotEmpty ? p.username[0].toUpperCase() : 'U',
                  style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.username,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
              if (p.isHost)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Text(
                    'HOST',
                    style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatList(List<ChatMessage> chat) {
    if (chat.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet.\nSay hello to the room!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chat.length,
      itemBuilder: (context, index) {
        final msg = chat[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    msg.username,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                msg.message,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}
