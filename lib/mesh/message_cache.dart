import 'dart:collection';

class CacheEntry {
  final int srcAddress;
  final int sequenceNumber;
  final String messageId;
  final DateTime expiryTime;

  CacheEntry({
    required this.srcAddress,
    required this.sequenceNumber,
    required this.messageId,
    required this.expiryTime,
  });
}

/// Bluetooth Mesh 1.1 Network PDU Message Cache.
/// Prevents reprocessing and duplicate relay flooding of previously seen PDUs.
class MeshNetworkMessageCache {
  final Map<String, CacheEntry> _cache = {};
  final Duration cacheLifetime;
  final int capacityLimit;

  MeshNetworkMessageCache({
    this.cacheLifetime = const Duration(minutes: 5),
    this.capacityLimit = 500,
  });

  /// Check if PDU is in cache. If not, add it and return false.
  bool isDuplicate(int srcAddress, int sequenceNumber, String messageId) {
    final key = '$srcAddress:$sequenceNumber:$messageId';
    _cleanExpiredEntries();

    if (_cache.containsKey(key)) {
      return true; // Duplicate network PDU!
    }

    if (_cache.length >= capacityLimit) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = CacheEntry(
      srcAddress: srcAddress,
      sequenceNumber: sequenceNumber,
      messageId: messageId,
      expiryTime: DateTime.now().add(cacheLifetime),
    );
    return false;
  }

  void _cleanExpiredEntries() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => now.isAfter(entry.expiryTime));
  }

  void clearCache() => _cache.clear();
}
