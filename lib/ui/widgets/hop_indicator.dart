import 'package:flutter/material.dart';
import '../../data/models.dart';

class HopIndicator extends StatelessWidget {
  final int hopCount;
  final DeliveryStatus status;
  final bool isOutgoing;

  const HopIndicator({
    super.key,
    required this.hopCount,
    required this.status,
    required this.isOutgoing,
  });

  Widget _buildStatusTicks() {
    IconData icon;
    Color color = Colors.grey;

    switch (status) {
      case DeliveryStatus.pending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
        );
      case DeliveryStatus.sent:
        icon = Icons.check;
        color = Colors.grey;
        break;
      case DeliveryStatus.relayed:
        icon = Icons.alt_route;
        color = Colors.amber;
        break;
      case DeliveryStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case DeliveryStatus.read:
        icon = Icons.done_all;
        color = const Color(0xFF38BDF8); // Light Cyan Read
        break;
    }
    return Icon(icon, size: 14, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final String label = hopCount <= 1 ? '1 Hop (Direct)' : '$hopCount Hops (Relayed)';
    final Color badgeColor = hopCount <= 1 ? const Color(0xFF10B981) : (hopCount == 2 ? Colors.amber : Colors.orangeAccent);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hopCount <= 1 ? Icons.bluetooth_connected : Icons.hub,
                size: 11,
                color: badgeColor,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
        if (isOutgoing) ...[
          const SizedBox(width: 5),
          _buildStatusTicks(),
        ],
      ],
    );
  }
}
