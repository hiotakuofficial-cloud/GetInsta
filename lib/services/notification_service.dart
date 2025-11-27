import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;
  }

  static Future<void> showDownloadStarted(String filename) async {
    await initialize();
    
    const androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Instagram download notifications',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/notification',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      'Downloading Instagram Media',
      'Starting download: $filename',
      details,
    );
  }

  static Future<void> updateDownloadProgress(int progress, String filename) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Instagram download notifications',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/notification',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      'Downloading Instagram Media',
      '$progress% - $filename',
      details,
    );
  }

  static Future<void> showDownloadComplete(String filename, bool success) async {
    const androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Instagram download notifications',
      importance: Importance.high,
      priority: Priority.high,
      showProgress: false,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/notification',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      2,
      success ? 'Download Complete!' : 'Download Failed',
      success ? 'Successfully saved: $filename' : 'Failed to download: $filename',
      details,
    );
  }

  static Future<void> cancelDownloadNotification() async {
    await _notifications.cancel(1);
  }
}
