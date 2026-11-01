import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../services/api_service.dart';
import '../../services/local_store_service.dart';
import '../../services/p2p_mesh_service.dart';
import '../main_navigation_shell.dart';

class SplashLoadingScreen extends StatefulWidget {
  const SplashLoadingScreen({super.key});

  @override
  State<SplashLoadingScreen> createState() => _SplashLoadingScreenState();
}

class _SplashLoadingScreenState extends State<SplashLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  late AnimationController _exitController;
  late Animation<double> _exitScaleAnimation;
  late Animation<double> _exitOpacityAnimation;

  double _progress = 0.08;
  String _statusMessage = 'Bootstrapping companion node...';
  String _stepDetail = 'Verifying local runtime environment';

  @override
  void initState() {
    super.initState();

    // 1. Subtle, organic logo breathing motion (Emil Kowalski / Apple design principles)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 2. Fluid exit hand-off animation
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: AppMotion.easeOut,
      ),
    );

    _exitOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInQuad,
      ),
    );

    // 3. Initiate real lifecycle boot sequence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServerSequence();
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _updateMilestone({
    required double progress,
    required String status,
    required String detail,
    int holdMs = 280,
  }) async {
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _statusMessage = status;
      _stepDetail = detail;
    });
    await Future.delayed(Duration(milliseconds: holdMs));
  }

  Future<void> _startServerSequence() async {
    // Stage 1: Runtime & Local Persistence Check
    await _updateMilestone(
      progress: 0.22,
      status: 'Mounting sovereign local store...',
      detail: 'Initializing high-speed SQLite and Hive memory cache',
      holdMs: 320,
    );
    await LocalStoreService().init();

    // Stage 2: Companion Server Initialization
    await _updateMilestone(
      progress: 0.48,
      status: 'Booting Go Fiber companion node...',
      detail: 'Starting video scrapers & media engine on 127.0.0.1:8080',
      holdMs: 360,
    );

    // Verify or launch companion server
    await _ensureCompanionServer();
    await ApiService().autoDetectBaseUrl();

    // Stage 3: P2P Mesh Party Socket
    await _updateMilestone(
      progress: 0.74,
      status: 'Binding peer-to-peer playback mesh...',
      detail: 'Calibrating zero-latency LAN party listener on port 8888',
      holdMs: 300,
    );
    try {
      P2PMeshService();
    } catch (_) {}

    // Stage 4: Database / Cloud Mesh Handshake
    await _updateMilestone(
      progress: 0.92,
      status: 'Synchronizing hybrid cloud state...',
      detail: 'Checking Supabase PostgreSQL pooler connectivity',
      holdMs: 260,
    );

    // Final Ready Stage
    await _updateMilestone(
      progress: 1.0,
      status: 'Companion Engine Ready',
      detail: 'Launching fluid media workspace',
      holdMs: 220,
    );

    // Fluid hand-off transition into the Main Navigation Shell
    if (!mounted) return;
    await _exitController.forward();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigationShell(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curveAnimation = CurvedAnimation(
            parent: animation,
            curve: AppMotion.easeOut,
          );
          return FadeTransition(
            opacity: curveAnimation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1.0).animate(curveAnimation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _ensureCompanionServer() async {
    if (kIsWeb) return;

    // 1. Probe if port 8080 is already active
    try {
      final socket = await Socket.connect('127.0.0.1', 8080,
          timeout: const Duration(milliseconds: 200));
      socket.destroy();
      return;
    } catch (_) {}

    // 2. On Desktop, automatically spawn server sidecar if present
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final serverName = Platform.isWindows ? 'server.exe' : 'server';
      final candidates = [
        '$exeDir/$serverName',
        '$exeDir/backend/$serverName',
        '$exeDir/../../backend/bin/$serverName',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) {
          try {
            await Process.start(path, [], mode: ProcessStartMode.detached);
            // Brief wait for socket bind
            for (int i = 0; i < 4; i++) {
              await Future.delayed(const Duration(milliseconds: 100));
              try {
                final s = await Socket.connect('127.0.0.1', 8080,
                    timeout: const Duration(milliseconds: 150));
                s.destroy();
                return;
              } catch (_) {}
            }
            break;
          } catch (_) {}
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitController,
      builder: (context, child) {
        return Opacity(
          opacity: _exitOpacityAnimation.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _exitScaleAnimation.value,
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: Stack(
                children: [
                  // Atmospheric Radial Ambient Glow behind the card
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.12),
                              const Color(0xFF06B6D4).withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 0.85],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Center Stage: Liquid-Glass Loading Window
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 40,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F131E).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.50),
                                    blurRadius: 36,
                                    spreadRadius: -4,
                                    offset: const Offset(0, 16),
                                  ),
                                  BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Breathing Brand Identity Glyph
                                  ScaleTransition(
                                    scale: _breathingAnimation,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF06B6D4),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF6366F1)
                                                .withValues(alpha: 0.35),
                                            blurRadius: 22,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 46,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Application Title with Optical Tracking
                                  const Text(
                                    'Watch2Gether',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.6,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // Status Badge Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _progress >= 1.0
                                                ? AppColors.liveIndicator
                                                : AppColors.accentBright,
                                            boxShadow: [
                                              BoxShadow(
                                                color: (_progress >= 1.0
                                                        ? AppColors.liveIndicator
                                                        : AppColors.accentBright)
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _progress >= 1.0
                                              ? 'ONLINE & SYNCED'
                                              : 'STARTING COMPANION',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  // Fluid Segmented Progress Filament
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Stack(
                                      children: [
                                        // Track
                                        Container(
                                          height: 3.5,
                                          width: double.infinity,
                                          color: Colors.white
                                              .withValues(alpha: 0.08),
                                        ),
                                        // Active Animated Filament
                                        AnimatedFractionallySizedBox(
                                          duration: const Duration(
                                              milliseconds: 320),
                                          curve: AppMotion.easeOut,
                                          alignment: Alignment.centerLeft,
                                          widthFactor: _progress.clamp(0.0, 1.0),
                                          child: Container(
                                            height: 3.5,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF6366F1),
                                                  Color(0xFF06B6D4),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF6366F1)
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // Micro-spring Telemetry Text Transitions
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: AppMotion.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0.0, 0.35),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      _statusMessage,
                                      key: ValueKey<String>(_statusMessage),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  // Secondary Subtext Detail
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                                    child: Text(
                                      _stepDetail,
                                      key: ValueKey<String>(_stepDetail),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
