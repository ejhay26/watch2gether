import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'constants/theme.dart';
import 'services/auth_service.dart';
import 'services/room_service.dart';
import 'services/playback_service.dart';
import 'services/settings_service.dart';
import 'ui/main_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(800, 500),
        center: true,
        title: 'WatchHub',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => RoomService()),
        ChangeNotifierProvider(create: (_) => PlaybackService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
      ],
      child: const Watch2GetherApp(),
    ),
  );
}

class Watch2GetherApp extends StatelessWidget {
  const Watch2GetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WatchHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: const MainNavigationShell(),
    );
  }
}
