import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _storage = const FlutterSecureStorage();
  final _algorithm = X25519();
  final _cipher = AesGcm.with256bits();

  SimpleKeyPair? _keyPair;
  SecretKey? _selfSymmetricKey;

  /// Returns the base64 encoded public key
  Future<String?> getPublicKey() async {
    if (_keyPair == null) return null;
    final pubKey = await _keyPair!.extractPublicKey();
    return base64Encode(pubKey.bytes);
  }

  /// Initialize keys from a 16-word phrase, save private key to storage, and return public key.
  Future<String> initializeKeysFromPhrase(String phrase) async {
    // 1. Convert phrase to seed
    final seed = bip39.mnemonicToSeed(phrase.trim());
    
    // 2. Use the first 32 bytes of the seed for the X25519 private key
    final privateKeyBytes = seed.sublist(0, 32);
    
    // 3. Create key pair
    _keyPair = await _algorithm.newKeyPairFromSeed(privateKeyBytes);
    
    // 4. Save to secure storage (base64 encoded)
    final privateKey = await _keyPair!.extractPrivateKeyBytes();
    await _storage.write(key: 'e2ee_private_key', value: base64Encode(privateKey));

    // Derive self-encryption symmetric key
    final selfKeyBytes = sha256.convert(privateKey).bytes.sublist(0, 32);
    _selfSymmetricKey = SecretKey(selfKeyBytes);

    // 5. Return Public Key
    final pubKey = await _keyPair!.extractPublicKey();
    return base64Encode(pubKey.bytes);
  }

  /// Load existing key from secure storage (e.g. on app launch)
  Future<bool> loadKeysFromStorage() async {
    final privKeyB64 = await _storage.read(key: 'e2ee_private_key');
    if (privKeyB64 == null) return false;

    try {
      final privateKeyBytes = base64Decode(privKeyB64);
      _keyPair = await _algorithm.newKeyPairFromSeed(privateKeyBytes);
      
      final selfKeyBytes = sha256.convert(privateKeyBytes).bytes.sublist(0, 32);
      _selfSymmetricKey = SecretKey(selfKeyBytes);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear keys (e.g. on logout)
  Future<void> clearKeys() async {
    await _storage.delete(key: 'e2ee_private_key');
    _keyPair = null;
    _selfSymmetricKey = null;
  }

  /// Derive shared secret with a partner using their public key
  Future<SecretKey> deriveSharedSecret(String partnerPublicKeyB64) async {
    if (_keyPair == null) throw Exception("Local keypair not initialized");
    
    final partnerPubKeyBytes = base64Decode(partnerPublicKeyB64);
    final partnerPublicKey = SimplePublicKey(partnerPubKeyBytes, type: KeyPairType.x25519);

    return await _algorithm.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: partnerPublicKey,
    );
  }

  /// Encrypt a string payload using the shared secret
  Future<String> encryptPayload(String text, SecretKey sharedSecret) async {
    final message = utf8.encode(text);
    final secretBox = await _cipher.encrypt(
      message,
      secretKey: sharedSecret,
    );
    
    // Format: base64(nonce + mac + cipherText)
    final bb = BytesBuilder();
    bb.add(secretBox.nonce);
    bb.add(secretBox.mac.bytes);
    bb.add(secretBox.cipherText);
    
    return base64Encode(bb.toBytes());
  }

  /// Decrypt a string payload using the shared secret
  Future<String> decryptPayload(String encryptedB64, SecretKey sharedSecret) async {
    final data = base64Decode(encryptedB64);
    
    // AesGcm default nonce is 12 bytes, mac is 16 bytes
    if (data.length < 28) throw Exception("Invalid encrypted payload length");

    final nonce = data.sublist(0, 12);
    final macBytes = data.sublist(12, 28);
    final cipherText = data.sublist(28);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearText = await _cipher.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );

    return utf8.decode(clearText);
  }

  /// Encrypt a string specifically for self-storage (e.g. Profile data)
  Future<String> encryptSelf(String text) async {
    if (_selfSymmetricKey == null) throw Exception("Self key not initialized");
    return await encryptPayload(text, _selfSymmetricKey!);
  }

  /// Decrypt a string self-storage
  Future<String> decryptSelf(String encryptedB64) async {
    if (_selfSymmetricKey == null) throw Exception("Self key not initialized");
    return await decryptPayload(encryptedB64, _selfSymmetricKey!);
  }
}
