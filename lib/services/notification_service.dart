import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _fcm = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;
  bool _isInitialized = false;

  Future<void> initNotification() async {
    if (!_isInitialized) {
      // 1. Local Notification Setup (Required for Foreground popups)
      const initSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: initSettingsAndroid,
        iOS: initSettingsIOS,
      );

      await notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle what happens when a user taps the notification
          print("Notification tapped: ${details.payload}");
        },
      );

      // 2. Firebase Messaging Permissions
      await _fcm.requestPermission(alert: true, badge: true, sound: true);

      // 3. Foreground Message Listener
      // This makes notifications show up even when the app is OPEN
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("Received foreground message: ${message.notification?.title}");

        RemoteNotification? notification = message.notification;
        if (notification != null) {
          showNotification(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
          );
        }
      });

      // 4. Background/Terminated Click Listener
      // Handle when app is opened FROM a notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("App opened via notification: ${message.data}");
      });

      // 5. iOS Specific: Show banner even when app is in foreground
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 6. Token Refresh Listener
      _fcm.onTokenRefresh.listen((newToken) {
        print("FCM Token Refreshed: $newToken");
        _saveTokenToSupabase(newToken);
      });

      _isInitialized = true;
    }

    // 7. FORCE REFRESH: Always fetch and sync token on every app open
    await getAndSaveToken();
  }

  /// Fetches the current device token and saves it to Supabase
  Future<void> getAndSaveToken() async {
    try {
      String? token = await _fcm.getToken();

      if (token != null) {
        print("========================================");
        print("FCM TOKEN: $token");
        print("========================================");

        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      print("Error getting FCM token: $e");
    }
  }

  /// Saves or Updates the token in the 'fcm_tokens' table
  Future<void> _saveTokenToSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId != null) {
      try {
        await _supabase.from('fcm_tokens').upsert({
          'user_id': userId,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id, token');

        print("FCM Token synced to fcm_tokens table for user $userId");
      } catch (e) {
        print("Error saving token to Supabase: $e");
      }
    } else {
      print("No user logged in. Skipping token sync.");
    }
  }

  NotificationDetails _getPlatformDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        "ccr_id",
        "CCR",
        channelDescription: "Booking Updates",
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    await notificationsPlugin.show(id, title, body, _getPlatformDetails());
  }
}
