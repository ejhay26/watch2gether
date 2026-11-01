import 'package:flutter_test/flutter_test.dart';
import 'package:watch2gether/services/local_store_service.dart';
import 'package:watch2gether/services/p2p_mesh_service.dart';

void main() {
  group('P2P Mesh & IP Code Encoding Tests', () {
    test('encodeIpToCode and decodeCodeToIp roundtrip test', () {
      const testIp = '192.168.1.42';
      final code = P2PMeshService.encodeIpToCode(testIp);
      expect(code.length >= 6, isTrue);

      final decoded = P2PMeshService.decodeCodeToIp(code);
      expect(decoded, testIp);
    });

    test('decodeCodeToIp preserves direct IP strings', () {
      const directIp = '192.168.0.105';
      final decoded = P2PMeshService.decodeCodeToIp(directIp);
      expect(decoded, directIp);
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
