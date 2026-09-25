import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../services/playback_service.dart";
import "components/floating_mini_player.dart";
import "components/floating_nav_bar.dart";
import "history/history_screen.dart";
import "home_screen.dart";
import "settings/settings_screen.dart";

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Primary screen tabs with preserved state
          IndexedStack(
            index: _currentIndex,
            children: [
              const HomeScreen(),
              HistoryScreen(onNavigateHome: () => setState(() => _currentIndex = 0)),
              const SettingsScreen(),
            ],
          ),

          // Floating Navigation Bottom Bar with optimal bottom offset
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: FloatingNavBar(
                currentIndex: _currentIndex,
                onTap: (idx) => setState(() => _currentIndex = idx),
              ),
            ),
          ),

          // Floating Mini-Player (Persistent across all tabs, search, and navigation, floating above nav bar)
          Consumer<PlaybackService>(
            builder: (context, playbackService, _) {
              return FloatingMiniPlayer(playbackService: playbackService);
            },
          ),
        ],
      ),
    );
  }
}
