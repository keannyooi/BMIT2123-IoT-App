import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../local_notification_service.dart';

class AppNotification {
  final String id;
  final String cabinetId;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'alert', 'info', 'access'

  AppNotification({
    required this.id,
    required this.cabinetId,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type = 'info',
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts;
    if (map['timestamp'] is Timestamp) {
      ts = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      ts = DateTime.parse(map['timestamp']);
    } else {
      ts = DateTime.now();
    }

    return AppNotification(
      id: map['notificationId'] ?? '',
      cabinetId: map['cabinetId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      timestamp: ts,
      isRead: map['isRead'] ?? false,
      type: map['type'] ?? 'info',
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription? _subscription;
  StreamSubscription? _fcmSubscription;
  StreamSubscription? _tokenRefreshSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> subscribeToNotifications(String userId) async {
    _subscription?.cancel();
    _fcmSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();

    _isLoading = true;
    notifyListeners();

    // 1. Request FCM Permissions
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }

    // 2. Handle FCM Token Generation and Storage
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _updateFcmToken(userId, token);
      }

      // Listen for token refreshes
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        _updateFcmToken(userId, newToken);
      });
    } catch (e) {
      debugPrint('Error handling FCM token: $e');
    }

    // 3. Listen for Foreground Messages
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.notification?.title}');

      final notification = message.notification;
      if (notification == null) {
        return;
      }

      LocalNotificationService.instance.show(
        title:
        notification.title ??
            'Medicine Cabinet',
        body:
        notification.body ??
            'New cabinet notification',
      );
    });

    // 4. Handle notification clicks when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification caused app to open from background: ${message.data}');
      // Handle navigation if needed
    });

    // 5. Check for initial message (app opened from terminated state)
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('Notification caused app to open from terminated state: ${message.data}');
      }
    });

    // 6. Subscribe to the Firestore notifications collection
    _subscription = _firestore
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notifications.clear();
      for (var doc in snapshot.docs) {
        _notifications.add(AppNotification.fromMap(doc.data(), doc.id));
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error subscribing to notifications: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _updateFcmToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).set({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String cabinetId) async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    final querySnapshot = await _firestore
        .collection('notifications')
        .where('cabinetId', isEqualTo: cabinetId)
        .get();

    final batch = _firestore.batch();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllNotifications(String cabinetId) async {
    if (_notifications.isEmpty) return;

    final querySnapshot = await _firestore
        .collection('notifications')
        .where('cabinetId', isEqualTo: cabinetId)
        .get();

    final batch = _firestore.batch();
    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _fcmSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}
