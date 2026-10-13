import 'package:shared_preferences/shared_preferences.dart';

/// کشِ جواب‌های GET (به‌همراه ETag) روی گوشی — برای گزینه‌های پروفایل و پروفایلِ
/// خودِ کاربر. با خروج از حساب پاک می‌شه.
class HttpCacheStore {
  HttpCacheStore._();

  static const String prefix = 'http_cache:';

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
