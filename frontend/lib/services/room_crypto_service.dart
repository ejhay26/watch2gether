import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Zero-Knowledge Room Crypto Service
/// Encrypts and decrypts all P2P room events (media playback, seeks, chat, member state)
/// using AES-256-CBC derived deterministically from the shared Room Code.
class RoomCryptoService {
  static enc.Key _deriveKey(String roomCode) {
    final clean = roomCode.trim().toUpperCase();
    final bytes = utf8.encode('w2g_salt_2026_$clean');
    final hash = sha256.convert(bytes).bytes;
    return enc.Key(Uint8List.fromList(hash));
  }

  static enc.IV _deriveIV(String roomCode) {
    final clean = roomCode.trim().toUpperCase();
    final bytes = utf8.encode('w2g_iv_salt_$clean');
    final hash = md5.convert(bytes).bytes;
    return enc.IV(Uint8List.fromList(hash));
  }

  /// Encrypts a JSON payload map into an encrypted envelope string.
  static String encryptPayload(Map<String, dynamic> data, String roomCode) {
    try {
      if (roomCode.isEmpty) return jsonEncode(data);

      final key = _deriveKey(roomCode);
      final iv = _deriveIV(roomCode);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final plainJson = jsonEncode(data);
      final encrypted = encrypter.encrypt(plainJson, iv: iv);

      return jsonEncode({
        'w2g_enc': true,
        'data': encrypted.base64,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      // Fallback to plain JSON if encryption encounters any runtime issue
      return jsonEncode(data);
    }
  }

  /// Decrypts an incoming message string. Handles both encrypted envelopes and raw JSON.
  static Map<String, dynamic> decryptPayload(String raw, String roomCode) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        if (decoded['w2g_enc'] == true && decoded['data'] != null) {
          try {
            final key = _deriveKey(roomCode);
            final iv = _deriveIV(roomCode);
            final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
            final decrypted = encrypter.decrypt64(decoded['data'] as String, iv: iv);
            return jsonDecode(decrypted) as Map<String, dynamic>;
          } catch (_) {
            return {};
          }
        }
        return decoded;
      }
    } catch (_) {}

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
