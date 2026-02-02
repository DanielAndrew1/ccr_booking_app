// ignore_for_file: avoid_print

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _fcm = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;
  bool _isInitialized = false;

  static const String _storageKey = "notifications_enabled";

  /// 1. Static check for the toggle state (Used by UI and main.dart)
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_storageKey) ?? true; // Default to true
  }

  /// 2. The toggle logic for the Profile Page
  Future<bool> toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      // User wants to enable: Just update preference and sync token
      await prefs.setBool(_storageKey, true);
      await getAndSaveToken(); // Re-sync token to Supabase
      return true;
    } else {
      // User wants to disable: Save preference and wipe token from DB
      await prefs.setBool(_storageKey, false);
      await _removeTokenFromSupabase();
      return false;
    }
  }

  Future<void> initNotification() async {
    if (!_isInitialized) {
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
        onDidReceiveNotificationResponse: (details) {},
      );

      // Foreground Message Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        // Gate: Only show if enabled in settings
        if (await isEnabled()) {
          RemoteNotification? notification = message.notification;
          if (notification != null) {
            showNotification(
              id: notification.hashCode,
              title: notification.title,
              body: notification.body,
            );
          }
        }
      });

      _fcm.onTokenRefresh.listen((newToken) async {
        if (await isEnabled()) {
          _saveTokenToSupabase(newToken);
        }
      });

      _isInitialized = true;
    }

    if (await isEnabled()) {
      await getAndSaveToken();
    }
  }

  Future<void> getAndSaveToken() async {
    try {
      if (!(await isEnabled())) return;

      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      print("Error getting FCM token: $e");
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase.from('fcm_tokens').upsert({
          'user_id': userId,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id, token');
      } catch (e) {
        print("Error saving token to Supabase: $e");
      }
    }
  }

  /// Removes the token so the server stops sending pushes to this device
  Future<void> _removeTokenFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    final token = await _fcm.getToken();

    if (userId != null && token != null) {
      try {
        await _supabase.from('fcm_tokens').delete().match({
          'user_id': userId,
          'token': token,
        });
        print("FCM Token removed from Supabase.");
      } catch (e) {
        print("Error removing token: $e");
      }
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
