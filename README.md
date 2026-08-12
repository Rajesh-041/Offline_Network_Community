# MeshLink - Serverless P2P BLE Mesh Chat & Communication Platform

**MeshLink** is a decentralized, off-grid communication platform built with **Flutter (Dart)**. It enables serverless, peer-to-peer messaging, audio voice notes, location-free emergency SOS broadcasting, and encrypted 1:1 & channel communications over Bluetooth Low Energy (BLE) multi-hop mesh networks.

---

## 🌟 Key Features

* **Zero-Server Cryptographic Identity**: Identity is a locally generated X25519 keypair formatted as an 8-character hex fingerprint. No phone numbers, accounts, or central servers.
* **Multi-Hop Store-and-Forward Mesh**: Nodes act as clients and relays. Packets carry `TTL` and `hopCount`, and LRU deduplication (500 capacity) prevents broadcast loops.
* **End-to-End Encryption**: 1:1 private messages are encrypted using X25519 DH + AES-256-GCM authenticated encryption. Public channels support optional Argon2id password-protected encryption.
* **Tiny ML Adaptive Router** (`/lib/ml/adaptive_router.dart`): Offline lightweight machine learning inference engine evaluating RSSI, delivery success rate, battery level, and hop latency to dynamically predict optimal relay routes.
* **Force-Directed Mesh Map Visualizer** (`/lib/ui/screens/mesh_map_screen.dart`): Interactive CustomPainter visualizer rendering active peer nodes, signal line health colors (green/amber/red), traffic pulse animations, and battery status.
* **Location-Free Emergency SOS Center** (`/lib/ui/screens/sos_screen.dart`): Dedicated SOS panic screen broadcasting high-priority, non-suppressible alert packets with maximum TTL (15 hops).
* **BLE Voice Notes** (`/lib/ui/widgets/voice_recorder_widget.dart`): Record short (<30s) audio clips, compressed and chunked into BLE payload frames.
* **Battery-Aware Duty Cycling**: Automatically reduces BLE scanning window when device battery falls below a configurable threshold (e.g. 20%).
* **3-Second Panic Wipe**: Long-pressing the app logo for 3 seconds purges all local databases, keys, channels, and message history instantly.
* **Encrypted Chat Backups**: Export and import full database snapshot files protected with AES-256-GCM.

---

## 📂 Project Structure

```
meshlink/
├── lib/
│   ├── main.dart                      # App entrypoint and service bootstrapping
│   ├── ble/                           # BLE Transport Layer
│   │   ├── ble_packet.dart            # Binary framing, chunking & MTU reassembly
│   │   ├── ble_transport.dart         # Transport interface abstraction
│   │   └── ble_simulation.dart        # Multi-node in-memory BLE simulation engine
│   ├── crypto/                        # Cryptographic Security Layer
│   │   ├── crypto_engine.dart         # X25519, AES-256-GCM, PBKDF2, HMAC signatures
│   │   ├── identity_manager.dart      # Keypair generation & fingerprint formatting
│   │   └── channel_crypto.dart        # Password-protected channel derivation
│   ├── data/                          # Data Models & Persistence
│   │   ├── models.dart                # Peer, Channel, Message, ACK models
│   │   ├── database_helper.dart       # SQLite persistence, unsent queue, & Panic Wipe
│   │   └── backup_service.dart        # Encrypted JSON backup export & import
│   ├── mesh/                          # Mesh Routing & Control Protocols
│   │   ├── mesh_router.dart           # Store-and-forward relay & LRU deduplication
│   │   ├── ack_manager.dart           # Per-hop delivery & read receipts
│   │   └── moderation_manager.dart    # Signed mute/kick moderation control packets
│   ├── ml/                            # On-Device Machine Learning
│   │   ├── adaptive_router.dart       # Tiny ML route optimization engine
│   │   └── translation_engine.dart    # Offline multi-lingual translation stub
│   └── ui/                            # Material 3 UI Layer
│       ├── theme.dart                 # Dark & light Material 3 design tokens
│       ├── screens/                   # Home, Chat, Mesh Map, SOS, Settings
│       └── widgets/                   # Panic Wipe logo, Hop indicator, Voice recorder
├── test/
│   └── mesh_app_test.dart             # Comprehensive unit & integration test suite
├── web/
│   └── index.html                     # Web runner entrypoint
└── pubspec.yaml                       # Dependencies & package configuration
```

---

## 🚀 How to Run

### Requirements
- Flutter SDK (>= 3.0.0)

### Running Locally
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run automated test suite
flutter test

# 3. Launch on connected device / simulator / web
flutter run
```
