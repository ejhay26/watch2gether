import 'package:flutter_test/flutter_test.dart';
import 'package:watch2gether/services/online_room_service.dart';
import 'package:watch2gether/services/room_crypto_service.dart';
import 'package:watch2gether/services/room_service.dart';

void main() {
  group('Online Room Service & Supabase Worldwide Sync Tests', () {
    test('generateRoomCode produces valid uppercase alphanumeric codes', () {
      final code1 = OnlineRoomService.generateRoomCode();
      final code2 = OnlineRoomService.generateRoomCode();

      expect(code1.contains('-'), isTrue);
      expect(code2.contains('-'), isTrue);

      final parts1 = code1.split('-');
      expect(parts1.length, 2);
      expect(parts1[0].length >= 3, isTrue);
      expect(int.tryParse(parts1[1]), isNotNull);
    });

    test('cleanCode normalizes dashes, spaces, and casing', () {
      expect(OnlineRoomService.cleanCode('sky-942'), 'SKY942');
      expect(OnlineRoomService.cleanCode('  NOVA-109  '), 'NOVA109');
      expect(OnlineRoomService.cleanCode('w2g_star_77'), 'W2GSTAR77');
    });

    test('End-to-End Encryption protects telemetry payloads over online relay', () {
      const roomCode = 'SKY-942';
      final playEvent = {
        'type': 'PLAY',
        'position': 45.2,
        'execute_at_ms': 1793520000000,
      };

      final encrypted = RoomCryptoService.encryptPayload(playEvent, roomCode);
      expect(encrypted.contains('w2g_enc'), isTrue);
      expect(encrypted.contains('1793520000000'), isFalse); // Total confidentiality

      final decrypted = RoomCryptoService.decryptPayload(encrypted, roomCode);
      expect(decrypted['type'], 'PLAY');
      expect(decrypted['position'], 45.2);
      expect(decrypted['execute_at_ms'], 1793520000000);
    });

    test('Wrong room code cannot decrypt online telemetry', () {
      const roomCode = 'SKY-942';
      const wrongCode = 'MARS-100';

      final secretChat = {
        'type': 'CHAT',
        'message': 'Meeting at Tokyo Tower',
      };

      final encrypted = RoomCryptoService.encryptPayload(secretChat, roomCode);
      final decrypted = RoomCryptoService.decryptPayload(encrypted, wrongCode);
      expect(decrypted.isEmpty, isTrue); // Decryption fails safely without leaking plaintext
    });

    test('RoomService starts in onlineCloud engine mode by default', () {
      final roomService = RoomService();
      expect(roomService.activeEngine, RoomEngineMode.onlineCloud);
      expect(roomService.isOnlineCloud, isTrue);
      expect(roomService.isInParty, isFalse);
    });
  });
}
