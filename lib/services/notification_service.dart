import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(String? payload)? onNotificationTapped;
  String? initialPayload;

  Future<void> init({void Function(String? payload)? onTapped}) async {
    onNotificationTapped = onTapped;

    const android = AndroidInitializationSettings('@drawable/ic_stat_market');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        onNotificationTapped?.call(response.payload);
      },
    );

    // Check if app was launched via notification tap from killed state
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      initialPayload = launchDetails.notificationResponse!.payload;
      onNotificationTapped?.call(initialPayload);
    }
  }

  /// Android 13+ runtime notification permission
  Future<bool?> requestPermission() async {
    return await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Constructs notification details, attaching BigPictureStyleInformation if image exists
  static NotificationDetails buildPromoNotificationDetails({
    required String title,
    required String body,
    String? imagePath,
  }) {
    BigPictureStyleInformation? bigPictureStyle;
    if (imagePath != null && File(imagePath).existsSync()) {
      bigPictureStyle = BigPictureStyleInformation(
        FilePathAndroidBitmap(imagePath),
        contentTitle: title,
        summaryText: body,
        hideExpandedLargeIcon: true,
      );
    }

    final androidDetails = AndroidNotificationDetails(
      'promo_channel',
      'Business Promotions',
      channelDescription: 'Promotions from nearby businesses',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_stat_market',
      styleInformation: bigPictureStyle,
    );

    return NotificationDetails(android: androidDetails);
  }

  Future<void> showPromo({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imagePath,
  }) async {
    try {
      final details = buildPromoNotificationDetails(
        title: title,
        body: body,
        imagePath: imagePath,
      );
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (_) {}
  }
}
