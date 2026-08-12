import 'dart:async';
import '../packet/mesh_packet.dart';

/// Bluetooth Mesh 1.1 Low Power Node (LPN) Feature Manager.
/// Manages duty-cycled sleep/wake polling to save node battery power.
class LowPowerNodeManager {
  bool _isLpnModeEnabled = false;
  int? _friendAddress;
  Timer? _pollTimer;
  final Function(int friendAddress)? _onSendFriendPoll;

  LowPowerNodeManager({Function(int friendAddress)? onSendFriendPoll})
      : _onSendFriendPoll = onSendFriendPoll;

  bool get isLpnModeEnabled => _isLpnModeEnabled;
  int? get friendAddress => _friendAddress;

  void enableLpnMode(int friendUnicastAddress, {Duration pollInterval = const Duration(seconds: 15)}) {
    _isLpnModeEnabled = true;
    _friendAddress = friendUnicastAddress;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_isLpnModeEnabled && _friendAddress != null) {
        _onSendFriendPoll?.call(_friendAddress!);
      }
    });
  }

  void disableLpnMode() {
    _isLpnModeEnabled = false;
    _friendAddress = null;
    _pollTimer?.cancel();
  }
}
