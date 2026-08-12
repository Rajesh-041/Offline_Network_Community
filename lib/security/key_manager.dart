import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Bluetooth Mesh 1.1 Key & Address Manager.
/// Manages Network Keys (NetKey), Application Keys (AppKey), Device Keys (DevKey),
/// 16-bit Unicast Addresses, and IV Indices according to the Bluetooth Mesh Spec 1.1.
class MeshKeyManager {
  static final _random = Random.secure();

  Uint8List _netKey;
  Uint8List _appKey;
  Uint8List _devKey;
  int _unicastAddress; // 16-bit Unicast Address e.g. 0x0001
  int _ivIndex;
  bool _isProvisioned;

  MeshKeyManager({
    Uint8List? netKey,
    Uint8List? appKey,
    Uint8List? devKey,
    int unicastAddress = 0x0001,
    int ivIndex = 0,
    bool isProvisioned = false,
  })  : _netKey = netKey ?? generate128BitKey(),
        _appKey = appKey ?? generate128BitKey(),
        _devKey = devKey ?? generate128BitKey(),
        _unicastAddress = unicastAddress,
        _ivIndex = ivIndex,
        _isProvisioned = isProvisioned;

  static Uint8List generate128BitKey() {
    final key = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      key[i] = _random.nextInt(256);
    }
    return key;
  }

  Uint8List get netKey => _netKey;
  Uint8List get appKey => _appKey;
  Uint8List get devKey => _devKey;
  int get unicastAddress => _unicastAddress;
  int get ivIndex => _ivIndex;
  bool get isProvisioned => _isProvisioned;

  String get unicastAddressHex => '0x${_unicastAddress.toRadixString(16).padLeft(4, '0').toUpperCase()}';

  void updateKeys({
    Uint8List? netKey,
    Uint8List? appKey,
    Uint8List? devKey,
    int? unicastAddress,
    int? ivIndex,
  }) {
    if (netKey != null) _netKey = netKey;
    if (appKey != null) _appKey = appKey;
    if (devKey != null) _devKey = devKey;
    if (unicastAddress != null) _unicastAddress = unicastAddress;
    if (ivIndex != null) _ivIndex = ivIndex;
    _isProvisioned = true;
  }

  void resetKeys() {
    _netKey = generate128BitKey();
    _appKey = generate128BitKey();
    _devKey = generate128BitKey();
    _unicastAddress = 0x0001;
    _ivIndex = 0;
    _isProvisioned = false;
  }

  /// Derive Network ID (NID) 7-bit identifier from NetKey
  int deriveNid() {
    final digest = sha256.convert(_netKey);
    return digest.bytes[0] & 0x7F;
  }

  /// Derive Encryption Key (EK) from NetKey
  Uint8List deriveEncryptionKey() {
    final digest = sha256.convert(utf8.encode('enc_key_${base64Encode(_netKey)}'));
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }

  /// Derive Privacy Key (PK) from NetKey
  Uint8List derivePrivacyKey() {
    final digest = sha256.convert(utf8.encode('priv_key_${base64Encode(_netKey)}'));
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }
}
