class UserSettingsModel {
  final bool liquidGlass;
  final bool autoSyncParty;
  final bool hardwareAccel;
  final bool subtitlesEnabled;
  final String defaultQuality;
  final int seekDurationSeconds;
  final double autoHideControlsSeconds;
  final bool autoPlayNextEpisode;
  final double subtitleFontSize;
  final int subtitleTextColor;
  final double subtitleBackgroundOpacity;

  const UserSettingsModel({
    this.liquidGlass = true,
    this.autoSyncParty = true,
    this.hardwareAccel = true,
    this.subtitlesEnabled = true,
    this.defaultQuality = 'Auto',
    this.seekDurationSeconds = 10,
    this.autoHideControlsSeconds = 3.5,
    this.autoPlayNextEpisode = true,
    this.subtitleFontSize = 18.0,
    this.subtitleTextColor = 0xFFFFFFFF,
    this.subtitleBackgroundOpacity = 0.5,
  });

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      liquidGlass: json['liquid_glass'] as bool? ?? true,
      autoSyncParty: json['auto_sync_party'] as bool? ?? true,
      hardwareAccel: json['hardware_accel'] as bool? ?? true,
      subtitlesEnabled: json['subtitles_enabled'] as bool? ?? true,
      defaultQuality: json['default_quality'] as String? ?? 'Auto',
      seekDurationSeconds: json['seek_duration_seconds'] as int? ?? 10,
      autoHideControlsSeconds: (json['auto_hide_controls_seconds'] as num?)?.toDouble() ?? 3.5,
      autoPlayNextEpisode: json['auto_play_next_episode'] as bool? ?? true,
      subtitleFontSize: (json['subtitle_font_size'] as num?)?.toDouble() ?? 18.0,
      subtitleTextColor: json['subtitle_text_color'] as int? ?? 0xFFFFFFFF,
      subtitleBackgroundOpacity: (json['subtitle_background_opacity'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'liquid_glass': liquidGlass,
      'auto_sync_party': autoSyncParty,
      'hardware_accel': hardwareAccel,
      'subtitles_enabled': subtitlesEnabled,
      'default_quality': defaultQuality,
      'seek_duration_seconds': seekDurationSeconds,
      'auto_hide_controls_seconds': autoHideControlsSeconds,
      'auto_play_next_episode': autoPlayNextEpisode,
      'subtitle_font_size': subtitleFontSize,
      'subtitle_text_color': subtitleTextColor,
      'subtitle_background_opacity': subtitleBackgroundOpacity,
    };
  }

  UserSettingsModel copyWith({
    bool? liquidGlass,
    bool? autoSyncParty,
    bool? hardwareAccel,
    bool? subtitlesEnabled,
    String? defaultQuality,
    int? seekDurationSeconds,
    double? autoHideControlsSeconds,
    bool? autoPlayNextEpisode,
    double? subtitleFontSize,
    int? subtitleTextColor,
    double? subtitleBackgroundOpacity,
  }) {
    return UserSettingsModel(
      liquidGlass: liquidGlass ?? this.liquidGlass,
      autoSyncParty: autoSyncParty ?? this.autoSyncParty,
      hardwareAccel: hardwareAccel ?? this.hardwareAccel,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      seekDurationSeconds: seekDurationSeconds ?? this.seekDurationSeconds,
      autoHideControlsSeconds: autoHideControlsSeconds ?? this.autoHideControlsSeconds,
      autoPlayNextEpisode: autoPlayNextEpisode ?? this.autoPlayNextEpisode,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleTextColor: subtitleTextColor ?? this.subtitleTextColor,
      subtitleBackgroundOpacity: subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
    );
  }
}
