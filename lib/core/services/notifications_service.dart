import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _fm = FirebaseMessaging.instance;
  static final StreamController<RemoteMessage> _messages = StreamController.broadcast();
  static Stream<RemoteMessage> get messages => _messages.stream;

  static Future<void> init() async {
    // Local notifications init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Request FCM permission (Android 13+ & iOS)
    await _fm.requestPermission(alert: true, badge: true, sound: true);

    // Foreground handler
    FirebaseMessaging.onMessage.listen((msg) async {
      _messages.add(msg);
      final notification = msg.notification;
      if (notification != null) {
        await _plugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel',
              'Default',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }
}
