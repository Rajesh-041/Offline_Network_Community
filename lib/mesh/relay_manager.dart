/// Bluetooth Mesh 1.1 Managed Flooding & Relay Configuration Manager.
class MeshRelayManager {
  bool relayEnabled;
  int relayRetransmitCount;
  int relayIntervalMs;

  MeshRelayManager({
    this.relayEnabled = true,
    this.relayRetransmitCount = 2,
    this.relayIntervalMs = 100,
  });

  void updateRelayConfiguration({
    bool? enabled,
    int? retransmitCount,
    int? intervalMs,
  }) {
    if (enabled != null) relayEnabled = enabled;
    if (retransmitCount != null) relayRetransmitCount = retransmitCount;
    if (intervalMs != null) relayIntervalMs = intervalMs;
  }
}
