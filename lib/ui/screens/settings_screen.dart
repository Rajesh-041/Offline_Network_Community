import 'package:flutter/material.dart';
import '../../crypto/identity_manager.dart';
import '../../data/backup_service.dart';
import '../../data/database_helper.dart';
import '../../ml/translation_engine.dart';

class SettingsScreen extends StatefulWidget {
  final IdentityManager identityManager;
  final TranslationEngine translationEngine;
  final DatabaseHelper dbHelper;
  final VoidCallback onPanicWipe;

  const SettingsScreen({
    super.key,
    required this.identityManager,
    required this.translationEngine,
    required this.dbHelper,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Settings & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Identity Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.fingerprint, color: Color(0xFF6366F1), size: 36),
              title: Text('Node ID: ${widget.identityManager.nodeName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: SelectableText('Fingerprint: ${widget.identityManager.fingerprint}\nPubKey: ${widget.identityManager.publicKeyHex.substring(0, 24)}...'),
            ),
          ),
          const SizedBox(height: 16),

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
