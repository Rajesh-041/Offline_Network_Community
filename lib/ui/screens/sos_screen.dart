import 'package:flutter/material.dart';
import '../../mesh/mesh_router.dart';

class SosScreen extends StatefulWidget {
  final MeshRouter meshRouter;

  const SosScreen({super.key, required this.meshRouter});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  late AnimationController _beaconController;
  final _sosTextController = TextEditingController(text: 'EMERGENCY SOS: Require Medical & Rescue Assistance!');
  bool _isBroadcasting = false;
  int _relayedNodeCount = 0;

  @override
  void initState() {
    super.initState();
    _beaconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _beaconController.dispose();
    _sosTextController.dispose();
    super.dispose();
  }

  void _triggerSos() async {
    setState(() {
      _isBroadcasting = true;
      _relayedNodeCount = widget.meshRouter.activePeers.length + 1;
    });

    await widget.meshRouter.sendEmergencySos(_sosTextController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('🚨 HIGH PRIORITY SOS BROADCAST SENT to $_relayedNodeCount mesh nodes!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS Center', style: TextStyle(color: Colors.redAccent)),
        backgroundColor: Colors.redAccent.withOpacity(0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Beacon animation button
            AnimatedBuilder(
              animation: _beaconController,
              builder: (context, child) {
                return Container(
                  padding: EdgeInsets.all(20 + (_beaconController.value * 12)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.2 * _beaconController.value + 0.1),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(40),
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 8,
                    ),
                    onPressed: _triggerSos,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 48),
                        SizedBox(height: 8),
                        Text('BROADCAST SOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _sosTextController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Emergency Alert Message',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note, color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.redAccent.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Location-Free Mesh Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Emergency SOS packets bypass channel filters, carry maximum TTL (15 hops), and are unconditionally relayed by all nearby BLE devices.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (_isBroadcasting) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Active Mesh Nodes Reached:'),
                          Text('$_relayedNodeCount Nodes', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
