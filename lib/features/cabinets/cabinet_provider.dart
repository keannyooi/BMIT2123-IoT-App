import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/cabinet.dart';
import 'models/discovered_device.dart';

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
    await Future.delayed(const Duration(seconds: 2));
    final count = 1 + _random.nextInt(3);
    return List.generate(count, (_) {
      final code = 1000 + _random.nextInt(9000);
      return DiscoveredCabinetDevice(
        cabinetId: 'CAB$code',
        signalStrength: 2 + _random.nextInt(3),
      );
    });
  }

  // ── Pair a newly discovered cabinet ───────────────────────────
  Future<String?> pairCabinet({
    required String cabinetId,
    required String name,
  }) async {
    try {
      await _cabinetsRef.doc(cabinetId).set({
        'name': name,
        'cabinetId': cabinetId,
        'locked': true,
        'temperature': 22 + _random.nextDouble() * 8,
        'humidity': 45 + _random.nextDouble() * 30,
        'pairedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      await refreshCabinets();
      return null;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        return 'Permission Denied: Ensure you are logged in and Firestore rules allow writes to /cabinets.';
      }
      return 'Failed to pair cabinet: $e';
    }
  }

  // ── Simulate pulling the latest sensor readings ──────────────
  Future<void> refreshReadings(String cabinetId) async {
    _refreshingIds.add(cabinetId);
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 700));
      final temperature = 20 + _random.nextDouble() * 12;
      final humidity = 35 + _random.nextDouble() * 45;
      await _cabinetsRef.doc(cabinetId).update({
        'temperature': temperature,
        'humidity': humidity,
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
      return null;
    } catch (_) {
      return 'Failed to update the cabinet lock status.';
    } finally {
      _updatingLockIds.remove(cabinetId);
      notifyListeners();
    }
  }

  // ── Unpair / disconnect a cabinet ─────────────────────────────
  Future<String?> deleteCabinet(String cabinetId) async {
    try {
      await _cabinetsRef.doc(cabinetId).delete();
      await refreshCabinets();
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
