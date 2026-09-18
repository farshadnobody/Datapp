// نگهدارنده‌ی ساده‌ی session تو حافظه. فعلاً با بستن اپ پاک می‌شه — تو مراحل
// بعدی نقشه راه (وقتی به سخت‌سازی امنیتی رسیدیم) می‌شه با shared_preferences
// این رو بین بازکردن‌های اپ هم نگه داشت.
class AuthSession {
  static String? token;
  static String? phone;

  static bool get isLoggedIn => token != null;

  static void set(String newToken, String newPhone) {
    token = newToken;
    phone = newPhone;
  }

  static void clear() {
    token = null;
    phone = null;
  }
}
