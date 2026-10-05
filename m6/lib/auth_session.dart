import 'swipe/rewind_memory.dart';
import 'http_cache.dart';
import 'swipe/location_gate.dart';
import 'widgets/app_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'swipe/swipe_onboarding_store.dart';
import 'subscription/subscription_state.dart';
import 'promo/promo_service.dart';
import 'bootstrap/bootstrap_service.dart';
import 'realtime/realtime_service.dart';
import 'chat/chat_cache.dart';
import 'swipe/swipe_outbox.dart';
import 'cache/card_cache.dart';
import 'cache/discovery_queue.dart';
import 'likes/likes_store.dart';

// نگهدارنده‌ی session. مقدارها هم تو حافظه نگه داشته می‌شن (برای دسترسی
// سریع و همزمان از ApiClient) و هم روی گوشی ذخیره می‌شن تا با بستن و باز کردن
// اپ لاگین بمونه. «توکن» (که مثلِ رمزه) تو حافظه‌ی امنِ گوشی (Keystore اندروید /
// Keychain آیفون) رمزنگاری‌شده ذخیره می‌شه؛ بقیه (شماره، ...) تو shared_preferences.
//
// AuthSession.load() باید یک‌بار قبل از runApp صدا زده بشه (تو main.dart).
class AuthSession {
  static const _tokenKey = 'auth_token';
  static const _phoneKey = 'auth_phone';
  static const _hasProfileKey = 'auth_has_profile';

  // حافظه‌ی امنِ گوشی برای توکن.
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

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
      phone = prefs.getString(_phoneKey);
      hasProfile = prefs.getBool(_hasProfileKey) ?? false;

      token = await _readSecureToken();

      // مهاجرت: نسخه‌های قبلی توکن رو بدون رمزنگاری تو shared_preferences نگه
      // می‌داشتن. اگه هنوز اونجا بود، به حافظه‌ی امن منتقلش کن و از اونجا پاک کن.
      final legacy = prefs.getString(_tokenKey);
      if (legacy != null && legacy.isNotEmpty) {
        if (token == null || token!.isEmpty) {
          token = legacy;
          await _writeSecureToken(legacy);
        }
        await prefs.remove(_tokenKey);
      }
    } catch (_) {
      // اگه خوندن ذخیره‌سازی خراب شد، فقط از اول لاگین لازم می‌شه.
    }
  }

  static Future<String?> _readSecureToken() async {
    try {
      return await _secure.read(key: _tokenKey);
    } catch (_) {
      // مثلاً کلیدِ Keystore خراب شده (بعد از restore بکاپ): از اول لاگین.
      try {
        await _secure.delete(key: _tokenKey);
      } catch (_) {}
      return null;
    }
  }

  static Future<void> _writeSecureToken(String value) async {
    try {
      await _secure.write(key: _tokenKey, value: value);
    } catch (_) {}
  }

  static Future<void> set(String newToken, String newPhone,
      {bool hasProfile = false}) async {
    // اول تو حافظه (همزمان)، بعد روی دیسک.
    token = newToken;
    phone = newPhone;
    AuthSession.hasProfile = hasProfile;
    try {
      await _writeSecureToken(newToken);
      final prefs = await SharedPreferences.getInstance();
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
    RewindMemory.instance.clear(); // حافظه‌ی Rewind فقط مالِ همین session/حساب‌ـه
    HttpCacheStore.clearAll(); // کشِ پروفایل/گزینه‌ها
    LocationGate.reset(); // لوکیشنِ حسابِ بعدی دوباره گرفته بشه
    SubscriptionState.instance.clear(); // اشتراکِ حسابِ قبلی نمونه
    PromoService.instance.clear(); // تبلیغ‌های حسابِ قبلی نمونه
    RealtimeService.instance.stop(); // اتصالِ زنده‌ی حسابِ قبلی بسته بشه
    BootstrapService.instance.clear(); // نسخه‌ها و داده‌ی ذخیره‌شده‌ی حسابِ قبلی
    ChatCache.clearAll(); // پیام‌های خصوصی نباید رو گوشی بمونه
    SwipeOutbox.instance.clearLocal(); // ردهای ارسال‌نشده‌ی حسابِ قبلی
    AppImageCache.clear(); // عکسِ آدم‌های دیگه نباید رو گوشی بمونه
    CardCache.instance.clear(); // کارت‌های کاربرِ قبلی (فقط تو logout کامل پاک می‌شه)
    DiscoveryQueueStore.instance.clearAll(); // صف‌های Swipe و Explore
    LikesStore.instance.clear(); // state لیستِ Likes
    token = null;
    phone = null;
    hasProfile = false;
    // شمارنده‌ی مرحله‌ی یادگیری سلیقه مال همین کاربر بود.
    await SwipeOnboarding.clear();
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey); // (نسخه‌ی قدیمی، اگه مونده بود)
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
