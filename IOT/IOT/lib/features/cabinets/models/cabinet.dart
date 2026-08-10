import 'package:cloud_firestore/cloud_firestore.dart';

class Cabinet {
  final String id;
  final String name;
  final String cabinetId;
  final bool locked;
  final double? temperature;
  final double? humidity;
  final DateTime? pairedAt;
  final DateTime? lastUpdated;

  const Cabinet({
    required this.id,
    required this.name,
    required this.cabinetId,
    required this.locked,
    this.temperature,
    this.humidity,
    this.pairedAt,
    this.lastUpdated,
  });

  factory Cabinet.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Cabinet(
      id: doc.id,
      name: data['name'] as String? ?? 'My Cabinet',
      cabinetId: data['cabinetId'] as String? ?? '',
      locked: data['locked'] as bool? ?? true,
      temperature: (data['temperature'] as num?)?.toDouble(),
      humidity: (data['humidity'] as num?)?.toDouble(),
      pairedAt: (data['pairedAt'] as Timestamp?)?.toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Cabinet copyWith({
    bool? locked,
    double? temperature,
    double? humidity,
    DateTime? lastUpdated,
  }) {
    return Cabinet(
      id: id,
      name: name,
      cabinetId: cabinetId,
      locked: locked ?? this.locked,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      pairedAt: pairedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
