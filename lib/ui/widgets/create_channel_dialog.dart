import 'package:flutter/material.dart';
import '../../crypto/channel_crypto.dart';
import '../../data/models.dart';

class CreateChannelDialog extends StatefulWidget {
  final String creatorFingerprint;
  final Function(Channel channel) onCreate;

  const CreateChannelDialog({
    super.key,
    required this.creatorFingerprint,
    required this.onCreate,
  });

  @override
  State<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<CreateChannelDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isProtected = false;

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final id = 'chan_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    final desc = _descController.text.trim();
    
    String? passwordHash;
    if (_isProtected && _passwordController.text.isNotEmpty) {
      final salt = id;
      passwordHash = ChannelCrypto.hashPassword(_passwordController.text, salt);
    }

    final channel = Channel(
      id: id,
      name: name,
      description: desc.isNotEmpty ? desc : 'Mesh Communication Channel',
      isProtected: _isProtected,
      passwordHash: passwordHash,
      creatorFingerprint: widget.creatorFingerprint,
      createdTime: DateTime.now(),
    );

    widget.onCreate(channel);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_circle_outline, color: Color(0xFF6366F1)),
          SizedBox(width: 8),
          Text('Create Mesh Channel'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                hintText: 'e.g. Rescue Team Alpha',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Channel purpose or group details',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Password Protected'),
              subtitle: const Text('Encrypts payload with Argon2id + AES-GCM'),
              value: _isProtected,
              activeColor: const Color(0xFF6366F1),
              onChanged: (val) => setState(() => _isProtected = val),
            ),
            if (_isProtected) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Channel Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Create Channel'),
        ),
      ],
    );
  }
}
