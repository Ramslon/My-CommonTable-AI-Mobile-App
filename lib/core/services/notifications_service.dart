import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level background handler must be a global function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No heavy work here; the system will display notification payloads.
  // If you want to handle data-only messages, keep it lightweight.
}

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

    // Ensure the default Android notification channel exists (Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel',
      'Default',
      description: 'General notifications',
      importance: Importance.high,
    );
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

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
              channelDescription: 'General notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }
}
