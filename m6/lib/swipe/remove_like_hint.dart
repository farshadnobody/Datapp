import 'package:shared_preferences/shared_preferences.dart';

/// راهنمای یک‌باره‌ی «دکمه‌ی روشن رو نگه دار تا لایک برداشته بشه».
/// فقط یک بار برای کل اپ (نه هر صفحه) نشون داده می‌شه و روی گوشی ذخیره می‌شه.
class RemoveLikeHint {
  RemoveLikeHint._();

  static const String _key = 'remove_like_hint_seen';
  static bool _seen = true; // تا قبل از load، نشون نده.

  static bool get shouldShow => !_seen;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen = prefs.getBool(_key) ?? false;
    } catch (_) {
      _seen = true; // اگه ذخیره‌سازی خراب بود، مزاحم نشو.
    }
  }

  static void markSeen() {
    _seen = true;
    SharedPreferences.getInstance().then((p) => p.setBool(_key, true)).catchError((_) => false);
  }
}
