import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../services/settings_service.dart';
import '../components/liquid_glass.dart';

class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650 || (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Playback Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                8,
                isMobile ? 16 : 24,
                32,
              ),
              children: [
                // Section 1: Seeking & Gestures
                _buildSectionHeader('Seeking & Gestures'),
                const SizedBox(height: 10),
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.fast_forward_rounded, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Seek Duration',
                                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Double-tap and arrow keys jump ±${settings.seekDurationSeconds} seconds',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '${settings.seekDurationSeconds}s',
                              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Segmented Quick Buttons
                      Row(
                        children: [5, 10, 15, 30].map((dur) {
                          final isSelected = settings.seekDurationSeconds == dur;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  settings.setSeekDurationSeconds(dur);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppColors.accent : Colors.white12,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${dur}s',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.accent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: AppColors.accent,
                          overlayColor: AppColors.accent.withValues(alpha: 0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: settings.seekDurationSeconds.toDouble().clamp(5.0, 30.0),
                          min: 5,
                          max: 30,
                          divisions: 5,
                          onChanged: (val) => settings.setSeekDurationSeconds(val.round()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Section 2: HUD & Control Visibility
                _buildSectionHeader('HUD & Control Visibility'),
                const SizedBox(height: 10),
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.timer_outlined, color: Colors.cyanAccent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Auto-Hide Controls',
                                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  settings.autoHideControlsSeconds > 0
                                      ? 'Controls fade after ${settings.autoHideControlsSeconds} seconds of inactivity'
                                      : 'Controls remain visible until tapped',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              settings.autoHideControlsSeconds > 0 ? '${settings.autoHideControlsSeconds}s' : 'Never',
                              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildHideOption(context, settings, 2.0, '2.0s'),
                          _buildHideOption(context, settings, 3.5, '3.5s'),
                          _buildHideOption(context, settings, 5.0, '5.0s'),
                          _buildHideOption(context, settings, 0.0, 'Never'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.touch_app_rounded, color: Colors.white38, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Background tap toggles controls immediately. Play/pause operates exclusively from the center and bottom-left buttons.',
                              style: TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Section 3: Subtitles Styling & Preferences
                _buildSectionHeader('Subtitle Preferences & Appearance'),
                const SizedBox(height: 10),
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildToggleRow(
                        icon: Icons.subtitles_rounded,
                        iconColor: Colors.amberAccent,
                        title: 'Subtitles by Default',
                        subtitle: 'Automatically attach multi-language subtitles when opening streams',
                        value: settings.subtitlesEnabled,
                        onChanged: (val) => settings.setSubtitlesEnabled(val),
                      ),
                      const Divider(color: Colors.white10, height: 16),

                      // Font size slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Font Size', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                          Text('${settings.subtitleFontSize.round()}px', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.amberAccent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.amberAccent,
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: settings.subtitleFontSize.clamp(14.0, 32.0),
                          min: 14,
                          max: 32,
                          divisions: 9,
                          onChanged: (val) => settings.setSubtitleFontSize(val),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Background Opacity
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Background Box Opacity', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                          Text('${(settings.subtitleBackgroundOpacity * 100).round()}%', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.amberAccent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.amberAccent,
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: settings.subtitleBackgroundOpacity.clamp(0.0, 1.0),
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: (val) => settings.setSubtitleBackgroundOpacity(val),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Live Subtitle Preview Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F111A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: settings.subtitleBackgroundOpacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Sample Subtitle Preview [CC]',
                            style: TextStyle(
                              color: Color(settings.subtitleTextColor),
                              fontSize: settings.subtitleFontSize,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(blurRadius: 3, color: Colors.black, offset: Offset(1, 1)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Section 4: Continuous Playback & Engine
                _buildSectionHeader('Continuous Playback & Engine'),
                const SizedBox(height: 10),
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _buildToggleRow(
                        icon: Icons.playlist_play_rounded,
                        iconColor: Colors.greenAccent,
                        title: 'Auto-Play Next Episode',
                        subtitle: 'Automatically launch next TV episode when current video ends',
                        value: settings.autoPlayNextEpisode,
                        onChanged: (val) => settings.setAutoPlayNextEpisode(val),
                      ),
                      const Divider(color: Colors.white10, height: 1, indent: 56),
                      _buildToggleRow(
                        icon: Icons.sync_rounded,
                        iconColor: AppColors.accent,
                        title: 'Auto-Sync Watch Party',
                        subtitle: 'Micro-adjust playback clock drift within 150ms with party peers',
                        value: settings.autoSyncParty,
                        onChanged: (val) => settings.setAutoSyncParty(val),
                      ),
                      if (isDesktop) ...[
                        const Divider(color: Colors.white10, height: 1, indent: 56),
                        _buildToggleRow(
                          icon: Icons.speed_rounded,
                          iconColor: Colors.orangeAccent,
                          title: 'Hardware Acceleration (Direct3D 11)',
                          subtitle: 'Utilize dedicated GPU for stutter-free 1080p 60fps streaming',
                          value: settings.hardwareAccel,
                          onChanged: (val) => settings.setHardwareAccel(val),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHideOption(BuildContext context, SettingsService settings, double val, String label) {
    final isSelected = (settings.autoHideControlsSeconds - val).abs() < 0.05;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.selectionClick();
            settings.setAutoHideControlsSeconds(val);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.cyanAccent : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3)),
      trailing: Switch(
        value: value,
        activeThumbColor: AppColors.accent,
        activeTrackColor: AppColors.accent.withValues(alpha: 0.4),
        onChanged: (val) {
          HapticFeedback.selectionClick();
          onChanged(val);
        },
      ),
    );
  }
}
