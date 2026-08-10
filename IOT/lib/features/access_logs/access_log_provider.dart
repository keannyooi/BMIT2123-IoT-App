import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/access_log.dart';

enum AccessLogFilter { all, granted, denied }

/// Live-updating feed of "who has been accessing the cabinet" events.
/// NOTE: there's no physical cabinet writing these yet - once the
/// ESP32/cloud-function side is wired up, it should write documents to the
/// `access_logs` collection matching [AccessLog.fromDoc]'s shape.
class AccessLogProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      _firestore.collection('access_logs');

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  List<AccessLog> _logs = [];
  bool _loading = false;
  bool get loading => _loading;

  AccessLogFilter _filter = AccessLogFilter.all;
  AccessLogFilter get filter => _filter;

  List<AccessLog> get logs {
    switch (_filter) {
      case AccessLogFilter.granted:
        return _logs.where((l) => l.result == AccessResult.granted).toList();
      case AccessLogFilter.denied:
        return _logs.where((l) => l.result == AccessResult.denied).toList();
      case AccessLogFilter.all:
        return _logs;
    }
  }

  AccessLogProvider() {
    _listen();
  }

  void _listen() {
    _loading = true;
    notifyListeners();
    _subscription = _logsRef
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .listen(
      (snapshot) {
        _logs = snapshot.docs.map(AccessLog.fromDoc).toList();
        _loading = false;
        notifyListeners();
      },
      onError: (_) {
        _loading = false;
        notifyListeners();
      },
    );
  }

  void setFilter(AccessLogFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final snapshot = await _logsRef
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();
      _logs = snapshot.docs.map(AccessLog.fromDoc).toList();
    } catch (_) {
      // Keep the last known logs if the refresh fails.
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
