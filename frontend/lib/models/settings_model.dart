class UserSettingsModel {
  final bool liquidGlass;
  final bool autoSyncParty;
  final bool hardwareAccel;
  final bool subtitlesEnabled;
  final String defaultQuality;

  const UserSettingsModel({
    this.liquidGlass = true,
    this.autoSyncParty = true,
    this.hardwareAccel = true,
    this.subtitlesEnabled = true,
    this.defaultQuality = 'Auto',
  });

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      liquidGlass: json['liquid_glass'] as bool? ?? true,
      autoSyncParty: json['auto_sync_party'] as bool? ?? true,
      hardwareAccel: json['hardware_accel'] as bool? ?? true,
      subtitlesEnabled: json['subtitles_enabled'] as bool? ?? true,
      defaultQuality: json['default_quality'] as String? ?? 'Auto',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'liquid_glass': liquidGlass,
      'auto_sync_party': autoSyncParty,
      'hardware_accel': hardwareAccel,
      'subtitles_enabled': subtitlesEnabled,
      'default_quality': defaultQuality,
    };
  }

  UserSettingsModel copyWith({
    bool? liquidGlass,
    bool? autoSyncParty,
    bool? hardwareAccel,
    bool? subtitlesEnabled,
    String? defaultQuality,
  }) {
    return UserSettingsModel(
      liquidGlass: liquidGlass ?? this.liquidGlass,
      autoSyncParty: autoSyncParty ?? this.autoSyncParty,
      hardwareAccel: hardwareAccel ?? this.hardwareAccel,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      defaultQuality: defaultQuality ?? this.defaultQuality,
    );
  }
}
