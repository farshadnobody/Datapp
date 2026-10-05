import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../auth_session.dart';
import '../realtime/realtime_service.dart';

/// صفِ «ردهای هنوز ارسال‌نشده». ردکردن (۶۰ تا ۷۰ درصدِ swipeها) جوابِ فوری نمی‌خواد، پس
/// به‌جای یه درخواست برای هر رد:
///   ۱) ردها تو صف (روی گوشی هم ذخیره می‌شه، پس با بستنِ اپ یا قطعیِ اینترنت گم نمی‌شه)
///   ۲) همراهِ «لایک/سوپرلایکِ» بعدی تو همون درخواست می‌رن (ترتیبِ تاریخچه درست می‌مونه)
///   ۳) یا با تایمر (۶۰ ثانیه)، وقتی ۲۰ تا شد، موقعِ رفتن به پس‌زمینه، خروج از تبِ سواپ،
///      قبل از گرفتنِ کارت‌های جدید، قبل از Rewind، و برگشتنِ اتصال، یکجا فرستاده می‌شن.
/// ارسالِ مجدد بی‌خطره (ثبتِ رد idempotent ـه)، پس شکستِ شبکه فقط یعنی «بعداً دوباره».
class SwipeOutbox with WidgetsBindingObserver {
  SwipeOutbox._();
  static final SwipeOutbox instance = SwipeOutbox._();

  static const String _key = 'swipe_outbox_ids';
  static const int _flushAt = 20;
  static const int _piggybackMax = 50;
  static const Duration _interval = Duration(seconds: 60);

  final List<String> _ids = [];
  bool _flushing = false;
  int _failures = 0;
  Timer? _timer;
  Timer? _saveTimer;
  StreamSubscription? _sub;
  bool _inited = false;

  /// شناسه‌ی کسانی که ردشون کردیم ولی هنوز به سرور نرسیده (برای استثنا از کارت‌های بعدی).
  List<String> get ids => List.unmodifiable(_ids);

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) _ids.addAll((jsonDecode(raw) as List).map((e) => '$e'));
    } catch (_) {}
    WidgetsBinding.instance.addObserver(this);
    _sub = RealtimeService.instance.events.listen((e) {
      if (e.type == 'connected') flush(); // اتصال برگشت: هر چی مونده بفرست
    });
    if (_ids.isNotEmpty) _schedule();
  }

  void add(String publicId) {
    if (!_ids.contains(publicId)) _ids.add(publicId);
    _persist();
    if (_ids.length >= _flushAt) {
      flush();
    } else {
      _schedule();
    }
  }

  /// Rewindِ یه ردی که هنوز تو صفه: فقط از صف برداشته می‌شه، هیچ درخواستی لازم نیست.
  bool removeIfQueued(String publicId) {
    final removed = _ids.remove(publicId);
    if (removed) _persist();
    return removed;
  }

  /// ردهایی که همراهِ یه لایک/سوپرلایک می‌رن (بدونِ برداشتن از صف؛ بعد از موفقیت
  /// با [confirmSent] برداشته می‌شن).
  List<String> pendingForPiggyback() => _ids.take(_piggybackMax).toList();

  void confirmSent(List<String> sent) {
    if (sent.isEmpty) return;
    final set = sent.toSet();
    _ids.removeWhere(set.contains);
    _persist();
  }

  void _schedule() {
    _timer ??= Timer(_interval, () {
      _timer = null;
      flush();
    });
  }

  /// همه‌ی ردهای مونده رو (۱۰۰تا ۱۰۰تا) می‌فرسته.
  Future<void> flush() async {
    if (_flushing || _ids.isEmpty || AuthSession.token == null) return;
    _flushing = true;
    _timer?.cancel();
    _timer = null;
    try {
      while (_ids.isNotEmpty) {
        final chunk = _ids.take(100).toList();
        try {
          await ApiClient.swipeBatch(chunk);
        } on ApiException catch (e) {
          // محدودیتِ نرخ: بعداً. هر خطای دیگه‌ی سرور (۴۰۰ و...) یعنی دوباره فرستادنش
          // فایده‌ای نداره؛ دور ریخته می‌شه تا صف برای همیشه گیر نکنه.
          if (e.code == 'too_many_requests') rethrow;
        }
        confirmSent(chunk);
      }
      _failures = 0;
    } catch (_) {
      // شبکه/محدودیت: ردها تو صف می‌مونن؛ با فاصله‌ی فزاینده (۳۰ثانیه تا ۵ دقیقه) دوباره.
      _failures++;
      final secs = (30 * (1 << (_failures - 1).clamp(0, 4))).clamp(30, 300);
      _timer?.cancel();
      _timer = Timer(Duration(seconds: secs), () {
        _timer = null;
        flush();
      });
    } finally {
      _flushing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) flush();
  }

  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(_ids));
      } catch (_) {}
    });
  }

  /// موقعِ خروج از حساب: ردهای این حساب برای حسابِ بعدی نباید بمونن.
  Future<void> clearLocal() async {
    _ids.clear();
    _timer?.cancel();
    _timer = null;
    _failures = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
