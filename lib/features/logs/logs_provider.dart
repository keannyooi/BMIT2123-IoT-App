import "dart:async";
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

  TelemetryLog? get latestTelemetry => _telemetryLogs.isNotEmpty ? _telemetryLogs.first : null;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _accessSubscription;

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _accessSubscription?.cancel();
    super.dispose();
  }

  // ── Subscribe to telemetry logs ───────────────────────────────────────────
  void subscribeToTelemetryLogs(String cabinetId) {
    _telemetrySubscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _telemetrySubscription = _firestore
        .collection('telemetryLogs')
        .where('cabinetId', isEqualTo: cabinetId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
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
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = 'Failed to listen to telemetry logs: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    });
  }

  // ── Subscribe to access logs ──────────────────────────────────────────────
  void subscribeToAccessLogs(String cabinetId) {
    _accessSubscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _accessSubscription = _firestore
        .collection('accessLogs')
        .where('cabinetId', isEqualTo: cabinetId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
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
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = 'Failed to listen to access logs: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    });
  }

  void unsubscribeFromTelemetryLogs() {
    _telemetrySubscription?.cancel();
    _telemetrySubscription = null;
  }

  void unsubscribeFromAccessLogs() {
    _accessSubscription?.cancel();
    _accessSubscription = null;
  }

  // ── Fetch telemetry logs (One-time) ───────────────────────────────────────────
  Future<void> fetchTelemetryLogs(String cabinetId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('telemetryLogs')
          .where('cabinetId', isEqualTo: cabinetId)
          .orderBy('timestamp', descending: true)
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

  // ── Fetch latest telemetry log ───────────────────────────────────────────
  Future<TelemetryLog?> fetchLatestTelemetryLog(String cabinetId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('telemetryLogs')
          .where('cabinetId', isEqualTo: cabinetId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final data = snapshot.docs.first.data();
      return TelemetryLog.fromMap({
        ...data
      });
    } catch (e) {
      _error = 'Failed to fetch telemetry logs: ${e.toString()}';
      return null;
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
          .where('cabinetId', isEqualTo: cabinetId)
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
