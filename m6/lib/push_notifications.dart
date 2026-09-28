import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

class PushNotifications {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // موقع استارت اپ صدا زده می‌شه — مجوز نوتیف رو می‌گیره و برای نشون دادن
  // نوتیف وقتی اپ باز و فورگراند هست آماده می‌شه (FCM خودش تو این حالت
  // نوتیف رو نشون نمی‌ده، باید دستی نشونش بدیم).
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await FirebaseMessaging.instance.requestPermission();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings),
      );

      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel',
              'اعلان‌ها',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      });
    } catch (e) {
      // اگه فایربیس هنوز درست تنظیم نشده (google-services.json و...)،
      // بی‌خیال می‌شیم — بقیه‌ی اپ باید بدون مشکل کار کنه.
    }
  }

  // بعد از لاگین موفق صدا زده می‌شه — توکن این دستگاه رو به بک‌اند می‌ده.
  static Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiClient.registerPushToken(token);
      }
    } catch (e) {
      // اگه نشد، فقط پوش نوتیفیکیشن کار نمی‌کنه؛ بقیه‌ی اپ مشکلی نداره.
    }
  }
}
