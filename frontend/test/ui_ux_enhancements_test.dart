import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch2gether/constants/theme.dart';
import 'package:watch2gether/models/media_item.dart';
import 'package:watch2gether/ui/components/liquid_glass.dart';
import 'package:watch2gether/ui/components/floating_nav_bar.dart';
import 'package:watch2gether/ui/media/media_overview_modal.dart';
import 'package:watch2gether/ui/player/desktop_hud.dart';

void main() {
  group('UI/UX & Model Serialization Tests', () {
    test('MediaItem toJson and fromJson roundtrip serialization test', () {
      final original = MediaItem(
        id: 'movie-matrix',
        title: 'The Matrix',
        type: 'movie',
        poster: 'https://images.example.com/matrix.jpg',
        banner: 'https://images.example.com/matrix_banner.jpg',
        quality: '4K HDR',
        rating: '8.7',
        ratingSource: 'IMDB',
        year: '1999',
        duration: '2h 16m',
        overview: 'A computer hacker learns about the true nature of reality.',
        genres: ['Action', 'Sci-Fi'],
        seasons: [1],
      );

      final json = original.toJson();
      expect(json['id'], 'movie-matrix');
      expect(json['title'], 'The Matrix');
      expect(json['quality'], '4K HDR');
      expect(json['rating_source'], 'IMDB');
      expect(json['overview'], contains('computer hacker'));
      expect(json['genres'], contains('Sci-Fi'));

      final restored = MediaItem.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.type, original.type);
      expect(restored.rating, original.rating);
      expect(restored.ratingSource, original.ratingSource);
      expect(restored.quality, original.quality);
      expect(restored.year, original.year);
      expect(restored.duration, original.duration);
    });

    test('AppMotion design engineering specifications adhere to heuristics', () {
      // Emil Kowalski & Apple motion rules:
      // Snappy micro-interactions (< 300ms)
      expect(AppMotion.fast.inMilliseconds, lessThanOrEqualTo(200));
      expect(AppMotion.normal.inMilliseconds, lessThanOrEqualTo(300));
      expect(AppMotion.modal.inMilliseconds, lessThanOrEqualTo(300));

      // Ease out curves with smooth deceleration
      expect(AppMotion.easeOut, isA<Cubic>());
      expect(AppMotion.easeDrawer, isA<Cubic>());
    });

    testWidgets('AnimatedPressable scale and tap response test', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedPressable(
                pressedScale: 0.95,
                onTap: () => tapped = true,
                child: const Text('Press Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Press Me'), findsOneWidget);

      // Perform tap gesture
      await tester.tap(find.text('Press Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('LiquidGlassCard translucent material rendering test', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: const Scaffold(
            body: Center(
              child: LiquidGlassCard(
                borderRadius: 20,
                child: Text('Glass Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Glass Content'), findsOneWidget);
    });

    testWidgets('FloatingNavBar responsive width clamping test on mobile', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: FloatingNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MediaOverviewModal mobile responsiveness test', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testItem = MediaItem(
        id: 'interstellar',
        title: 'Interstellar',
        type: 'movie',
        poster: '',
        quality: '4K Ultra HD',
        rating: '8.6',
        ratingSource: 'IMDB',
        year: '2014',
        duration: '2h 49m',
        overview: 'A team of explorers travel through a wormhole in space in an attempt to ensure humanity\'s survival.',
        genres: ['Adventure', 'Drama', 'Sci-Fi'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: MediaOverviewModal(item: testItem),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Interstellar'), findsOneWidget);
      expect(find.text('Play Solo'), findsOneWidget);
      expect(find.text('Watch Together'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DesktopHUD mobile viewport zero-overflow test', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: DesktopHUD(
              isVisible: true,
              title: 'Mobile Stream Test Title Very Long Name That Could Truncate',
              subtitle: '1080p Stream',
              isPlaying: true,
              position: const Duration(minutes: 10),
              duration: const Duration(minutes: 45),
              volume: 1.0,
              isMuted: false,
              isFullscreen: false,
              isRoom: true,
              roomCode: 'MESH99',
              participantCount: 2,
              isChatOpen: false,
              onPlayPause: () {},
              onSeek: (_) {},
              onVolumeChange: (_) {},
              onToggleMute: () {},
              onToggleFullscreen: () {},
              onToggleChat: () {},
              onBack: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Mobile Stream Test'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsWidgets);
      expect(find.byIcon(Icons.forward_5_rounded), findsOneWidget);
      expect(find.byIcon(Icons.replay_5_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
