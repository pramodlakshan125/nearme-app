import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleDiscoveryService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  // Custom App Service UUID for proximity discovery
  static final Uuid appServiceUuid =
      Uuid.parse('0000180d-0000-1000-8000-00805f9b34fb');

  final StreamController<List<DiscoveredDevice>> _discoveredDevicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  final Map<String, DiscoveredDevice> _discoveredDevicesMap = {};

  Stream<List<DiscoveredDevice>> get discoveredDevicesStream =>
      _discoveredDevicesController.stream;

  Future<bool> requestPermissions() async {
    final statusLocation = await Permission.locationWhenInUse.request();
    final statusBleScan = await Permission.bluetoothScan.request();
    final statusBleAdvertise = await Permission.bluetoothAdvertise.request();
    final statusBleConnect = await Permission.bluetoothConnect.request();

    return statusLocation.isGranted &&
        (statusBleScan.isGranted || await Permission.bluetooth.request().isGranted);
  }

  void startScanning() {
    _discoveredDevicesMap.clear();
    _scanSubscription?.cancel();

    _scanSubscription = _ble.scanForDevices(
      withServices: [], // Scan for nearby BLE devices
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.name.isNotEmpty || device.serviceData.isNotEmpty) {
        _discoveredDevicesMap[device.id] = device;
        _discoveredDevicesController.add(_discoveredDevicesMap.values.toList());
      }
    }, onError: (Object error) {
      print('BLE Scan error: $error');
    });
  }

  void stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  void dispose() {
    stopScanning();
    _discoveredDevicesController.close();
  }
}
