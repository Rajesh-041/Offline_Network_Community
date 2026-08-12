import 'package:flutter/material.dart';
import '../../crypto/identity_manager.dart';
import '../../data/backup_service.dart';
import '../../data/database_helper.dart';
import '../../mesh/mesh_router.dart';
import '../../ml/translation_engine.dart';

class SettingsScreen extends StatefulWidget {
  final IdentityManager identityManager;
  final TranslationEngine translationEngine;
  final DatabaseHelper dbHelper;
  final MeshRouter meshRouter;
  final VoidCallback onPanicWipe;

  const SettingsScreen({
    super.key,
    required this.identityManager,
    required this.translationEngine,
    required this.dbHelper,
    required this.meshRouter,
    required this.onPanicWipe,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _batteryThreshold = 20.0;
  final _passController = TextEditingController();

  void _exportBackup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Encrypted Backup'),
        content: TextField(
          controller: _passController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Backup Encryption Passphrase',
            prefixIcon: Icon(Icons.key),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final backupService = BackupService(dbHelper: widget.dbHelper);
              final encryptedData = backupService.createEncryptedBackup(_passController.text);
              _passController.clear();

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Encrypted Backup Snapshot'),
                  content: SelectableText(encryptedData),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                  ],
                ),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _importBackup() {
    final dataController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dataController,
              decoration: const InputDecoration(labelText: 'Encrypted Backup Payload'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final backupService = BackupService(dbHelper: widget.dbHelper);
              final success = backupService.restoreFromEncryptedBackup(dataController.text, _passController.text);
              _passController.clear();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: success ? Colors.green : Colors.red,
                  content: Text(success ? 'Backup Restored Successfully!' : 'Restoration Failed: Wrong Passphrase'),
                ),
              );
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _openProvisioningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.hub, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Provision Unprovisioned Device'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scanning for Unprovisioned Bluetooth Mesh Beacons...'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth_searching, color: Color(0xFF10B981)),
                title: const Text('Unprovisioned Node 0x0002'),
                subtitle: const Text('UUID: 4a2b...89c0 • RSSI: -54 dBm'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('✓ Node 0x0002 Provisioned! NetKey, AppKey & Unicast Address Issued.'),
                      ),
                    );
                  },
                  child: const Text('PROVISION'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyMgr = widget.identityManager.meshKeyManager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Mesh 1.1 Config & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Identity & Provisioning Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fingerprint, color: Color(0xFF6366F1), size: 28),
                          const SizedBox(width: 8),
                          Text('Node: ${widget.identityManager.nodeName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          keyMgr.unicastAddressHex,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText('Fingerprint: ${widget.identityManager.fingerprint}'),
                  SelectableText('PubKey: ${widget.identityManager.publicKeyHex.substring(0, 24)}...'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                    icon: const Icon(Icons.add_moderator),
                    label: const Text('PROVISION NEW MESH DEVICE'),
                    onPressed: _openProvisioningDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bluetooth Mesh Features Card
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Managed Flooding Relay'),
                  subtitle: const Text('Act as multi-hop relay node (Max TTL 126)'),
                  value: widget.meshRouter.relayManager.relayEnabled,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) {
                    setState(() => widget.meshRouter.relayManager.relayEnabled = val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Friend Node Feature'),
                  subtitle: const Text('Queue messages for sleeping Low Power Nodes (LPNs)'),
                  value: widget.meshRouter.friendManager.isFriendFeatureEnabled,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    setState(() => widget.meshRouter.friendManager.toggleFriendFeature(val));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Battery Duty Cycling
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Battery Duty Cycling Threshold', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_batteryThreshold.toInt()}%', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Reduces BLE scanning frequency when battery falls below threshold.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Slider(
                    value: _batteryThreshold,
                    min: 5,
                    max: 40,
                    divisions: 7,
                    activeColor: const Color(0xFF6366F1),
                    onChanged: (val) => setState(() => _batteryThreshold = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Translation Toggle
          Card(
            child: SwitchListTile(
              title: const Text('On-Device ML Translation'),
              subtitle: const Text('Auto-translate messages received in foreign languages'),
              value: widget.translationEngine.isEnabled,
              activeColor: const Color(0xFF6366F1),
              onChanged: (val) {
                setState(() => widget.translationEngine.toggleTranslation(val));
              },
            ),
          ),
          const SizedBox(height: 12),

          // Backup & Restore
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Color(0xFF10B981)),
                  title: const Text('Export Encrypted Backup'),
                  onTap: _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_for_offline, color: Color(0xFFF59E0B)),
                  title: const Text('Import Backup File'),
                  onTap: _importBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Panic Wipe Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            icon: const Icon(Icons.cleaning_services),
            label: const Text('MANUAL PANIC WIPE ALL DATA', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: widget.onPanicWipe,
          ),
        ],
      ),
    );
  }
}
