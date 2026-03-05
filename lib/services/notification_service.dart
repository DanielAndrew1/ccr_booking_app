// ignore_for_file: avoid_print

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _fcm = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;
  bool _isInitialized = false;
  bool _isTokenSyncInProgress = false;
  bool _isRetryScheduled = false;
  int _apnsRetryCount = 0;

  static const String _storageKey = "notifications_enabled";
  static const int _maxApnsRetries = 6;

  bool get _isIosSimulator {
    if (!Platform.isIOS) return false;
    final env = Platform.environment;
    return env.containsKey('SIMULATOR_DEVICE_NAME') ||
        env.containsKey('SIMULATOR_MODEL_IDENTIFIER') ||
        env.containsKey('SIMULATOR_UDID');
  }

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
        macOS: initSettingsIOS,
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
    if (_isIosSimulator) return;
    if (_isTokenSyncInProgress) return;
    _isTokenSyncInProgress = true;
    try {
      if (!(await isEnabled())) return;

      final apnsReady = await _waitForApnsTokenIfNeeded();
      if (!apnsReady) {
        _scheduleApnsRetry();
        return;
      }

      String? token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        _apnsRetryCount = 0;
        await _saveTokenToSupabase(token);
      } else {
        _scheduleApnsRetry();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') {
        _scheduleApnsRetry();
        return;
      }
      print("Error getting FCM token: $e");
    } catch (e) {
      print("Error getting FCM token: $e");
    } finally {
      _isTokenSyncInProgress = false;
    }
  }

  Future<bool> _waitForApnsTokenIfNeeded() async {
    if (!Platform.isIOS) return true;

    final existingToken = await _fcm.getAPNSToken();
    if (existingToken != null && existingToken.isNotEmpty) return true;

    for (int i = 0; i < 8; i++) {
      final apnsToken = await _fcm.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) return true;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return false;
  }

  void _scheduleApnsRetry() {
    if (!Platform.isIOS) return;
    if (_apnsRetryCount >= _maxApnsRetries) return;
    if (_isRetryScheduled) return;
    _isRetryScheduled = true;
    _apnsRetryCount += 1;
    final retryDelay = Duration(seconds: _apnsRetryCount * 2);
    Future.delayed(retryDelay, () async {
      _isRetryScheduled = false;
      await getAndSaveToken();
    });
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
    if (_isIosSimulator) return;
    final userId = _supabase.auth.currentUser?.id;
    String? token;
    try {
      final apnsReady = await _waitForApnsTokenIfNeeded();
      if (!apnsReady) return;
      token = await _fcm.getToken();
    } on FirebaseException catch (e) {
      if (e.code != 'apns-token-not-set') {
        print("Error reading token for removal: $e");
      }
      token = null;
    } catch (e) {
      print("Error reading token for removal: $e");
      token = null;
    }

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
