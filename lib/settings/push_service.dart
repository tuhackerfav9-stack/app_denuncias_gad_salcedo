//import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_connection.dart';
import 'session.dart';

class PushService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1) Pedir permisos (Android 13+ y iOS)
    await FirebaseMessaging.instance.requestPermission();

    // 2) Local notifications (para que se vea cuando está en foreground)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(initSettings);

    // 3) Canal Android
    const androidChannel = AndroidNotificationChannel(
      'denuncias_channel',
      'Denuncias',
      description: 'Notificaciones de denuncias',
      importance: Importance.high,
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(androidChannel);

    // 4) Obtener token y guardar en tu backend
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _sendTokenToBackend(token);
    }

    // 5) Si el token cambia (pasa a veces)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _sendTokenToBackend(newToken);
    });

    // 6) Mensajes en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? 'Denuncias GAD Salcedo';
      final body = message.notification?.body ?? 'Tienes una notificación';

      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'denuncias_channel',
            'Denuncias',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    final access = await Session.access();
    if (access == null || access.isEmpty) {
      //  si aún no hay login, guárdalo para enviarlo luego
      await Session.setPendingFcmToken(fcmToken);
      return;
    }

    await ApiConnection.instance.post("api/notificaciones/token/", {
      "fcm_token": fcmToken,
      "platform": "android",
    }, auth: true);
  }
}
