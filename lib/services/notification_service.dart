import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize
  Future<void> initNotification() async {
    if (_isInitialized) return;

    // 1. Android init settings
    // IMPORTANT: Android does not use 'assets/icon.png'.
    // It looks for a drawable resource in android/app/src/main/res/drawable/
    // Use '@mipmap/ic_launcher' for the default app icon.
    const initSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // 2. IOS init settings
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    // Initialize Plugin
    await notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap logic here
      },
    );

    _isInitialized = true;
  }

  // 3. Notification Detail Setup
  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        "ccr_booking_channel", // Unique ID
        "CCR Bookings", // User visible name
        channelDescription: "Notifications for equipment rental updates",
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        // This ensures it pops up like Instagram/Snapchat
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // 4. Show Notification
  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    // FIXED: Pass the _notificationDetails() method here instead of an empty object
    return notificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(),
      payload: payload,
    );
  }
}
