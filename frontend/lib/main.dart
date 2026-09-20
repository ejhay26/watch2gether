import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'constants/theme.dart';
import 'services/auth_service.dart';
import 'services/room_service.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => RoomService()),
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
      title: 'Watch2Gether',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: const HomeScreen(),
    );
  }
}
