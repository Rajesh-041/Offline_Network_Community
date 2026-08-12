import 'dart:async';
import 'package:flutter/material.dart';

class PanicWipeLogo extends StatefulWidget {
  final VoidCallback onPanicWipe;

  const PanicWipeLogo({super.key, required this.onPanicWipe});

  @override
  State<PanicWipeLogo> createState() => _PanicWipeLogoState();
}

class _PanicWipeLogoState extends State<PanicWipeLogo> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _holdTimer;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerPanicWipe();
      }
    });
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isHolding = true);
    _animController.forward(from: 0.0);
  }

  void _onTapUp(TapUpDetails details) => _cancelHold();
  void _onTapCancel() => _cancelHold();

  void _cancelHold() {
    if (_isHolding) {
      setState(() => _isHolding = false);
      _animController.reset();
    }
  }

  void _triggerPanicWipe() {
    _cancelHold();
    widget.onPanicWipe();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Row(
            children: [
              Icon(Icons.cleaning_services, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('🚨 PANIC WIPE EXECUTED: All keys, chats & history purged!'),
              ),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Tooltip(
        message: 'Hold 3s for Emergency Panic Wipe',
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isHolding)
              SizedBox(
                width: 44,
                height: 44,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: _animController.value,
                      strokeWidth: 3.5,
                      color: Colors.redAccent,
                    );
                  },
                ),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isHolding
                      ? [Colors.redAccent, Colors.deepOrange]
                      : [const Color(0xFF6366F1), const Color(0xFF10B981)],
                ),
              ),
              child: const Icon(
                Icons.hub_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
