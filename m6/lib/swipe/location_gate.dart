import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';

/// چرا الان نمی‌تونیم لوکیشن بگیریم (برای نشون دادنِ پیام به کاربر).
enum LocationIssue { none, denied, deniedForever, serviceOff }

class LocationResult {
  final LocationIssue issue;

  /// true = همین الان لوکیشنِ جدید گرفته و به سرور فرستاده شد.
  final bool updated;
  const LocationResult(this.issue, {this.updated = false});
}

/// منطقِ لوکیشنِ صفحه‌ی سواپ:
///  - لوکیشن فقط وقتی گرفته می‌شه که از آخرین ارسال ≥ ۴۸ ساعت گذشته باشه (یا
///    هیچ‌وقت نفرستاده باشیم).
///  - مجوزِ لوکیشن: اولین ورود به صفحه‌ی سواپ بعد از هر بار باز شدنِ اپ، اگه مجوز
///    نبود درخواست می‌شه (فقط یک بار برای هر اجرای اپ — اسپم نمی‌کنه). ورودهای بعدی
///    فقط وضعیتِ مجوز رو چک می‌کنن، بدون دیالوگ.
///  - اگه لوکیشن لازمه ولی مجوز/GPS نیست، [LocationIssue] برمی‌گرده تا صفحه به
///    کاربر بگه «برای دیدن افراد نزدیک به خودت مجوز لوکیشن لازمه».
class LocationGate {
  LocationGate._();

  static const String _sentAtKey = 'location_sent_at_ms';
  static const Duration maxAge = Duration(hours: 48);

  // با هر بار بسته و باز شدنِ اپ (پروسه‌ی جدید) صفر می‌شه.
  static bool _askedThisLaunch = false;

  static Future<bool> isStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_sentAtKey);
      if (at == null) return true;
      return DateTime.now().millisecondsSinceEpoch - at >= maxAge.inMilliseconds;
    } catch (_) {
      return true;
    }
  }

  /// موقع خروج از حساب: لوکیشنِ حسابِ بعدی باید دوباره گرفته بشه.
  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sentAtKey);
    } catch (_) {}
  }

  /// [allowPrompt] = اجازه‌ی نشون دادنِ دیالوگِ مجوز (فقط اولین ورود بعد از باز
  /// شدنِ اپ). [userInitiated] = کاربر خودش دکمه‌ی «فعال‌سازی» رو زده.
  /// بدون هیچ‌کدوم، فقط بی‌صدا وضعیتِ مجوز چک می‌شه و اگه مجوز بود و لوکیشن
  /// منقضی شده بود، لوکیشنِ جدید فرستاده می‌شه.
  static Future<LocationResult> ensure({
    bool allowPrompt = false,
    bool userInitiated = false,
  }) async {
    final stale = await isStale();

    LocationPermission perm;
    try {
      perm = await Geolocator.checkPermission();
    } catch (_) {
      return const LocationResult(LocationIssue.none);
    }

    if (perm == LocationPermission.denied &&
        (userInitiated || (allowPrompt && !_askedThisLaunch))) {
      _askedThisLaunch = true;
      try {
        perm = await Geolocator.requestPermission();
      } catch (_) {}
    }

    final granted =
        perm == LocationPermission.whileInUse || perm == LocationPermission.always;
    if (!granted) {
      if (!stale) return const LocationResult(LocationIssue.none);
      return LocationResult(perm == LocationPermission.deniedForever
          ? LocationIssue.deniedForever
          : LocationIssue.denied);
    }
    if (!stale) return const LocationResult(LocationIssue.none);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationIssue.serviceOff);
      }
      final position = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.low))
          .timeout(const Duration(seconds: 8));
      await ApiClient.updateLocation(position.latitude, position.longitude);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sentAtKey, DateTime.now().millisecondsSinceEpoch);
      return const LocationResult(LocationIssue.none, updated: true);
    } catch (_) {
      // نتونستیم بگیریم/بفرستیم (تایم‌اوت، شبکه...)؛ دفعه‌ی بعد دوباره تلاش می‌شه.
      return const LocationResult(LocationIssue.none);
    }
  }

  static Future<void> openSettings(LocationIssue issue) async {
    try {
      if (issue == LocationIssue.serviceOff) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {}
  }
}
