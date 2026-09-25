import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../auth/auth_modal.dart';
import '../components/liquid_glass.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.2';
  String _buildNumber = '3';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() {
          _appVersion = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final auth = Provider.of<AuthService>(context);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                16,
                isMobile ? 16 : 24,
                isDesktop ? 88 : 96,
              ),
              children: [
                // Page Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.tune_rounded, color: AppColors.accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            'Preferences synchronized across your devices',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Account / Cloud Sync Card
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          auth.isAuthenticated && (auth.currentUser?.username.isNotEmpty ?? false)
                              ? auth.currentUser!.username.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.isAuthenticated ? (auth.currentUser?.username ?? 'Logged In') : 'Guest Session',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.isAuthenticated
                                  ? (auth.currentUser?.email ?? 'Settings persistently saved to cloud')
                                  : 'Log in to store settings and history across any device',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!auth.isAuthenticated)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => AuthModal.show(context),
                          child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 20),
                          tooltip: 'Sign Out',
                          onPressed: () => auth.logout(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // --- SECTION: APPEARANCE & LIQUID GLASS ---
                _buildSectionHeader('Appearance & Aesthetics'),
                const SizedBox(height: 10),

                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.blur_on_rounded, color: Colors.cyanAccent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apple Liquid Glass',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Crystalline visionOS optics with neutral Gaussian backdrop blur and precision specular edge highlight.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: settings.liquidGlass,
                            activeColor: AppColors.accent,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              settings.setLiquidGlass(val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: settings.liquidGlass
                              ? Colors.cyanAccent.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: settings.liquidGlass
                                ? Colors.cyanAccent.withValues(alpha: 0.25)
                                : Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              settings.liquidGlass ? 'Liquid Glass Active (visionOS Crystal)' : 'Standard Obsidian Solid Dark',
                              style: TextStyle(
                                color: settings.liquidGlass ? Colors.cyanAccent : Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              settings.liquidGlass ? Icons.auto_awesome_rounded : Icons.crop_square_rounded,
                              color: settings.liquidGlass ? Colors.cyanAccent : Colors.white38,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // --- SECTION: PLATFORM SPECIFIC CONTROLS ---
                if (isDesktop) ...[
                  _buildSectionHeader('Desktop & Display Options'),
                  const SizedBox(height: 10),
                  LiquidGlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _buildToggleTile(
                          icon: Icons.speed_rounded,
                          iconColor: Colors.orangeAccent,
                          title: 'Hardware Acceleration (Direct3D 11 GPU)',
                          subtitle: 'Utilize dedicated GPU hardware decoding for stutter-free 1080p 60fps streaming.',
                          value: settings.hardwareAccel,
                          onChanged: (val) => settings.setHardwareAccel(val),
                        ),
                        const Divider(color: Colors.white10, height: 1, indent: 56),
                        _buildToggleTile(
                          icon: Icons.picture_in_picture_alt_rounded,
                          iconColor: Colors.blueAccent,
                          title: 'Always on Top during Mini-Player',
                          subtitle: 'Keep playback window floating over other desktop applications when browsing.',
                          value: true,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                if (isMobile) ...[
                  _buildSectionHeader('Mobile Playback Controls'),
                  const SizedBox(height: 10),
                  LiquidGlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _buildToggleTile(
                          icon: Icons.touch_app_rounded,
                          iconColor: Colors.tealAccent,
                          title: 'Double-Tap Gesture Seek',
                          subtitle: 'Double tap left or right halves of the screen to jump backwards or forwards ±5s.',
                          value: true,
                          onChanged: (_) {},
                        ),
                        const Divider(color: Colors.white10, height: 1, indent: 56),
                        _buildToggleTile(
                          icon: Icons.screen_lock_portrait_rounded,
                          iconColor: Colors.amberAccent,
                          title: 'Keep Screen Awake during Playback',
                          subtitle: 'Prevent the display from automatically sleeping or dimming while a video is playing.',
                          value: true,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // --- SECTION: PLAYBACK & SYNC (UNIVERSAL) ---
                _buildSectionHeader('Playback & Sync'),
                const SizedBox(height: 10),

                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _buildToggleTile(
                        icon: Icons.sync_rounded,
                        iconColor: Colors.greenAccent,
                        title: 'Auto-Sync Party Playback',
                        subtitle: 'Synchronize playback timeline and play/pause state when joining watch rooms.',
                        value: settings.autoSyncParty,
                        onChanged: (val) => settings.setAutoSyncParty(val),
                      ),
                      const Divider(color: Colors.white10, height: 1, indent: 56),
                      _buildToggleTile(
                        icon: Icons.subtitles_rounded,
                        iconColor: AppColors.accent,
                        title: 'Enable Subtitles by Default',
                        subtitle: 'Automatically activate English CC or available closed captions.',
                        value: settings.subtitlesEnabled,
                        onChanged: (val) => settings.setSubtitlesEnabled(val),
                      ),
                      const Divider(color: Colors.white10, height: 1, indent: 56),
                      // Video Quality Tile
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.hd_rounded, color: Colors.purpleAccent, size: 20),
                        ),
                        title: const Text('Default Stream Quality', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Target resolution for movies and series', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: DropdownButton<String>(
                          value: settings.defaultQuality,
                          dropdownColor: const Color(0xFF161928),
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                          underline: const SizedBox.shrink(),
                          icon: const Icon(Icons.expand_more_rounded, color: AppColors.accent),
                          items: const [
                            DropdownMenuItem(value: 'Auto', child: Text('Auto (Dynamic)')),
                            DropdownMenuItem(value: '1080p', child: Text('1080p Ultra HD')),
                            DropdownMenuItem(value: '720p', child: Text('720p HD')),
                          ],
                          onChanged: (val) {
                            if (val != null) settings.setDefaultQuality(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // --- SECTION: ABOUT & APP ---
                _buildSectionHeader('About WatchTogether'),
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
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('WatchTogether Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                                Text('Version $_appVersion (Build $_buildNumber) • ${isDesktop ? "Windows Desktop" : "Android Mobile"}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                            ),
                            child: const Text('UP TO DATE', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Direct 1080p master video streaming, synchronized party playback, visionOS crystal glass design, and persistent watch history.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
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
        activeColor: AppColors.accent,
        onChanged: (val) {
          HapticFeedback.selectionClick();
          onChanged(val);
        },
      ),
    );
  }
}
