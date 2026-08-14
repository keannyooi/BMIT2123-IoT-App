import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelemetryLog {
  final String id;
  final String cabinetId;
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final String stockStatus;

  TelemetryLog({
    required this.id,
    required this.cabinetId,
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.stockStatus,
  });

  factory TelemetryLog.fromMap(Map<String, dynamic> map) {
    DateTime ts;
    if (map['timestamp'] is Timestamp) {
      ts = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      ts = DateTime.parse(map['timestamp']);
    } else {
      ts = DateTime.now();
    }

    return TelemetryLog(
      id: map['telemetryLogId'] ?? '',
      cabinetId: map['cabinetId'] ?? '',
      timestamp: ts,
      temperature: (map['temperature'] as num? ?? 0).toDouble(),
      humidity: (map['humidity'] as num? ?? 0).toDouble(),
      stockStatus: map['stockStatus'] ?? '',
    );
  }
}

class AccessLog {
  final String id;
  final String cabinetId;
  final String cardId;
  final String accessResult;
  final String imagePath;
  final String imageUploadStatus;
  final DateTime timestamp;

  AccessLog({
    required this.id,
    required this.cabinetId,
    required this.cardId,
    required this.accessResult,
    required this.imagePath,
    required this.imageUploadStatus,
    required this.timestamp
  });

  factory AccessLog.fromMap(Map<String, dynamic> map) {
    DateTime ts;
    if (map['timestamp'] is Timestamp) {
      ts = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      ts = DateTime.parse(map['timestamp']);
    } else {
      ts = DateTime.now();
    }

    return AccessLog(
      id: map['accessLogId'] ?? '',
      cabinetId: map['cabinetId'] ?? '',
      cardId: map['cardId'] ?? '',
      accessResult: map['accessResult'] ?? 'failed',
      imagePath: map['imagePath'] ?? '',
      imageUploadStatus: map['imageUploadStatus'] ?? 'failed',
      timestamp: ts,
    );
  }
}

class LogsProvider extends ChangeNotifier {
  final List<TelemetryLog> _telemetryLogs = [];
  List<TelemetryLog> get telemetryLogs => _telemetryLogs;
  final List<AccessLog> _accessLogs = [];
  List<AccessLog> get accessLogs => _accessLogs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  // ── Fetch telemetry logs ───────────────────────────────────────────
  Future<void> fetchTelemetryLogs(String cabinetId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('telemetryLogs')
          .orderBy('timestamp', descending: true)
          // .limit(100) // Limit to recent logs for reports
          .get();

      _telemetryLogs.clear();
      _telemetryLogs.addAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          return TelemetryLog.fromMap({
            ...data,
            'telemetryLogId': doc.id,
          });
        }),
      );
    } catch (e) {
      _error = 'Failed to fetch telemetry logs: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Fetch access logs ──────────────────────────────────────────────
  Future<void> fetchAccessLogs(String cabinetId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('accessLogs')
          // .where('isTestData', isEqualTo: true)
          // .where('cabinetId', isEqualTo: cabinetId)
          .orderBy('timestamp', descending: true)
          .get();

      _accessLogs.clear();
      _accessLogs.addAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          return AccessLog.fromMap({
            ...data,
            'accessLogId': doc.id,
          });
        }),
      );
    } catch (e) {
      _error = 'Failed to fetch access logs: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
