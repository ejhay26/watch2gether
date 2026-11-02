import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' hide SubtitleTrack;
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../models/media_item.dart';
import '../../services/api_service.dart';
import '../../services/settings_service.dart';
import '../components/app_toast.dart';

enum PlayerSettingsTab { quality, subs, servers, speed }

enum ServerStateStatus { idle, loading, failed, active }

class PlayerSettingsModal extends StatefulWidget {
  final Player player;
  final String title;
  final List<Server> servers;
  final Server? currentServer;
  final List<StreamSource> sources;
  final String currentQuality;
  final List<String> availableSubtitles;
  final String currentSubtitle;
  final List<String> availableAudioTracks;
  final String currentAudioTrack;
  final Map<String, ServerStateStatus> serverStatuses;
  final Set<String> favoriteServers;
  final ValueChanged<Server> onSelectServer;
  final ValueChanged<StreamSource> onSelectQuality;
  final ValueChanged<String> onSelectSubtitle;
  final ValueChanged<String> onSelectAudioTrack;
  final ValueChanged<String> onToggleFavoriteServer;
  final Future<void> Function(String fileName, String content) onUploadSubtitle;
  final VoidCallback onClose;
  final PlayerSettingsTab initialTab;

  const PlayerSettingsModal({
    super.key,
    required this.player,
    required this.title,
    required this.servers,
    required this.currentServer,
    required this.sources,
    required this.currentQuality,
    required this.availableSubtitles,
    required this.currentSubtitle,
    required this.availableAudioTracks,
    required this.currentAudioTrack,
    required this.serverStatuses,
    required this.favoriteServers,
    required this.onSelectServer,
    required this.onSelectQuality,
    required this.onSelectSubtitle,
    required this.onSelectAudioTrack,
    required this.onToggleFavoriteServer,
    required this.onUploadSubtitle,
    required this.onClose,
    this.initialTab = PlayerSettingsTab.subs,
  });

  @override
  State<PlayerSettingsModal> createState() => _PlayerSettingsModalState();
}

class _PlayerSettingsModalState extends State<PlayerSettingsModal> {
  late PlayerSettingsTab _activeTab;
  bool _isSearchingOpenSubtitles = false;
  bool _isCustomizingAppearance = false;
  final TextEditingController _subSearchController = TextEditingController();
  List<SubtitleTrack> _openSubResults = [];
  bool _isSearchingSubs = false;
  String _selectedSubLang = 'All';

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _subSearchController.text = widget.title;
  }

  @override
  void dispose() {
    _subSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleUploadSubtitles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final content = await file.xFile.readAsString();

        if (content.isNotEmpty) {
          await widget.onUploadSubtitle(file.name, content);
          if (mounted) {
            AppToast.show(context, 'Loaded custom subtitle: ${file.name}', type: ToastType.success);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to pick subtitle file', type: ToastType.error);
      }
    }
  }

  Future<void> _performOpenSubtitlesSearch() async {
    final query = _subSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearchingSubs = true);
    try {
      final results = await ApiService().searchSubtitles(
        query,
        lang: _selectedSubLang == 'All' ? null : _selectedSubLang.toLowerCase(),
      );
      if (mounted) {
        setState(() {
          _openSubResults = results;
          _isSearchingSubs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingSubs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 410,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: const Color(0xFF16151A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (Player Settings • Customize your viewing experience)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF332008),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.tune_rounded, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Player Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Customize your viewing experience',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.onClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar [Quality] [Subs] [Servers] [Speed]
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  _buildTabItem(PlayerSettingsTab.quality, Icons.tv_rounded, 'Quality'),
                  _buildTabItem(PlayerSettingsTab.subs, Icons.chat_bubble_outline_rounded, 'Subs'),
                  _buildTabItem(PlayerSettingsTab.servers, Icons.dns_outlined, 'Servers'),
                  _buildTabItem(PlayerSettingsTab.speed, Icons.speed_rounded, 'Speed'),
                ],
              ),
            ),

            // Tab Content Area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(PlayerSettingsTab tab, IconData icon, String label) {
    final isSelected = _activeTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _activeTab = tab;
            _isSearchingOpenSubtitles = false;
            _isCustomizingAppearance = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.accent : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.accent : Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case PlayerSettingsTab.quality:
        return _buildQualityTab();
      case PlayerSettingsTab.subs:
        if (_isSearchingOpenSubtitles) {
          return _buildOpenSubtitlesSearchView();
        }
        if (_isCustomizingAppearance) {
          return _buildSubtitleAppearanceView();
        }
        return _buildSubsTab();
      case PlayerSettingsTab.servers:
        return _buildServersTab();
      case PlayerSettingsTab.speed:
        return _buildSpeedTab();
    }
  }

  // --- Quality Tab ---
  Widget _buildQualityTab() {
    final sources = widget.sources;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (sources.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Auto (Stream adaptive bitrate)',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          )
        else
          ...sources.map((src) {
            final isSelected = src.quality == widget.currentQuality;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.accent : Colors.white10,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                dense: true,
                title: Text(
                  src.quality,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13.5,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.accent, size: 18) : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onSelectQuality(src);
                },
              ),
            );
          }),
      ],
    );
  }

  // --- Subs Tab (Matching Screenshot 1) ---
  Widget _buildSubsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Active Subtitle Option (e.g. Off [NO SUBTITLES])
        ...widget.availableSubtitles.map((sub) {
          final isSelected = sub == widget.currentSubtitle;
          final isOff = sub.toLowerCase() == 'off';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF281D0B) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : Colors.white10,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              title: Text(
                sub,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              trailing: isOff
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NO SUBTITLES',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    )
                  : (isSelected
                      ? const Icon(Icons.check_rounded, color: AppColors.accent, size: 18)
                      : null),
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSelectSubtitle(sub);
              },
            ),
          );
        }),

        const SizedBox(height: 6),

        // Upload Subtitles Button
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _handleUploadSubtitles,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: const Row(
              children: [
                Icon(Icons.file_upload_outlined, color: Colors.white70, size: 20),
                SizedBox(width: 12),
                Text(
                  'Upload subtitles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Search OpenSubtitles >
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
            title: const Text(
              'Search OpenSubtitles',
              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
            onTap: () {
              setState(() {
                _isSearchingOpenSubtitles = true;
                _performOpenSubtitlesSearch();
              });
            },
          ),
        ),

        const SizedBox(height: 8),

        // Customize appearance >
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.tune_rounded, color: Colors.white70, size: 18),
            title: const Text(
              'Customize appearance',
              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
            onTap: () {
              setState(() => _isCustomizingAppearance = true);
            },
          ),
        ),
      ],
    );
  }

  // --- Subtitle Search Online View ---
  Widget _buildOpenSubtitlesSearchView() {
    return Column(
      children: [
        // Sub-header with back button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _isSearchingOpenSubtitles = false),
              ),
              const Expanded(
                child: Text(
                  'Search OpenSubtitles',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _subSearchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              hintText: 'Search title...',
              hintStyle: const TextStyle(color: Colors.white38),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded, color: AppColors.accent, size: 18),
                onPressed: _performOpenSubtitlesSearch,
              ),
            ),
            onSubmitted: (_) => _performOpenSubtitlesSearch(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isSearchingSubs
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
              : _openSubResults.isEmpty
                  ? const Center(
                      child: Text(
                        'No subtitles found on OpenSubtitles.',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _openSubResults.length,
                      itemBuilder: (ctx, idx) {
                        final item = _openSubResults[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.subtitles_rounded, color: AppColors.accent, size: 18),
                            title: Text(
                              item.lang,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            subtitle: Text(
                              item.url.contains('proxy') ? 'Verified OpenSubtitles v3' : item.url,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.download_rounded, color: Colors.white60, size: 18),
                            onTap: () {
                              widget.onSelectSubtitle(item.lang);
                              setState(() => _isSearchingOpenSubtitles = false);
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // --- Subtitle Appearance Customize View ---
  Widget _buildSubtitleAppearanceView() {
    final settings = Provider.of<SettingsService>(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _isCustomizingAppearance = false),
              ),
              const Expanded(
                child: Text(
                  'Customize Appearance',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Font Size', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Text('${settings.subtitleFontSize.round()}px', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: settings.subtitleFontSize.clamp(14.0, 32.0),
                min: 14,
                max: 32,
                divisions: 9,
                activeColor: AppColors.accent,
                onChanged: (val) => settings.setSubtitleFontSize(val),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Background Opacity', style: TextStyle(color: Colors.white, fontSize: 13)),
                  Text('${(settings.subtitleBackgroundOpacity * 100).round()}%', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: settings.subtitleBackgroundOpacity.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                divisions: 10,
                activeColor: AppColors.accent,
                onChanged: (val) => settings.setSubtitleBackgroundOpacity(val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Servers Tab (Matching Screenshot 2) ---
  Widget _buildServersTab() {
    final servers = widget.servers;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: servers.length,
      itemBuilder: (ctx, idx) {
        final srv = servers[idx];
        final isSelected = widget.currentServer?.id == srv.id;
        final status = widget.serverStatuses[srv.id] ?? (isSelected ? ServerStateStatus.active : ServerStateStatus.idle);
        final isFav = widget.favoriteServers.contains(srv.id);

        final flag = srv.flag ?? '🇺🇸';
        final audioDesc = srv.audio ?? 'Original audio';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF281D0B) : const Color(0xFF1F1E24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.07),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            leading: Text(
              flag,
              style: const TextStyle(fontSize: 22),
            ),
            title: Text(
              srv.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              audioDesc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == ServerStateStatus.loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                else if (status == ServerStateStatus.failed)
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFF05252),
                    size: 18,
                  ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onToggleFavoriteServer(srv.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? const Color(0xFFF05252) : Colors.white38,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onSelectServer(srv);
            },
          ),
        );
      },
    );
  }

  // --- Speed Tab ---
  Widget _buildSpeedTab() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentRate = widget.player.state.rate;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: speeds.map((speed) {
        final isSelected = (currentRate - speed).abs() < 0.05;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.white10,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            dense: true,
            title: Text(
              speed == 1.0 ? '1.0x (Normal)' : '${speed}x',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.5,
              ),
            ),
            trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.accent, size: 18) : null,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.player.setRate(speed);
              setState(() {});
            },
          ),
        );
      }).toList(),
    );
  }
}
