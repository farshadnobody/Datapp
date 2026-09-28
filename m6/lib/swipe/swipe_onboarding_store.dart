import 'package:shared_preferences/shared_preferences.dart';

/// وضعیت «مرحله‌ی یادگیری سلیقه» — فقط برای کاربری که تازه ثبت‌نام کرده و از
/// فلو اونبوردینگ وارد اپ شده.
///
/// - `start()` آخر اونبوردینگ صدا زده می‌شه و شمارنده رو روی ۲۰ می‌ذاره.
/// - تا وقتی `remaining > 0` صفحه‌ی Swipe تو حالت ۱ (دو دکمه + بنر بالا) می‌مونه.
/// - کاربرهای قدیمی هیچ مقداری ذخیره ندارن → `remaining == 0` → مستقیم حالت ۲.
///
/// فعلاً محلیه (shared_preferences). اگه بخوای با عوض شدن گوشی هم حفظ بشه،
/// باید تعداد swipeهای کاربر رو از بک‌اند بگیری.
class SwipeOnboarding {
  SwipeOnboarding._();

  /// چند نفر باید لایک/رد بشن تا مرحله‌ی یادگیری تموم بشه.
  static const int requiredSwipes = 20;

  /// اگه true باشه «رد کردن» هم تو ۲۰ تا حساب می‌شه؛ اگه false فقط لایک و
  /// سوپرلایک می‌شمره (مثل متن اصلی تیندر: «Send 20 more Likes»).
  static const bool passesCount = true;

  static const String _key = 'swipe_onboarding_remaining';

  static int remaining = 0;

  static bool get isActive => remaining > 0;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      remaining = prefs.getInt(_key) ?? 0;
    } catch (_) {
      remaining = 0;
    }
  }

  static Future<void> start() async {
    remaining = requiredSwipes;
    await _save();
  }

  /// یه swipe رو ثبت می‌کنه. اگه با این swipe مرحله تموم شد `true` برمی‌گردونه.
  /// مقدار تو حافظه همون لحظه عوض می‌شه؛ ذخیره روی دیسک بی‌صبرانه انجام می‌شه.
  static bool register(String direction) {
    if (!isActive) return false;
    if (direction == 'pass' && !passesCount) return false;
    remaining -= 1;
    if (remaining < 0) remaining = 0;
    _save();
    return remaining == 0;
  }

  static Future<void> clear() async {
    remaining = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, remaining);
    } catch (_) {}
  }
}
