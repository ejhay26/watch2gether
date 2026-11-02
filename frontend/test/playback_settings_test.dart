import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch2gether/models/media_item.dart';
import 'package:watch2gether/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SettingsService playback settings default and persistence test', () async {
    final settings = SettingsService();
    // Allow asynchronous constructor load to complete
    await Future.delayed(const Duration(milliseconds: 50));

    // Default seek duration is 10s
    expect(settings.seekDurationSeconds, 10);
    // Default auto-hide controls is 3.5s
    expect(settings.autoHideControlsSeconds, 3.5);
    // Default auto-play next episode is true
    expect(settings.autoPlayNextEpisode, true);
    // Default subtitle font size is 18.0
    expect(settings.subtitleFontSize, 18.0);
    // Default text color is 0xFFFFFFFF
    expect(settings.subtitleTextColor, 0xFFFFFFFF);
    // Default background opacity is 0.5
    expect(settings.subtitleBackgroundOpacity, 0.5);

    // Update settings
    await settings.setSeekDurationSeconds(15);
    expect(settings.seekDurationSeconds, 15);

    await settings.setAutoHideControlsSeconds(5.0);
    expect(settings.autoHideControlsSeconds, 5.0);

    await settings.setSubtitleFontSize(24.0);
    expect(settings.subtitleFontSize, 24.0);

    await settings.setSubtitleTextColor(0xFFFFD700);
    expect(settings.subtitleTextColor, 0xFFFFD700);

    await settings.setSubtitleBackgroundOpacity(0.8);
    expect(settings.subtitleBackgroundOpacity, 0.8);
  });

  test('Server model with flag, audio, badge deserialization test', () {
    final json = {
      'id': 'yoru',
      'name': 'Yoru',
      'quality': '1080p / 4K',
      'url': 'https://stream.provider/yoru',
      'flag': '🇺🇸',
      'audio': 'Original audio. May have 4K',
      'badge': 'Original',
    };

    final server = Server.fromJson(json);
    expect(server.id, 'yoru');
    expect(server.name, 'Yoru');
    expect(server.flag, '🇺🇸');
    expect(server.audio, 'Original audio. May have 4K');
    expect(server.badge, 'Original');
  });
}
