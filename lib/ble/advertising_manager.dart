import 'dart:async';
import 'package:flutter/foundation.dart';

class BleAdvertisingManager {
  bool _isAdvertising = false;
  String _advertisingData = '';

  bool get isAdvertising => _isAdvertising;

  Future<void> startAdvertising({required String serviceUuid, String? payload}) async {
    _isAdvertising = true;
    _advertisingData = payload ?? serviceUuid;
    debugPrint('BLE Advertising Bearer Started on Service: $serviceUuid');
  }

  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    debugPrint('BLE Advertising Bearer Stopped.');
  }
}
