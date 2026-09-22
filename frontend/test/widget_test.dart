import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch2gether/constants/theme.dart';
import 'package:watch2gether/models/media_item.dart';
import 'package:watch2gether/models/room_models.dart';
import 'package:watch2gether/ui/player/desktop_hud.dart';

void main() {
  test('MediaItem deserialization test', () {
    final json = {
      'id': 'test-1',
      'title': 'Test Movie',
      'type': 'movie',
      'poster': 'https://img.test/p.jpg',
      'quality': '4K HDR',
      'duration': '2h 10m',
    };

    final item = MediaItem.fromJson(json);
    expect(item.id, 'test-1');
    expect(item.title, 'Test Movie');
    expect(item.quality, '4K HDR');
  });

  test('RoomStateData deserialization test', () {
    final json = {
      'room_id': 'ABC123',
      'host_id': 'user-1',
      'media_id': 'demo-sintel',
      'title': 'Sintel',
      'stream_url': 'https://stream.test/m3u8',
      'playback_position': 120.5,
      'is_playing': true,
      'participants': [
        {'id': 'user-1', 'username': 'Alice', 'is_host': true}
      ],
      'recent_chat': [],
    };

    final state = RoomStateData.fromJson(json);
    expect(state.roomId, 'ABC123');
    expect(state.isPlaying, true);
    expect(state.playbackPosition, 120.5);
    expect(state.participants.length, 1);
  });

  testWidgets('DesktopHUD widget test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: Scaffold(
          body: DesktopHUD(
            isVisible: true,
            title: 'Sintel 4K',
            subtitle: 'Animation',
            isPlaying: false,
            position: const Duration(minutes: 2, seconds: 15),
            duration: const Duration(minutes: 15),
            volume: 0.8,
            isMuted: false,
            isFullscreen: false,
            isRoom: true,
            roomCode: 'XYZ789',
            participantCount: 3,
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

    // Verify Title and Room Code are displayed
    expect(find.text('Sintel 4K'), findsOneWidget);
    expect(find.text('ROOM: XYZ789'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
    expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
  });
}
