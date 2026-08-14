/// Represents a smart cabinet found while scanning for nearby devices
/// during the pairing flow.
class DiscoveredCabinetDevice {
  final String cabinetId;
  final int signalStrength; // 1 (weak) .. 4 (strong)

  const DiscoveredCabinetDevice({
    required this.cabinetId,
    required this.signalStrength, // TODO: remove
  });
}
