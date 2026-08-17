import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationService {
  static final LocalNotificationService instance =
  LocalNotificationService._();

  LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel =
  AndroidNotificationChannel(
    'cabinet_alerts',
    'Cabinet Alerts',
    description: 'Alerts from the medicine cabinet',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: settings,
    );

    // Explicitly create our Android notification channel.
    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> show({
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('push_notification') != true) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'cabinet_alerts',
        'Cabinet Alerts',
        channelDescription:
        'Alerts from the medicine cabinet',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}