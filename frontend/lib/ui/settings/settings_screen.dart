import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_store_service.dart';
import '../../services/p2p_mesh_service.dart';
import '../../services/settings_service.dart';
import '../components/app_toast.dart';
import '../components/liquid_glass.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.6';
  String _buildNumber = '6';
  String? _pingResult;
  bool _isTestingPing = false;

  String _getPlatformLabel() {
    if (kIsWeb) return 'Web Client';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isMacOS) return 'macOS Desktop';
    if (Platform.isLinux) return 'Linux Desktop';
    if (Platform.isAndroid) return 'Android Mobile';
    if (Platform.isIOS) return 'iOS Mobile';
    return 'Desktop Client';
  }

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    P2PMeshService().detectLocalIp();
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

  Future<void> _testCompanionPing(String url) async {
    setState(() {
      _isTestingPing = true;
      _pingResult = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      final cleanUrl = url.replaceAll(RegExp(r'/+$'), '');
      final res = await dio.get('$cleanUrl/api/v1/health');
      stopwatch.stop();
      if (res.statusCode == 200) {
        setState(() {
          _pingResult = 'Online (${stopwatch.elapsedMilliseconds}ms)';
          _isTestingPing = false;
        });
      } else {
        setState(() {
          _pingResult = 'HTTP ${res.statusCode}';
          _isTestingPing = false;
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _pingResult = 'Offline (Check IP/Server)';
        _isTestingPing = false;
      });
    }
  }

  void _showEditUsernameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Text('Edit Peer Display Name', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This name is visible to peers in Watch Parties and Mesh Groups.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0C0E17),
                hintText: 'Enter display name',
                hintStyle: const TextStyle(color: Colors.white30),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await Provider.of<AuthService>(context, listen: false).updateUsername(newName);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!mounted) return;
                AppToast.show(context, 'Display name updated to "$newName"');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditBackendDialog(String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Text('Companion Backend URL', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Go companion server runs locally or on your home PC on port 8080.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '• Windows Desktop: http://127.0.0.1:8080\n• Android on Wi-Fi: http://<PC-LAN-IP>:8080\n• Android Emulator: http://10.0.2.2:8080',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0C0E17),
                hintText: 'http://127.0.0.1:8080',
                hintStyle: const TextStyle(color: Colors.white30),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await LocalStoreService().updateCompanionBackendUrl(newUrl);
                ApiService().updateBaseUrl(newUrl);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!mounted) return;
                AppToast.show(context, 'Backend URL set to $newUrl');
                _testCompanionPing(newUrl);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showCreateCircleDialog() {
    final controller = TextEditingController(text: 'My Watch Circle');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Text('Create Persistent Circle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A Circle groups your devices or close friends so you can connect anytime without server accounts.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0C0E17),
                hintText: 'Circle Name (e.g. Living Room & Mobile)',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final group = await LocalStoreService().createPersistentGroup(name);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!mounted) return;
                AppToast.show(context, 'Circle created: ${group.groupId}', type: ToastType.success);
                Clipboard.setData(ClipboardData(text: group.groupId));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinCircleDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
        title: const Text('Join Circle with Code', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Circle Code shared from your other device or friend.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0C0E17),
                hintText: 'GRP-XXXXXX',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                await LocalStoreService().joinPersistentGroup(code);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!mounted) return;
                AppToast.show(context, 'Joined Circle $code', type: ToastType.success);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final auth = Provider.of<AuthService>(context);
    final localStore = Provider.of<LocalStoreService>(context);
    final mesh = Provider.of<P2PMeshService>(context);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650 || (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

    final peerId = localStore.peerId.isNotEmpty ? localStore.peerId : (auth.userId ?? 'P2P-LOCAL');
    final username = localStore.username.isNotEmpty ? localStore.username : (auth.username ?? 'Viewer');

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
                            'Decentralized Peer-to-Peer & Local Preferences',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. Peer Identity & Local Sovereignty Card
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        username,
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => _showEditUsernameDialog(username),
                                      child: const Padding(
                                        padding: EdgeInsets.all(3),
                                        child: Icon(Icons.edit_rounded, color: AppColors.accent, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Text(
                                          peerId,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: peerId));
                                        AppToast.show(context, 'Peer ID copied to clipboard');
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(3),
                                        child: Icon(Icons.copy_rounded, color: Colors.white54, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Local-First',
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Identity, watch progress, and favorites are 100% private and stored locally on this ${localStore.deviceType}.',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 2. Section: Mesh Network & P2P Topology
                _buildSectionHeader('Mesh Network & Companion Node'),
                const SizedBox(height: 10),
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      // Companion Go Backend URL
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.dns_rounded, color: Colors.blueAccent, size: 20),
                        ),
                        title: const Text('Companion Scraper Backend', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${localStore.companionBackendUrl} ${(_pingResult != null ? "• $_pingResult" : "")}',
                          style: TextStyle(
                            color: _pingResult != null && _pingResult!.startsWith('Online') ? Colors.greenAccent : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: _isTestingPing
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                                  : const Icon(Icons.network_ping_rounded, color: Colors.white60, size: 20),
                              tooltip: 'Ping Backend',
                              onPressed: _isTestingPing ? null : () => _testCompanionPing(localStore.companionBackendUrl),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_suggest_rounded, color: AppColors.accent, size: 20),
                              tooltip: 'Edit Server URL',
                              onPressed: () => _showEditBackendDialog(localStore.companionBackendUrl),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1, indent: 56),

                      // Direct LAN P2P Host Address
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.hub_rounded, color: Colors.purpleAccent, size: 20),
                        ),
                        title: const Text('Direct LAN Host IP', style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          mesh.localIpAddress != null
                              ? '${mesh.localIpAddress}:${localStore.meshDirectPort} (Mesh Code: ${P2PMeshService.encodeIpToCode(mesh.localIpAddress!)})'
                              : 'Detecting local Wi-Fi interface...',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white60, size: 20),
                          tooltip: 'Detect IP',
                          onPressed: () async {
                            final ip = await mesh.detectLocalIp();
                            if (!mounted) return;
                            if (ip != null) {
                              AppToast.show(context, 'Local IP: $ip (Mesh Code: ${P2PMeshService.encodeIpToCode(ip)})');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 3. Section: Persistent Circles (Linked Devices & Friends)
                _buildSectionHeader('Persistent Circles (Device Groupings)'),
                const SizedBox(height: 10),
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Connected Circles',
                            style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.login_rounded, size: 14, color: Colors.white70),
                                label: const Text('Join', style: TextStyle(fontSize: 12, color: Colors.white)),
                                onPressed: () => _showJoinCircleDialog(),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _showCreateCircleDialog(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (localStore.groups.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Colors.white38, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No persistent circles yet. Create one to pair your Windows PC and Android mobile without typing room codes.',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...localStore.groups.map(
                          (g) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.group_rounded, color: AppColors.accent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g.groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                      Text('Code: ${g.groupId} • ${g.peers.length} linked peer(s)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 16),
                                  tooltip: 'Copy Code',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: g.groupId));
                                    AppToast.show(context, 'Circle Code ${g.groupId} copied');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                  tooltip: 'Leave Circle',
                                  onPressed: () => localStore.removePersistentGroup(g.groupId),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 4. Section: Platform Specific Controls
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // 5. Section: Playback Preferences
                _buildSectionHeader('Playback Preferences'),
                const SizedBox(height: 10),
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _buildToggleTile(
                        icon: Icons.sync_rounded,
                        iconColor: AppColors.accent,
                        title: 'Auto-Sync Watch Party',
                        subtitle: 'Automatically micro-adjust video drift within 150ms when watching with friends.',
                        value: settings.autoSyncParty,
                        onChanged: (val) => settings.setAutoSyncParty(val),
                      ),
                      const Divider(color: Colors.white10, height: 1, indent: 56),
                      _buildToggleTile(
                        icon: Icons.subtitles_rounded,
                        iconColor: Colors.amberAccent,
                        title: 'Subtitles by Default',
                        subtitle: 'Automatically load multi-language subtitle tracks when starting anime and movies.',
                        value: settings.subtitlesEnabled,
                        onChanged: (val) => settings.setSubtitlesEnabled(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // App Info & Build Footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Watch2Gether Mesh Edition v$_appVersion (Build $_buildNumber)',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Running on ${_getPlatformLabel()} • Powered by media_kit & Go',
                        style: const TextStyle(color: Colors.white24, fontSize: 11),
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
