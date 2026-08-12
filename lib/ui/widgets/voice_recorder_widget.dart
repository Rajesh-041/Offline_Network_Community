import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(Uint8List audioBytes, int durationMs) onSendVoice;

  const VoiceRecorderWidget({super.key, required this.onSendVoice});

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  bool _isRecording = false;
  int _elapsedMs = 0;
  Timer? _timer;

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _elapsedMs = 0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() {
        _elapsedMs += 100;
      });
      if (_elapsedMs >= 30000) { // 30 second limit
        _stopAndSend();
      }
    });
  }

  void _stopAndSend() {
    _timer?.cancel();
    if (_isRecording) {
      setState(() => _isRecording = false);
      if (_elapsedMs > 500) {
        // Generate simulated compressed Opus audio payload bytes
        final sampleCount = (_elapsedMs / 10).toInt();
        final dummyAudio = Uint8List(sampleCount);
        final rand = Random();
        for (int i = 0; i < sampleCount; i++) {
          dummyAudio[i] = rand.nextInt(256);
        }
        widget.onSendVoice(dummyAudio, _elapsedMs);
      }
    }
  }

  void _cancel() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _elapsedMs = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      return IconButton(
        icon: const Icon(Icons.mic_rounded, color: Color(0xFF6366F1)),
        tooltip: 'Hold to Record Voice Note (<30s)',
        onPressed: _startRecording,
      );
    }

    final seconds = (_elapsedMs / 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Text(
            '${seconds}s / 30s',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 18),
            onPressed: _cancel,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF6366F1), size: 20),
            onPressed: _stopAndSend,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
