import 'dart:async';
import '../data/models.dart';

class MeshPeerRecord {
  final Peer peer;
  final String bleAddress;
  bool isConnected;
  DateTime lastSeen;

  MeshPeerRecord({
    required this.peer,
    required this.bleAddress,
    this.isConnected = false,
    required this.lastSeen,
  });
}

/// Peer Manager maintaining neighboring nodes, connection states, RSSI, and battery levels.
class MeshPeerManager {
  final Map<String, MeshPeerRecord> _peerRecords = {};
  final _peersController = StreamController<List<Peer>>.broadcast();

  Stream<List<Peer>> get onPeersUpdated => _peersController.stream;

  void addOrUpdatePeer(Peer peer, {String? bleAddress, bool isConnected = false}) {
    final addr = bleAddress ?? 'ble_${peer.fingerprint}';
    _peerRecords[peer.id] = MeshPeerRecord(
      peer: peer,
      bleAddress: addr,
      isConnected: isConnected,
      lastSeen: DateTime.now(),
    );

    _notifyListeners();
  }

  void removePeer(String peerId) {
    _peerRecords.remove(peerId);
    _notifyListeners();
  }

  void setPeerConnectionState(String peerId, bool isConnected) {
    if (_peerRecords.containsKey(peerId)) {
      _peerRecords[peerId]!.isConnected = isConnected;
      _notifyListeners();
    }
  }

  List<Peer> get activePeers => _peerRecords.values.map((r) => r.peer).toList();

  MeshPeerRecord? getPeerRecord(String peerId) => _peerRecords[peerId];

  void _notifyListeners() {
    _peersController.add(activePeers);
  }
}
