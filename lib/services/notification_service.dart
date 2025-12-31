import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class NotificationService {
  // Singleton pattern to use the same instance everywhere
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initNotification() async {
    if (_isInitialized) return;

    try {
      // Android: Use the app icon (without extension) from android/app/src/main/res/drawable
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

      // Initialize with callback for when user taps notification
      await notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions (especially important for Android 13+)
      await _requestPermissions();

      _isInitialized = true;
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotificationService: $e');
      _isInitialized = false;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped with payload: ${response.payload}');
    // You can add navigation logic here based on payload
  }

  /// Request notification permissions (Android 13+ and iOS)
  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ requires runtime permission
        final status = await Permission.notification.status;
        if (status.isDenied) {
          final result = await Permission.notification.request();
          return result.isGranted;
        }
        return status.isGranted;
      } else if (Platform.isIOS) {
        // iOS permissions are handled in DarwinInitializationSettings
        return true;
      }
      return true;
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        return await Permission.notification.isGranted;
      } else if (Platform.isIOS) {
        final result = await notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return result ?? false;
      }
      return true;
    } catch (e) {
      print('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  NotificationDetails _notificationDetails({String? payload}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        "ccr_bookings_channel",
        "Booking Updates",
        channelDescription: "Notifications for new and updated bookings",
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Show a notification
  Future<bool> showNotification({
    int? id,
    String? title,
    String? body,
    String? payload,
  }) async {
    try {
      // Check if initialized
      if (!_isInitialized) {
        await initNotification();
      }

      // Check permissions
      final hasPermission = await areNotificationsEnabled();
      if (!hasPermission) {
        print('⚠️ Notification permission not granted');
        return false;
      }

      // Generate unique ID if not provided
      final notificationId =
          id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await notificationsPlugin.show(
        notificationId,
        title ?? 'Notification',
        body ?? '',
        _notificationDetails(payload: payload),
        payload: payload,
      );

      print('✅ Notification shown: $title');
      return true;
    } catch (e) {
      print('❌ Error showing notification: $e');
      return false;
    }
  }

  /// Show notification for new booking
  Future<bool> showBookingCreatedNotification({
    required String clientName,
    String? bookingId,
  }) async {
    return await showNotification(
      title: '📅 New Booking Created!',
      body: 'Booking for $clientName has been created successfully',
      payload: 'booking_created:$bookingId',
    );
  }

  /// Show notification for booking update
  Future<bool> showBookingUpdatedNotification({
    required String clientName,
    required String status,
    String? bookingId,
  }) async {
    return await showNotification(
      title: '🔄 Booking Updated',
      body: '$clientName\'s booking is now: ${status.toUpperCase()}',
      payload: 'booking_updated:$bookingId',
    );
  }

  /// Show notification for booking status change
  Future<bool> showBookingStatusNotification({
    required String clientName,
    required String oldStatus,
    required String newStatus,
    String? bookingId,
  }) async {
    String emoji = '📦';
    if (newStatus == 'completed') emoji = '✅';
    if (newStatus == 'cancelled') emoji = '❌';
    if (newStatus == 'upcoming') emoji = '📅';
    if (newStatus == 'returning') emoji = '🔙';

    return await showNotification(
      title: '$emoji Booking Status Changed',
      body: '$clientName: $oldStatus → $newStatus',
      payload: 'status_change:$bookingId',
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    try {
      await notificationsPlugin.cancel(id);
      print('✅ Notification $id cancelled');
    } catch (e) {
      print('❌ Error cancelling notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await notificationsPlugin.cancelAll();
      print('✅ All notifications cancelled');
    } catch (e) {
      print('❌ Error cancelling all notifications: $e');
    }
  }

  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    try {
      final pendingNotifications = await notificationsPlugin
          .pendingNotificationRequests();
      return pendingNotifications.length;
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
      return 0;
    }
  }

  /// Get active notifications count (Android only)
  Future<int> getActiveNotificationsCount() async {
    try {
      final activeNotifications = await notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.getActiveNotifications();
      return activeNotifications?.length ?? 0;
    } catch (e) {
      print('❌ Error getting active notifications: $e');
      return 0;
    }
  }
}
