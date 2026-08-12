import 'dart:math';
import '../data/models.dart';

class RouteScore {
  final Peer peer;
  final double score;
  final String reasoning;

  RouteScore({
    required this.peer,
    required this.score,
    required this.reasoning,
  });
}

/// Offline Tiny ML Adaptive Mesh Routing Engine.
/// Learns node reliability metrics and predicts optimal relay paths.
class TinyMlAdaptiveRouter {
  final Map<String, List<bool>> _deliveryHistory = {};
  final Map<String, List<double>> _latencyHistory = {};

  /// Record delivery result (success/fail) for learning model weights
  void recordDeliveryResult(String peerId, bool success, double latencyMs) {
    _deliveryHistory.putIfAbsent(peerId, () => []);
    _deliveryHistory[peerId]!.add(success);
    if (_deliveryHistory[peerId]!.length > 30) {
      _deliveryHistory[peerId]!.removeAt(0); // sliding window of 30
    }

    _latencyHistory.putIfAbsent(peerId, () => []);
    _latencyHistory[peerId]!.add(latencyMs);
    if (_latencyHistory[peerId]!.length > 30) {
      _latencyHistory[peerId]!.removeAt(0);
    }
  }

  /// Predict optimal relay candidate among discovered active peers
  List<RouteScore> predictOptimalRoutes(List<Peer> activePeers, {String? targetPeerId}) {
    final List<RouteScore> scoredList = [];

    for (var peer in activePeers) {
      if (peer.isKicked) continue;

      // 1. RSSI Score (Normalized from -100dBm to -40dBm -> 0.0 to 1.0)
      final double rssiNormalized = ((peer.rssi + 100) / 60.0).clamp(0.0, 1.0);

      // 2. Delivery Success Rate (Historical + default)
      double deliveryRate = peer.deliverySuccessRate;
      if (_deliveryHistory.containsKey(peer.id) && _deliveryHistory[peer.id]!.isNotEmpty) {
        final successes = _deliveryHistory[peer.id]!.where((s) => s).length;
        deliveryRate = successes / _deliveryHistory[peer.id]!.length;
      }

      // 3. Battery Score (0 to 100 -> 0.0 to 1.0)
      final double batteryScore = (peer.batteryLevel / 100.0).clamp(0.0, 1.0);

      // 4. Latency Score (Normalized 10ms to 200ms -> 1.0 to 0.0)
      double avgLatency = peer.latencyMs;
      if (_latencyHistory.containsKey(peer.id) && _latencyHistory[peer.id]!.isNotEmpty) {
        avgLatency = _latencyHistory[peer.id]!.reduce((a, b) => a + b) / _latencyHistory[peer.id]!.length;
      }
      final double latencyScore = (1.0 - ((avgLatency - 10) / 190.0)).clamp(0.0, 1.0);

      // 5. Hop Penalty (Direct = 1.0, 2 hops = 0.7, 3+ hops = 0.4)
      final double hopScore = peer.hops == 1 ? 1.0 : (peer.hops == 2 ? 0.7 : 0.4);

      // Target bonus if direct match
      final double targetBonus = (targetPeerId != null && peer.id == targetPeerId) ? 0.25 : 0.0;

      // Tiny ML Weighted Linear Inference Formula
      final double score = (0.35 * rssiNormalized) +
          (0.25 * deliveryRate) +
          (0.20 * batteryScore) +
          (0.10 * latencyScore) +
          (0.10 * hopScore) +
          targetBonus;

      final String reasoning =
          'RSSI: ${(rssiNormalized * 100).toInt()}% | Success: ${(deliveryRate * 100).toInt()}% | Battery: ${peer.batteryLevel}% | Latency: ${avgLatency.toInt()}ms';

      scoredList.add(RouteScore(peer: peer, score: score, reasoning: reasoning));
    }

    scoredList.sort((a, b) => b.score.compareTo(a.score));
    return scoredList;
  }
}
