import 'package:cloud_firestore/cloud_firestore.dart';

enum AccessResult { granted, denied }

/// A single "who accessed the cabinet" event. In production these are
/// expected to be written by the cabinet's ESP32/cloud function whenever
/// someone attempts to open it; the app only reads and displays them here.
class AccessLog {
  final String id;
  final String cabinetId;
  final String cabinetName;
  final String accessedBy;
  final AccessResult result;
  final DateTime? timestamp;
  final String? imageUrl;

  const AccessLog({
    required this.id,
    required this.cabinetId,
    required this.cabinetName,
    required this.accessedBy,
    required this.result,
    this.timestamp,
    this.imageUrl,
  });

  factory AccessLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccessLog(
      id: doc.id,
      cabinetId: data['cabinetId'] as String? ?? '',
      cabinetName: data['cabinetName'] as String? ?? 'Unknown Cabinet',
      accessedBy: data['accessedBy'] as String? ?? 'Unknown User',
      result: (data['result'] as String?) == 'denied'
          ? AccessResult.denied
          : AccessResult.granted,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      imageUrl: data['imageUrl'] as String?,
    );
  }
}
