class WatchHistoryItem {
  final String id;
  final String userId;
  final String mediaId;
  final String title;
  final String poster;
  final String? episodeId;
  final int timestampSeconds;
  final int durationSeconds;
  final bool isWatched;
  final DateTime? updatedAt;

  const WatchHistoryItem({
    required this.id,
    required this.userId,
    required this.mediaId,
    required this.title,
    this.poster = '',
    this.episodeId,
    this.timestampSeconds = 0,
    this.durationSeconds = 0,
    this.isWatched = false,
    this.updatedAt,
  });

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      mediaId: json['media_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      poster: json['poster'] as String? ?? '',
      episodeId: json['episode_id'] as String?,
      timestampSeconds: json['timestamp_seconds'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      isWatched: json['is_watched'] as bool? ?? false,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'media_id': mediaId,
      'title': title,
      'poster': poster,
      if (episodeId != null) 'episode_id': episodeId,
      'timestamp_seconds': timestampSeconds,
      'duration_seconds': durationSeconds,
      'is_watched': isWatched,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  double get progressPercent {
    if (isWatched) return 1.0;
    if (durationSeconds <= 0) return 0.0;
    final pct = timestampSeconds / durationSeconds;
    return pct.clamp(0.0, 1.0);
  }

  String get formattedProgress {
    if (isWatched) return 'Completed';
    final cur = _formatSec(timestampSeconds);
    final total = _formatSec(durationSeconds);
    return '$cur / $total';
  }

  static String _formatSec(int sec) {
    if (sec <= 0) return '0:00';
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final sStr = s.toString().padLeft(2, '0');
    final h = sec ~/ 3600;
    if (h > 0) {
      final mStr = m.toString().padLeft(2, '0');
      return '$h:$mStr:$sStr';
    }
    return '$m:$sStr';
  }
}
