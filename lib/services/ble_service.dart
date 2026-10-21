import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleDiscoveryService {
  static const MethodChannel _advertisingChannel =
      MethodChannel('nearme/ble_advertising');
  static const Duration _deviceTimeout = Duration(seconds: 15);

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  final _discoveredTokensController =
      StreamController<List<String>>.broadcast();
  final Map<String, DateTime> _discoveredTokens = {};
  Timer? _expiryTimer;

  Stream<List<String>> get discoveredTokensStream =>
      _discoveredTokensController.stream;

  String createDiscoveryToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      return (await Permission.bluetooth.request()).isGranted;
    }
    if (!Platform.isAndroid) return false;

    final androidSdkInt =
        await _advertisingChannel.invokeMethod<int>('getAndroidSdkInt');
    if (androidSdkInt != null && androidSdkInt <= 30) {
      return (await Permission.locationWhenInUse.request()).isGranted;
    }

    final statusBleScan = await Permission.bluetoothScan.request();
    final statusBleAdvertise = await Permission.bluetoothAdvertise.request();
    final statusBleConnect = await Permission.bluetoothConnect.request();

    return statusBleAdvertise.isGranted &&
        statusBleConnect.isGranted &&
        statusBleScan.isGranted;
  }

  Future<void> startScanning() async {
    await _ble.statusStream
        .firstWhere((status) => status == BleStatus.ready)
        .timeout(const Duration(seconds: 10));
    _discoveredTokens.clear();
    _scanSubscription?.cancel();
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final cutoff = DateTime.now().subtract(_deviceTimeout);
      final previousCount = _discoveredTokens.length;
      _discoveredTokens.removeWhere((_, lastSeen) => lastSeen.isBefore(cutoff));
      if (_discoveredTokens.length != previousCount) {
        _emitDiscoveredTokens();
      }
    });

    _scanSubscription = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      final now = DateTime.now();
      for (final serviceUuid in device.serviceUuids) {
        final token = serviceUuid.toString().toLowerCase();
        if (_isDiscoveryToken(token)) _discoveredTokens[token] = now;
      }
      _emitDiscoveredTokens();
    }, onError: (Object error) {
      debugPrint('BLE Scan error: $error');
    });
  }

  Future<void> startAdvertising(String discoveryToken) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      throw UnsupportedError(
          'Bluetooth advertising is available on Android and iOS.');
    }
    await _advertisingChannel.invokeMethod<void>(
      'startAdvertising',
      {'serviceUuid': discoveryToken},
    );
  }

  Future<void> stopAdvertising() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    await _advertisingChannel.invokeMethod<void>('stopAdvertising');
  }

  void stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _discoveredTokens.clear();
    _emitDiscoveredTokens();
  }

  void dispose() {
    stopScanning();
    _discoveredTokensController.close();
  }

  bool _isDiscoveryToken(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value);
  }

  void _emitDiscoveredTokens() {
    if (!_discoveredTokensController.isClosed) {
      _discoveredTokensController.add(_discoveredTokens.keys.toList());
    }
  }
}
