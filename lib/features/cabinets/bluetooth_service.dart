import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'models/discovered_device.dart';

/// Service to handle Bluetooth Low Energy (BLE) operations for cabinet discovery.
class BLEService {
  // Singleton pattern for easy access across the app
  static final BLEService instance = BLEService._();
  BLEService._();

  /// Stream to monitor Bluetooth adapter state (ON/OFF)
  Stream<BluetoothAdapterState> get stateStream => FlutterBluePlus.adapterState;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final Guid serviceUuid = Guid('9f83a100-7e3b-4dc7-8f45-91d587d23601');
  final Guid deviceIdUuid = Guid('9f83a101-7e3b-4dc7-8f45-91d587d23601');
  final Guid controlUuid = Guid('9f83a102-7e3b-4dc7-8f45-91d587d23601');

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _deviceIdCharacteristic;
  BluetoothCharacteristic? _controlCharacteristic;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String? _cabinetId;
  bool get isCabinetConnected => _connectedDevice != null;

  /// Checks if Bluetooth is supported and enabled on the device.
  Future<bool> isBluetoothAvailable() async {
    if (!await FlutterBluePlus.isSupported) {
      return false;
    }
    return await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
  }

  /// Starts a scan for nearby BLE devices and filters for cabinets.
  /// Returns a list of [DiscoveredCabinetDevice] once the scan completes.
  Future<List<DiscoveredCabinetDevice>> scanForCabinets({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final List<DiscoveredCabinetDevice> cabinets = [];

    // Ensure we are not already scanning
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    try {
      // Start scanning. In a real scenario, you would pass service UUIDs
      // to `withServices` to only find relevant hardware.
      await FlutterBluePlus.startScan(
        withServices: [
          Guid('9f83a100-7e3b-4dc7-8f45-91d587d23601'),
        ],
        timeout: timeout,
      );

      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;

      // Process results
      for (ScanResult result in FlutterBluePlus.lastScanResults) {
        cabinets.add(
          DiscoveredCabinetDevice(
            device: result.device,
            signalStrength: _calculateSignalStrength(result.rssi),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Bluetooth scan failed: $e');
      print(stackTrace);
      rethrow;
    }

    return cabinets;
  }

  Future<void> sendBLECommand(String cabinetId, String command) async {
    var characteristic = _controlCharacteristic;
    if (characteristic == null) {
      final success = await reconnect(targetCabinetId: cabinetId);
      if (!success) {
        throw StateError('Cabinet is not connected');
      }

      characteristic = _controlCharacteristic;
    }

    if (characteristic == null) {
      throw StateError('Control characteristic unavailable');
    }

    try {
      await characteristic.write(utf8.encode(command));
    }
    catch (e) {
      _controlCharacteristic = null;
      rethrow;
    }
  }

  Future<String?> connect(BluetoothDevice device) async {
    _controlCharacteristic = null;
    _deviceIdCharacteristic = null;
    _connectedDevice = null;
    _cabinetId = "";
    _connectionSubscription?.cancel();

    // 1. Connect
    await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 10));
    _connectedDevice = device;
    _monitorConnection(device);
    await _discoverCharacteristics(device);

    // 5. Read its bytes
    final cabinetId = await _deviceIdCharacteristic?.read();
    _cabinetId = utf8.decode(cabinetId ?? []);

    // 6. Convert bytes → String
    return _cabinetId;
  }

  Future<bool> reconnect({
    required String targetCabinetId,
    int maxAttempts = 3,
  }) async {
    final device = _connectedDevice;

    print(device);
    if (device == null) {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 5),
      );

      await FlutterBluePlus.isScanning
          .where((scanning) => !scanning)
          .first;

      final results =
          FlutterBluePlus.lastScanResults;

      for (final result in results) {
        final device = result.device;

        try {
          await device.connect(
            timeout: const Duration(seconds: 10),
            license: License.nonprofit
          );

          final cabinetId = await connect(device);
          if (cabinetId == targetCabinetId) {
            // Correct physical cabinet.
            _connectedDevice = device;
            _cabinetId = cabinetId;

            await _discoverCharacteristics(device);
            _monitorConnection(device);

            return true;
          }

          // Compatible cabinet, but not ours.
          await device.disconnect();
        } catch (e) {
          try {
            await device.disconnect();
          } catch (_) {}

          // Try next discovered cabinet.
        }
      }
      return false;
    }

    _controlCharacteristic = null;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        print('BLE reconnect attempt $attempt/$maxAttempts');
        await Future.delayed(
          Duration(seconds: attempt * 2),
        );

        await device.connect(license: License.nonprofit, timeout: Duration(seconds: 10));
        await _discoverCharacteristics(device);

        print('BLE reconnected');
        return true;
      } catch (e) {
        print('Reconnect attempt $attempt failed: $e',);

        try {
          await device.disconnect();
        } catch (_) {
          // Already disconnected; that's fine.
        }
      }
    }

    return false;
  }

  Future<void> _discoverCharacteristics(BluetoothDevice device) async {
    // Ask ESP32 for its GATT database
    final services = await device.discoverServices();

    // Find medicine cabinet service
    final cabinetService = services.firstWhere((service) => service.uuid == serviceUuid);

    // Find device-ID characteristic
    final deviceIdCharacteristic =
    cabinetService.characteristics.firstWhere((characteristic) =>
    characteristic.uuid == deviceIdUuid,
    );
    _deviceIdCharacteristic = deviceIdCharacteristic;

    // Find control characteristic
    final controlCharacteristic =
    cabinetService.characteristics.firstWhere(
          (characteristic) =>
      characteristic.uuid == controlUuid,
    );
    _controlCharacteristic = controlCharacteristic;
  }

  void _monitorConnection(BluetoothDevice device) {
    _connectionSubscription?.cancel();

    _connectionSubscription =
        device.connectionState.listen((state) {
          print('BLE state: $state');

          if (state == BluetoothConnectionState.disconnected) {
            _controlCharacteristic = null;

            print('Cabinet BLE connection lost');
          }
        });
  }

  /// -- HELPER FUNCTIONS FOR SCANNING --
  /// Maps BLE RSSI value to a 1-4 signal strength scale.
  int _calculateSignalStrength(int rssi) {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  /// Stops any active Bluetooth scan.
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}


