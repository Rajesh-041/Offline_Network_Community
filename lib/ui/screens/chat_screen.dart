import 'dart:convert';
import 'package:flutter/material.dart';
import '../../crypto/identity_manager.dart';
import '../../data/models.dart';
import '../../mesh/mesh_router.dart';
import '../widgets/hop_indicator.dart';
import '../widgets/voice_recorder_widget.dart';

class ChatScreen extends StatefulWidget {
  final String title;
  final String? peerId;
  final String? channelId;
  final MeshRouter meshRouter;
  final IdentityManager identityManager;

  const ChatScreen({
    super.key,
    required this.title,
    this.peerId,
    this.channelId,
    required this.meshRouter,
    required this.identityManager,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _chatMessages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    widget.meshRouter.onMessageReceived.listen((_) {
      if (mounted) _loadMessages();
    });
  }

  void _loadMessages() {
    setState(() {
      if (widget.channelId != null) {
        _chatMessages = widget.meshRouter.dbHelper.getMessagesForChannel(widget.channelId!);
      } else if (widget.peerId != null) {
        _chatMessages = widget.meshRouter.dbHelper.getDirectMessages(widget.peerId!);
      }
    });
  }

  void _sendMessage({String? overrideContent, MessageType type = MessageType.text, dynamic voiceBytes, int? durationMs}) async {
    final text = overrideContent ?? _messageController.text.trim();
    if (text.isEmpty && type != MessageType.voice) return;

    final msg = Message(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      senderId: widget.identityManager.nodeId,
      senderFingerprint: widget.identityManager.fingerprint,
      senderName: widget.identityManager.nodeName,
      recipientId: widget.peerId,
      channelId: widget.channelId,
      content: text,
      timestamp: DateTime.now(),
      type: type,
      isEncrypted: widget.peerId != null,
      voiceBytes: voiceBytes,
      voiceDurationMs: durationMs,
    );

    _messageController.clear();
    await widget.meshRouter.sendMessage(msg);
    _loadMessages();
  }

  void _onSendVoice(dynamic bytes, int durationMs) {
    _sendMessage(overrideContent: '[Voice Note]', type: MessageType.voice, voiceBytes: bytes, durationMs: durationMs);
  }

  @override
  Widget build(BuildContext context) {
    final isEncrypted = widget.peerId != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isEncrypted ? Icons.lock : Icons.lock_open,
                  size: 12,
                  color: isEncrypted ? const Color(0xFF10B981) : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isEncrypted ? 'End-to-End Encrypted (X25519 + AES-GCM)' : 'Public BLE Mesh Broadcast',
                  style: TextStyle(fontSize: 10, color: isEncrypted ? const Color(0xFF10B981) : Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                final isMe = msg.senderId == widget.identityManager.nodeId;
                return _buildChatBubble(msg, isMe);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Message msg, bool isMe) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF6366F1) : colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.senderName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      msg.senderFingerprint,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (msg.type == MessageType.voice) ...[
              Row(
                children: [
                  Icon(Icons.play_arrow_rounded, color: isMe ? Colors.white : const Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    'Voice Note (${(msg.voiceDurationMs ?? 0) ~/ 1000}s)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : null),
                  ),
                ],
              ),
            ] else ...[
              Text(
                msg.content,
                style: TextStyle(color: isMe ? Colors.white : null, fontSize: 14),
              ),
            ],
            if (msg.translatedContent != null) ...[
              const SizedBox(height: 4),
              Text(
                msg.translatedContent!,
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amberAccent),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HopIndicator(
                  hopCount: msg.hopCount,
                  status: msg.status,
                  isOutgoing: isMe,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            VoiceRecorderWidget(onSendVoice: _onSendVoice),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type mesh message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF6366F1)),
              onPressed: () => _sendMessage(),
            ),
          ],
        ),
      ),
    );
  }
}
