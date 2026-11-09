import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local X25519 keys and AES-GCM for direct chat messages.
class MessageCrypto {
  MessageCrypto(this._prefs);

  static const prefix = 'e2e1.';
  static const _privateKeyKey = 'e2e_private_key';
  static const _publicKeyKey = 'e2e_public_key';

  final SharedPreferences _prefs;
  final _x25519 = X25519();
  final _aes = AesGcm.with256bits();
  SimpleKeyPair? _keyPair;

  static bool isEncrypted(String text) => text.startsWith(prefix);

  Future<String> localPublicKey() async {
    final pair = await _pair();
    final publicKey = await pair.extractPublicKey();
    return base64UrlEncode(publicKey.bytes);
  }

  Future<String> encrypt({
    required String plaintext,
    required String peerPublicKey,
  }) async {
    final secret = await _sharedSecret(peerPublicKey);
    final box = await _aes.encryptString(plaintext, secretKey: secret);
    return '$prefix${base64UrlEncode(box.concatenation())}';
  }

  Future<String> decrypt({
    required String ciphertext,
    required String peerPublicKey,
  }) async {
    if (!isEncrypted(ciphertext)) return ciphertext;
    final secret = await _sharedSecret(peerPublicKey);
    final encoded = ciphertext.substring(prefix.length);
    final box = SecretBox.fromConcatenation(
      base64Url.decode(encoded),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    return _aes.decryptString(box, secretKey: secret);
  }

  Future<SimpleKeyPair> _pair() async {
    final cached = _keyPair;
    if (cached != null) return cached;

    final savedPrivate = _prefs.getString(_privateKeyKey);
    final savedPublic = _prefs.getString(_publicKeyKey);
    if (savedPrivate != null && savedPublic != null) {
      final pair = SimpleKeyPairData(
        base64Url.decode(savedPrivate),
        publicKey: SimplePublicKey(
          base64Url.decode(savedPublic),
          type: KeyPairType.x25519,
        ),
        type: KeyPairType.x25519,
      );
      _keyPair = pair;
      return pair;
    }

    final pair = await _x25519.newKeyPair();
    final privateBytes = await pair.extractPrivateKeyBytes();
    final publicKey = await pair.extractPublicKey();
    await _prefs.setString(_privateKeyKey, base64UrlEncode(privateBytes));
    await _prefs.setString(_publicKeyKey, base64UrlEncode(publicKey.bytes));
    final stored = SimpleKeyPairData(
      privateBytes,
      publicKey: publicKey,
      type: KeyPairType.x25519,
    );
    _keyPair = stored;
    return stored;
  }

  Future<SecretKey> _sharedSecret(String peerPublicKey) async {
    final remote = SimplePublicKey(
      base64Url.decode(peerPublicKey),
      type: KeyPairType.x25519,
    );
    return _x25519.sharedSecretKey(
      keyPair: await _pair(),
      remotePublicKey: remote,
    );
  }
}
