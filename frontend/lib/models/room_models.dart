class Participant {
  final String id;
  final String username;
  final bool isHost;

  Participant({
    required this.id,
    required this.username,
    required this.isHost,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] ?? '',
      username: json['username'] ?? 'Anonymous',
      isHost: json['is_host'] ?? false,
    );
  }
}

class ChatMessage {
  final String id;
  final String userId;
  final String username;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      username: json['username'] ?? 'User',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class RoomStateData {
  final String roomId;
  final String hostId;
  final String mediaId;
  final String title;
  final String streamUrl;
  final String episodeId;
  final double playbackPosition;
  final bool isPlaying;
  final List<Participant> participants;
  final List<ChatMessage> recentChat;
  final DateTime lastUpdated;

  RoomStateData({
    required this.roomId,
    required this.hostId,
    required this.mediaId,
    required this.title,
    required this.streamUrl,
    required this.episodeId,
    required this.playbackPosition,
    required this.isPlaying,
    required this.participants,
    required this.recentChat,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  double get currentPosition {
    if (!isPlaying) return playbackPosition;
    final elapsedSec = DateTime.now().difference(lastUpdated).inMilliseconds / 1000.0;
    return playbackPosition + elapsedSec;
  }

  RoomStateData copyWith({
    String? roomId,
    String? hostId,
    String? mediaId,
    String? title,
    String? streamUrl,
    String? episodeId,
    double? playbackPosition,
    bool? isPlaying,
    List<Participant>? participants,
    List<ChatMessage>? recentChat,
    DateTime? lastUpdated,
  }) {
    return RoomStateData(
      roomId: roomId ?? this.roomId,
      hostId: hostId ?? this.hostId,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      streamUrl: streamUrl ?? this.streamUrl,
      episodeId: episodeId ?? this.episodeId,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      participants: participants ?? this.participants,
      recentChat: recentChat ?? this.recentChat,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory RoomStateData.fromJson(Map<String, dynamic> json) {
    final rawParts = (json['participants'] as List<dynamic>?) ?? [];
    final rawChat = (json['recent_chat'] as List<dynamic>?) ?? [];

    return RoomStateData(
      roomId: json['room_id'] ?? '',
      hostId: json['host_id'] ?? '',
      mediaId: json['media_id'] ?? '',
      title: json['title'] ?? '',
      streamUrl: json['stream_url'] ?? '',
      episodeId: json['episode_id'] ?? '',
      playbackPosition: (json['playback_position'] as num?)?.toDouble() ?? 0.0,
      isPlaying: json['is_playing'] ?? false,
      participants: rawParts.map((e) => Participant.fromJson(e)).toList(),
      recentChat: rawChat.map((e) => ChatMessage.fromJson(e)).toList(),
      lastUpdated: DateTime.now(),
    );
  }
}
