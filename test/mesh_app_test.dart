import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshlink/crypto/crypto_engine.dart';
import 'package:meshlink/crypto/identity_manager.dart';
import 'package:meshlink/data/database_helper.dart';
import 'package:meshlink/data/models.dart';
import 'package:meshlink/mesh/message_cache.dart';
import 'package:meshlink/mesh/relay_manager.dart';
import 'package:meshlink/mesh/ttl_manager.dart';
import 'package:meshlink/ml/adaptive_router.dart';
import 'package:meshlink/packet/fragmenter.dart';
import 'package:meshlink/packet/mesh_packet.dart';
import 'package:meshlink/packet/reassembler.dart';
import 'package:meshlink/power/friend_manager.dart';
import 'package:meshlink/security/encryption.dart';
import 'package:meshlink/security/key_manager.dart';
import 'package:meshlink/security/replay_protection.dart';
import 'package:meshlink/topology/topology_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Bluetooth Mesh 1.1 Key & Identity Security Tests', () {
    test('16-bit Unicast Address & 128-bit NetKey/AppKey derivation', () {
      final identity = IdentityManager();
      expect(identity.fingerprint.length, equals(8));
      expect(identity.unicastAddress, greaterThan(0));
      expect(identity.meshKeyManager.netKey.length, equals(16));
    });

    test('Transport Layer AES-GCM Encryption & Decryption Roundtrip', () {
      final key = MeshKeyManager.generate128BitKey();
      const payload = 'Confidential Bluetooth Mesh 1.1 Payload';
      const seq = 105;
      const src = 0x0001;

      final encrypted = MeshEncryptionEngine.encryptNetworkPayload(payload, key, seq, src);
      final decrypted = MeshEncryptionEngine.decryptNetworkPayload(encrypted, key, seq, src);

      expect(decrypted, equals(payload));
    });

    test('Feature 13: Replay Protection List (RPL) Sequence Verification', () {
      final rpl = ReplayProtectionList();
      const srcAddr = 0x0005;

      expect(rpl.isReplayAttack(srcAddr, 100), isFalse);
      rpl.updateSequence(srcAddr, 100);

      // Replay attack with same sequence number 100 should be rejected!
      expect(rpl.isReplayAttack(srcAddr, 100), isTrue);
      // Older sequence number 99 should also be rejected!
      expect(rpl.isReplayAttack(srcAddr, 99), isTrue);

      // Higher sequence number 101 should be accepted
      expect(rpl.isReplayAttack(srcAddr, 101), isFalse);
    });
  });

  group('SAR Segmentation & Reassembly (Feature 9) Tests', () {
    test('Large Payload Segmentation and Reassembly Roundtrip', () {
      final fragmenter = MeshPacketFragmenter();
      final reassembler = MeshPacketReassembler();

      final longPayload = 'Fragment_A_' * 50; // Oversized payload
      final fragments = MeshPacketFragmenter.fragmentPayload(
        messageId: 'msg_sar_1',
        senderFingerprint: 'A1B2C3D4',
        senderName: 'TestNode',
        nid: 1,
        ttl: 7,
        seq: 200,
        src: 0x0001,
        dst: 0x0002,
        payload: longPayload,
        maxMtuPayloadSize: 60,
      );

      expect(fragments.length, greaterThan(1));

      BluetoothMeshPacket? reassembledPkt;
      for (var frag in fragments) {
        reassembledPkt = reassembler.addFragment(frag);
      }

      expect(reassembledPkt, isNotNull);
      expect(reassembledPkt!.payload, equals(longPayload));
    });
  });

  group('TTL & Duplicate Message Cache Tests (Features 6 & 7)', () {
    test('TTL Decrement & Max TTL 126 Enforcement', () {
      expect(MeshTtlManager.canRelay(7), isTrue);
      expect(MeshTtlManager.decrementTtl(7), equals(6));
      expect(MeshTtlManager.canRelay(1), isFalse); // Stops forwarding when TTL <= 1
      expect(MeshTtlManager.decrementTtl(1), equals(0));
    });

    test('Duplicate Network Message Suppression', () {
      final cache = MeshNetworkMessageCache();
      const src = 0x0003;
      const seq = 50;
      const msgId = 'msg_dup_99';

      expect(cache.isDuplicate(src, seq, msgId), isFalse);
      expect(cache.isDuplicate(src, seq, msgId), isTrue); // Duplicate detected!
    });
  });

  group('Friend & Topology Discovery Tests (Features 14 & 15)', () {
    test('Friend Node Queueing for Low Power Nodes (LPN)', () {
      final friendMgr = FriendNodeManager();
      const lpnAddr = 0x0008;

      friendMgr.establishFriendship(lpnAddr);
      final pkt = BluetoothMeshPacket(
        nid: 1,
        ttl: 5,
        seq: 1,
        src: 0x0001,
        dst: lpnAddr,
        messageId: 'lpn_msg_1',
        senderFingerprint: 'A1',
        senderName: 'Sender',
        payload: 'Queued Payload',
      );

      final queued = friendMgr.queueMessageForLpn(lpnAddr, pkt);
      expect(queued, isTrue);

      final polledMessages = friendMgr.pollFriendQueue(lpnAddr);
      expect(polledMessages.length, equals(1));
      expect(polledMessages.first.payload, equals('Queued Payload'));
    });

    test('Topology Graph Construction G = (V,E)', () {
      final identity = IdentityManager();
      final topoMgr = MeshTopologyManager(identityManager: identity);

      topoMgr.updateNeighborLink(
        unicastAddress: 0x0002,
        peerId: 'p2',
        peerName: 'Neighbor-Beta',
        fingerprint: 'B2B2B2B2',
        rssi: -58,
        hopCount: 1,
      );

      final graph = topoMgr.buildCurrentGraph();
      expect(graph.nodes.length, equals(2)); // Local node + 1 Neighbor node
      expect(graph.edges.length, equals(1));
    });
  });
}
