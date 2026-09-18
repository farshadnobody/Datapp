import 'package:shared_preferences/shared_preferences.dart';

// نگهدارنده‌ی session. مقدارها هم تو حافظه نگه داشته می‌شن (برای دسترسی
// سریع و همزمان از ApiClient) و هم با shared_preferences روی گوشی ذخیره
// می‌شن تا با بستن و باز کردن اپ لاگین بمونه.
//
// AuthSession.load() باید یک‌بار قبل از runApp صدا زده بشه (تو main.dart).
class AuthSession {
  static const _tokenKey = 'auth_token';
  static const _phoneKey = 'auth_phone';
  static const _hasProfileKey = 'auth_has_profile';

  static String? token;
  static String? phone;
  static bool hasProfile = false;

  // وقتی سرور توکن رو رد کنه (منقضی/نامعتبر) صدا زده می‌شه؛ main.dart
  // این رو وصل می‌کنه به برگشت به صفحه‌ی ورود.
  static void Function()? onExpired;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);
      phone = prefs.getString(_phoneKey);
      hasProfile = prefs.getBool(_hasProfileKey) ?? false;
    } catch (_) {
      // اگه خوندن ذخیره‌سازی خراب شد، فقط از اول لاگین لازم می‌شه.
    }
  }

  static Future<void> set(String newToken, String newPhone,
      {bool hasProfile = false}) async {
    // اول تو حافظه (همزمان)، بعد روی دیسک.
    token = newToken;
    phone = newPhone;
    AuthSession.hasProfile = hasProfile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
      await prefs.setString(_phoneKey, newPhone);
      await prefs.setBool(_hasProfileKey, hasProfile);
    } catch (_) {}
  }

  static Future<void> setHasProfile(bool value) async {
    hasProfile = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasProfileKey, value);
    } catch (_) {}
  }

  static Future<void> clear() async {
    token = null;
    phone = null;
    hasProfile = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_phoneKey);
      await prefs.remove(_hasProfileKey);
    } catch (_) {}
  }

  // وقتی سرور به یه درخواست احراز‌هویت‌شده 401 بده صدا زده می‌شه.
  static void expire() {
    if (!isLoggedIn) return; // چند درخواست همزمان → فقط یک‌بار
    clear();
    onExpired?.call();
  }
}
