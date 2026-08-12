/// Bluetooth Mesh 1.1 Time-To-Live (TTL) Manager.
/// Manages TTL decrementing and enforces maximum TTL of 126 according to the spec.
class MeshTtlManager {
  static const int maxTtl = 126;
  static const int defaultTtl = 7;

  /// Check if packet can be relayed based on current TTL
  static bool canRelay(int currentTtl) {
    return currentTtl > 1;
  }

  /// Decrement TTL for relayed packet
  static int decrementTtl(int currentTtl) {
    if (currentTtl <= 1) return 0;
    return (currentTtl - 1).clamp(0, maxTtl);
  }
}
