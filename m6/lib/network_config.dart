import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'api_client.dart' as api;

// عمداً هیچ تنظیمات کاربری یا مقدار ذخیره‌شده‌ای این‌جا نیست — چون یه تنظیمات
// که کاربر نهایی بتونه آدرس سرور رو دستی عوض کنه، تو یه اپ منتشرشده خودش یه
// ریسکه. فقط سه‌تا حالت ثابته:
//
// - وب        -> IP_زیر (یا localhost اگه رو همون کامپیوتری که بک‌اند روشه باز می‌شه)
// - امولاتور  -> 10.0.2.2 (این همیشه به کامپیوتر میزبان اشاره می‌کنه)
// - گوشی واقعی -> IP_زیر (باید IP لپ‌تاپت تو وای‌فای فعلی باشه)
//
// نکته: این کل قضیه فقط برای همین مرحله‌ی توسعه/تسته. وقتی بک‌اند رو رو یه
// سرور واقعی با دامنه‌ی ثابت میزبانی کردیم (مرحله‌ی آخر نقشه راه)، این فایل
// دیگه لازم نیست — همه‌جا یه آدرس ثابت (https://api.yourapp.com) می‌شه.
class NetworkConfig {
  static const _webUrl = 'http://192.168.1.100:8080';
  static const _emulatorUrl = 'http://10.0.2.2:8080';
  static const _realDeviceUrl = 'http://192.168.1.100:8080';

  static Future<void> initialize() async {
    if (kIsWeb) {
      api.backendBaseUrl = _webUrl;
      return;
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      api.backendBaseUrl = androidInfo.isPhysicalDevice ? _realDeviceUrl : _emulatorUrl;
    } catch (_) {
      // اندروید نیست (مثلاً iOS) — فعلاً همون آدرس گوشی واقعی رو می‌ذاریم.
      api.backendBaseUrl = _realDeviceUrl;
    }
  }
}
