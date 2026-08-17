import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bluetooth_service.dart';
import 'models/cabinet.dart';
import 'models/discovered_device.dart';
import '../logs/logs_provider.dart';

class CabinetProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  CollectionReference<Map<String, dynamic>> get _cabinetsRef =>
      _firestore.collection('cabinets');

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  List<Cabinet> _cabinets = [];
  List<Cabinet> get cabinets => _cabinets;

  bool _loading = false;
  bool get loading => _loading;

  final Set<String> _refreshingIds = {};
  bool isRefreshing(String cabinetId) => _refreshingIds.contains(cabinetId);

  final Set<String> _updatingLockIds = {};
  bool isUpdatingLock(String cabinetId) => _updatingLockIds.contains(cabinetId);

  CabinetProvider() {
    _listen();
  }

  // ── Live-updating list of every paired cabinet ────────────────
  void _listen() {
    _loading = true;
    notifyListeners();
    _subscription = _cabinetsRef
        .orderBy('pairedAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _cabinets = snapshot.docs.map(Cabinet.fromDoc).toList();
        _loading = false;
        notifyListeners();
      },
      onError: (_) {
        _loading = false;
        notifyListeners();
      },
    );
  }

  Cabinet? cabinetById(String id) {
    for (final cabinet in _cabinets) {
      if (cabinet.id == id) return cabinet;
    }
    return null;
  }

  // ── Manual refresh (e.g. pull-to-refresh); the stream already
  // keeps the list live, this just re-primes it if it ever errors out.
  Future<void> refreshCabinets() async {
    try {
      final snapshot =
          await _cabinetsRef.orderBy('pairedAt', descending: true).get();
      _cabinets = snapshot.docs.map(Cabinet.fromDoc).toList();
    } catch (_) {
      // Keep the last known list if the refresh fails.
    }
    notifyListeners();
  }

  // ── Scan for nearby cabinets ready to be paired ──────────────
  // NOTE: There is no physical pairing protocol finalised yet, so this
  // simulates a Bluetooth/Wi-Fi discovery scan. Swap the body of this
  // method out for real hardware discovery (e.g. via flutter_blue_plus)
  // once the device-side pairing flow is defined.
  Future<List<DiscoveredCabinetDevice>> scanForCabinets() async {
    return await BLEService.instance.scanForCabinets();
  }

  // ── Pair a newly discovered cabinet ───────────────────────────
  Future<String?> pairCabinet({
    required DiscoveredCabinetDevice discoveredDevice,
    required String name,
  }) async {
    // first get the cabinet ID through BLE
    final cabinetId = await BLEService.instance.connect(discoveredDevice.device);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (cabinetId == null) return 'Failed to retrieve Cabinet ID from device.';

    try {
      await _cabinetsRef.doc(cabinetId).set({
        'name': name,
        'cabinetId': cabinetId,
        'locked': true,
        'stockStatus': 'empty',
        'temperature': 22 + _random.nextDouble() * 8,
        'humidity': 45 + _random.nextDouble() * 30,
        'pairedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'cabinetId': cabinetId,
        });
      }

      notifyListeners();
      return null;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        return 'Permission Denied: Ensure you are logged in and Firestore rules allow writes to /cabinets.';
      }
      return 'Failed to pair cabinet: $e';
    }
  }

  // ── Simulate pulling the latest sensor readings ──────────────
  Future<void> refreshReadings(LogsProvider logsProvider, String cabinetId) async {
    _refreshingIds.add(cabinetId);
    notifyListeners();
    try {
      final cabinet = cabinetById(cabinetId);
      if (cabinet == null) return;

      // first get the most recent telemetry log
      final telemetryLog = await logsProvider.fetchLatestTelemetryLog(cabinetId);
      if (telemetryLog == null) return;

      // then update the readings
      await _cabinetsRef.doc(cabinetId).update({
        'temperature': telemetryLog.temperature,
        'humidity': telemetryLog.humidity,
        'stockStatus': telemetryLog.stockStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Keep the last known readings if the refresh fails.
    }
    _refreshingIds.remove(cabinetId);
    notifyListeners();
  }

  // ── Lock / unlock a cabinet ────────────────────────────────────
  Future<String?> setLocked(String cabinetId, bool locked) async {
    _updatingLockIds.add(cabinetId);
    notifyListeners();
    try {
      await _cabinetsRef.doc(cabinetId).update({
        'locked': locked,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // send BLE command to lock cabinet
      if (locked) {
        await BLEService.instance.sendBLECommand(cabinetId, 'LOCK');
      } else {
        await BLEService.instance.sendBLECommand(cabinetId, 'UNLOCK');
      }

      return null;
    } catch (e) {
      print(e);
      return 'Failed to update the cabinet lock status.';
    } finally {
      _updatingLockIds.remove(cabinetId);
      notifyListeners();
    }
  }

  // ── Unpair / disconnect a cabinet ─────────────────────────────
  Future<String?> deleteCabinet(String cabinetId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      await _cabinetsRef.doc(cabinetId).delete();
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'cabinetId': FieldValue.delete(),
        });
      }

      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to delete cabinet: $e';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
