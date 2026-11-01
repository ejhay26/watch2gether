import 'package:flutter_test/flutter_test.dart';
import 'package:watch2gether/services/local_store_service.dart';
import 'package:watch2gether/services/p2p_mesh_service.dart';
import 'package:watch2gether/services/room_crypto_service.dart';

void main() {
  group('P2P Mesh & IP Code Encoding Tests', () {
    test('encodeIpToCode and decodeCodeToIp roundtrip test', () {
      const testIp = '192.168.1.42';
      final code = P2PMeshService.encodeIpToCode(testIp);
      expect(code.length >= 6, isTrue);

      final decoded = P2PMeshService.decodeCodeToIp(code);
      expect(decoded, testIp);
    });

    test('encodeIpToCode roundtrip for physical LAN IP 192.168.100.6', () {
      const lanIp = '192.168.100.6';
      final code = P2PMeshService.encodeIpToCode(lanIp);
      expect(code, '1HGEKNA');

      final decoded = P2PMeshService.decodeCodeToIp(code);
      expect(decoded, lanIp);
    });

    test('decodeCodeToIp preserves direct IP strings', () {
      const directIp = '192.168.0.105';
      final decoded = P2PMeshService.decodeCodeToIp(directIp);
      expect(decoded, directIp);
    });

    test('isVirtualInterface correctly flags Hyper-V and WSL adapters', () {
      expect(P2PMeshService.isVirtualInterface('vEthernet (Default Switch)'), isTrue);
      expect(P2PMeshService.isVirtualInterface('VirtualBox Host-Only Ethernet Adapter'), isTrue);
      expect(P2PMeshService.isVirtualInterface('VMware Network Adapter VMnet1'), isTrue);
      expect(P2PMeshService.isVirtualInterface('docker0'), isTrue);
      expect(P2PMeshService.isVirtualInterface('Ethernet'), isFalse);
      expect(P2PMeshService.isVirtualInterface('Wi-Fi'), isFalse);
      expect(P2PMeshService.isVirtualInterface('wlan0'), isFalse);
    });

    test('RoomCryptoService AES-256 encryption and decryption roundtrip', () {
      const roomCode = '1HGIKAE';
      final original = {
        'type': 'CHANGE_MEDIA',
        'media_id': 'movie-1234',
        'title': 'Interstellar',
        'stream_url': 'https://cdn.example.com/stream.m3u8',
        'position': 124.5,
        'is_playing': true,
      };

      final encryptedJson = RoomCryptoService.encryptPayload(original, roomCode);
      expect(encryptedJson.contains('w2g_enc'), isTrue);
      expect(encryptedJson.contains('Interstellar'), isFalse); // Confidential!

      final decrypted = RoomCryptoService.decryptPayload(encryptedJson, roomCode);
      expect(decrypted['type'], 'CHANGE_MEDIA');
      expect(decrypted['title'], 'Interstellar');
      expect(decrypted['stream_url'], 'https://cdn.example.com/stream.m3u8');
      expect(decrypted['position'], 124.5);
      expect(decrypted['is_playing'], true);
    });

    test('PersistentGroup model serialization test', () {
      final now = DateTime.now();
      final peer = PersistentPeer(
        id: 'P2P-ABC123',
        name: 'Emmanuel',
        deviceType: 'Windows Desktop',
        lastSeen: now,
      );

      final group = PersistentGroup(
        groupId: 'GRP-TEST99',
        groupName: 'Living Room & Phone',
        secretKey: 'sec_key_1234',
        peers: [peer],
        createdAt: now,
      );

      final json = group.toJson();
      final restored = PersistentGroup.fromJson(json);

      expect(restored.groupId, 'GRP-TEST99');
      expect(restored.groupName, 'Living Room & Phone');
      expect(restored.peers.length, 1);
      expect(restored.peers.first.name, 'Emmanuel');
      expect(restored.peers.first.deviceType, 'Windows Desktop');
    });
  });
}
