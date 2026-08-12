import 'package:flutter/material.dart';
import '../../ble/ble_simulation.dart';
import '../../crypto/identity_manager.dart';
import '../../data/database_helper.dart';
import '../../data/models.dart';
import '../../mesh/mesh_router.dart';
import '../../ml/translation_engine.dart';
import '../widgets/create_channel_dialog.dart';
import '../widgets/panic_wipe_logo.dart';
import 'chat_screen.dart';
import 'mesh_map_screen.dart';
import 'settings_screen.dart';
import 'sos_screen.dart';

class HomeScreen extends StatefulWidget {
  final MeshRouter meshRouter;
  final IdentityManager identityManager;
  final DatabaseHelper dbHelper;
  final BleSimulationEngine simulationEngine;
  final TranslationEngine translationEngine;

  const HomeScreen({
    super.key,
    required this.meshRouter,
    required this.identityManager,
    required this.dbHelper,
    required this.simulationEngine,
    required this.translationEngine,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Peer> _nearbyPeers = [];
  List<Channel> _channels = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    widget.meshRouter.onPeersUpdated.listen((peers) {
      if (mounted) {
        setState(() {
          _nearbyPeers = List.from(peers);
          _nearbyPeers.sort((a, b) => b.rssi.compareTo(a.rssi)); // Sort by RSSI signal strength
        });
      }
    });
  }

  void _loadData() {
    setState(() {
      _channels = widget.dbHelper.getAllChannels();
    });
  }

  void _onPanicWipe() async {
    await widget.dbHelper.panicWipeAllData();
    widget.identityManager.panicWipeIdentity();
    _loadData();
  }

  void _openCreateChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateChannelDialog(
        creatorFingerprint: widget.identityManager.fingerprint,
        onCreate: (channel) {
          widget.dbHelper.saveChannel(channel);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: PanicWipeLogo(onPanicWipe: _onPanicWipe),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MeshLink', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Serverless P2P BLE Mesh', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            tooltip: 'Emergency SOS Center',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SosScreen(meshRouter: widget.meshRouter)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_rounded, color: Color(0xFF6366F1)),
            tooltip: 'Mesh Topology Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MeshMapScreen(
                    activePeers: widget.meshRouter.activePeers,
                    localNodeId: widget.identityManager.nodeId,
                    simulationEngine: widget.simulationEngine,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    identityManager: widget.identityManager,
                    translationEngine: widget.translationEngine,
                    dbHelper: widget.dbHelper,
                    meshRouter: widget.meshRouter,
                    onPanicWipe: _onPanicWipe,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: const Color(0xFF6366F1),
          tabs: [
            Tab(text: 'Nearby Peers (${_nearbyPeers.length})'),
            Tab(text: 'Channels (${_channels.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPeersTab(),
                _buildChannelsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateChannelDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Channel'),
      ),
    );
  }

  Widget _buildStatusBar() {
    final isDutyActive = widget.simulationEngine.isDutyCyclingActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('BLE Mesh Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          Row(
            children: [
              Icon(
                isDutyActive ? Icons.battery_saver : Icons.battery_full,
                size: 14,
                color: isDutyActive ? Colors.amber : Colors.greenAccent,
              ),
              const SizedBox(width: 4),
              Text(
                isDutyActive ? 'Duty Cycling Active' : 'Optimal Power',
                style: TextStyle(fontSize: 11, color: isDutyActive ? Colors.amber : Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeersTab() {
    if (_nearbyPeers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Scanning for nearby BLE mesh devices...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _nearbyPeers.length,
      itemBuilder: (context, index) {
        final peer = _nearbyPeers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.15),
              child: Text(
                peer.fingerprint.substring(0, 2),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ),
            title: Text(peer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Fingerprint: ${peer.fingerprint} • RSSI: ${peer.rssi} dBm'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${peer.hops} Hop${peer.hops > 1 ? 's' : ''}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                Text('${peer.batteryLevel}% Bat', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    title: peer.name,
                    peerId: peer.id,
                    meshRouter: widget.meshRouter,
                    identityManager: widget.identityManager,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChannelsTab() {
    return ListView.builder(
      itemCount: _channels.length,
      itemBuilder: (context, index) {
        final channel = _channels[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(
              channel.isProtected ? Icons.lock : Icons.tag,
              color: channel.isProtected ? Colors.amber : const Color(0xFF6366F1),
            ),
            title: Text('#${channel.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(channel.description),
            trailing: channel.isProtected
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('ENCRYPTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    title: '#${channel.name}',
                    channelId: channel.id,
                    meshRouter: widget.meshRouter,
                    identityManager: widget.identityManager,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
