import 'package:flutter_test/flutter_test.dart';
import 'package:watch2gether/models/user_model.dart';
import 'package:watch2gether/models/media_item.dart';

void main() {
  group('Auth and Media Model Tests', () {
    test('UserModel deserialization test', () {
      final json = {
        'id': 'user_123',
        'username': 'cinephile',
        'email': 'user@example.com',
        'role': 'member',
        'created_at': '2026-09-22T10:00:00Z',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'user_123');
      expect(user.username, 'cinephile');
      expect(user.email, 'user@example.com');
      expect(user.role, 'member');
    });

    test('MediaItem with RatingSource and Duration test', () {
      final json = {
        'id': 'movie_avatar',
        'title': 'Avatar',
        'type': 'movie',
        'poster': 'https://image.tmdb/avatar.jpg',
        'rating': '7.8',
        'rating_source': 'TMDB',
        'duration': '2h 42m',
        'quality': '1080p HD',
      };

      final media = MediaItem.fromJson(json);
      expect(media.title, 'Avatar');
      expect(media.ratingSource, 'TMDB');
      expect(media.duration, '2h 42m');
      expect(media.type, 'movie');
    });
  });
}
