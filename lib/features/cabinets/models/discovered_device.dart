import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DiscoveredCabinetDevice {
  final BluetoothDevice device;
  final int signalStrength; // 1 (weak) .. 4 (strong)

  const DiscoveredCabinetDevice({
    required this.device,
    required this.signalStrength,
  });
}