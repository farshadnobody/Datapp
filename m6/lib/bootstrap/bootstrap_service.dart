import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../promo/promo_models.dart';
import '../promo/promo_service.dart';
import '../realtime/realtime_service.dart';
import '../subscription/subscription_state.dart';
import '../likes/likes_store.dart';
import '../chat/conversations_store.dart';

/// شمارنده‌ی لایک‌ها (برای نوارِ پایین، تیزرِ تبِ چت و صفحه‌ی لایک‌ها).
///  - رایگان: از bootstrap میاد و حداکثر هر «یک ساعت» به‌روز می‌شه (انقضا روی گوشی ذخیره
///    می‌شه، پس با بستن و باز کردنِ اپ هم درست می‌مونه).
///  - اشتراکی: از لایک‌های ذخیره‌شده‌ی روی گوشی ([LikesStore]) حساب می‌شه.
class AppCounters extends ChangeNotifier {
  AppCounters._();
  static final AppCounters instance = AppCounters._();

  static const String _countKey = 'likes_counter_count';
  static const String _superKey = 'likes_counter_super';
  static const String _atKey = 'likes_counter_at';
  static const Duration freeTtl = Duration(hours: 1);

  int likesCount = 0;
  int superLikeCount = 0;
  DateTime? fetchedAt; // آخرین باری که از «سرور» گرفتیم (فقط رایگان‌ها)

  bool get stale => fetchedAt == null || DateTime.now().difference(fetchedAt!) >= freeTtl;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      likesCount = prefs.getInt(_countKey) ?? 0;
      superLikeCount = prefs.getInt(_superKey) ?? 0;
      final at = prefs.getInt(_atKey);
      fetchedAt = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    } catch (_) {}
  }

  /// [fromServer]=true یعنی عددِ تازه از سرور (برای رایگان‌ها) و انقضای یک‌ساعته از همین
  /// لحظه شروع می‌شه.
  void setLikes(int v, {int superCount = 0, bool fromServer = false}) {
    final changed = v != likesCount || superCount != superLikeCount;
    likesCount = v;
    superLikeCount = superCount;
    if (fromServer) {
      fetchedAt = DateTime.now();
      _persist();
    }
    if (changed || fromServer) notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_countKey, likesCount);
      await prefs.setInt(_superKey, superLikeCount);
      if (fetchedAt != null) await prefs.setInt(_atKey, fetchedAt!.millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> clear() async {
    likesCount = 0;
    superLikeCount = 0;
    fetchedAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in [_countKey, _superKey, _atKey]) {
        await prefs.remove(k);
      }
    } catch (_) {}
    notifyListeners();
  }
}

/// «درخواستِ اولیه»: به‌جای ۵ تا ۶ درخواستِ جدا، اپ یه درخواست (GET /api/bootstrap) می‌زنه.
///  - داده‌های زنده (اشتراک، سهمیه‌ها، تعدادِ لایک‌ها) همیشه میان.
///  - داده‌های کم‌تغییر (تبلیغ‌ها، پلن‌ها، گزینه‌های پروفایل) فقط وقتی «نسخه»‌شون با
///    نسخه‌ی ذخیره‌شده‌ی اپ فرق داشته باشه میان؛ وگرنه همون نسخه‌ی روی گوشی استفاده می‌شه.
///
/// دوباره‌صدا زدن: وقتی اپ باز می‌شه، از پس‌زمینه برمی‌گرده، WebSocket بعد از قطعی وصل
/// می‌شه، یا سرور خبر بده «تنظیمات/حساب عوض شد» (که با تأخیرِ تصادفی، تا ۲۰۰۰ نفر
/// هم‌زمان نزنن).
class BootstrapService {
  BootstrapService._();
  static final BootstrapService instance = BootstrapService._();

  static const String _versionsKey = 'bs_versions';
  static const String _promosKey = 'bs_promos_json';
  static const String _plansKey = 'bs_plans_json';
  static const String optionsKey = 'bs_options_json';
  static const Duration _minGap = Duration(seconds: 20);

  Map<String, String> _versions = {};
  bool _loaded = false;
  bool _running = false;
  DateTime? _last;
  StreamSubscription? _sub;
  Timer? _jitterTimer;

  /// یه بار موقعِ شروعِ اپ: نسخه‌ها و دیتای ذخیره‌شده رو می‌خونه و به رویدادهای سرور گوش می‌ده.
  Future<void> init() async {
    await AppCounters.instance.load();
    await _loadCached();
    _sub ??= RealtimeService.instance.events.listen((e) {
      switch (e.type) {
        case 'connected':
          if (e.data['reconnect'] == true) {
            refresh();
            // فقط وقتی صفحه‌ی Likes باز/زنده‌ست؛ هیچ لود حجیمی تو bootstrap نیست.
            if (SubscriptionState.instance.isPremium && LikesStore.instance.screenOpen) {
              LikesStore.instance.refreshFirstPage();
            }
          }
          break;
        case 'account_changed':
          refresh(force: true); // بن/اشتراک عوض شد: فوری
          break;
        case 'likes_changed':
          // فقط به اشتراکی‌ها فرستاده می‌شه. اگه صفحه‌ی Likes باز نیست کاری نمی‌کنیم؛
          // اگه بازه فقط صفحه‌ی اولِ IDها refresh می‌شه و versionها با CardCache مقایسه می‌شن.
          if (SubscriptionState.instance.isPremium && LikesStore.instance.screenOpen) {
            LikesStore.instance.refreshFirstPage();
          }
          break;
        case 'like_removed':
          LikesStore.instance.remove('${e.data['from']}'); // همون لحظه از گوشی پاک می‌شه
          break;
        case 'config_changed':
          // تنظیمات/تبلیغ/پلن عوض شد. همه‌ی اپ‌ها هم‌زمان خبردار می‌شن، پس تا ۳۰ ثانیه
          // پخش‌شون می‌کنیم.
          _jitterTimer?.cancel();
          _jitterTimer = Timer(Duration(milliseconds: math.Random().nextInt(30000)), () => refresh(force: true));
          break;
      }
    });
  }

  Future<void> _loadCached() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_versionsKey);
      if (raw != null) {
        _versions = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, '$v'));
      }
      final promosRaw = prefs.getString(_promosKey);
      if (promosRaw != null) {
        final list = (jsonDecode(promosRaw) as List)
            .map((e) => Promo.fromJson(e as Map<String, dynamic>))
            .toList();
        PromoService.instance.applyList(list, notify: false);
      }
    } catch (_) {}
    _loaded = true;
  }

  // true تا اولین bootstrapِ موفقِ این بار باز شدنِ اپ (نه برگشت از پس‌زمینه).
  bool _coldStart = false;

  /// موقعِ باز شدنِ اپ (HomeScreen.initState).
  void markColdStart() => _coldStart = true;

  Future<void> refresh({bool force = false}) async {
    if (_running) return;
    final last = _last;
    if (!force && last != null && DateTime.now().difference(last) < _minGap) return;
    _running = true;
    try {
      await _loadCached();
      final json = await ApiClient.bootstrap(
        promosVersion: _versions['promos'],
        plansVersion: _versions['plans'],
        optionsVersion: _versions['options'],
        // شمارنده‌ی لایک‌ها فقط وقتی خواسته می‌شه که از آخرین دریافتش یه ساعت گذشته باشه
        // (سرور برای اشتراکی‌ها هیچ‌وقت نمی‌فرستدش).
        likesCounts: AppCounters.instance.stale,
      );
      await _apply(json);
      _last = DateTime.now();
    } catch (_) {
      // شبکه/خطا: همون داده‌ی قبلی می‌مونه.
    } finally {
      _running = false;
    }
  }

  Future<void> _apply(Map<String, dynamic> json) async {
    // ۱) داده‌های زنده
    final wasPremium = SubscriptionState.instance.isPremium;
    final sub = json['subscription'];
    if (sub is Map<String, dynamic>) {
      SubscriptionState.instance.applyStatus(SubscriptionStatus.fromJson(sub));
    }
    final premium = SubscriptionState.instance.isPremium;
    // Bootstrap دیگه هیچ Likes sync ای اجرا نمی‌کنه؛ لایک‌ها با باز شدنِ صفحه‌ی Likes لود می‌شن.
    if (!premium && wasPremium) {
      LikesStore.instance.clear(); // اشتراک تموم شد
    }
    _coldStart = false;

    final likes = json['likes'];
    if (likes is Map<String, dynamic> && !premium) {
      AppCounters.instance.setLikes(
        (likes['count'] as num?)?.toInt() ?? 0,
        superCount: (likes['super_like_count'] as num?)?.toInt() ?? 0,
        fromServer: true,
      );
    }

    // ۲) داده‌های کم‌تغییر: فقط اگه سرور فرستاده (یعنی نسخه عوض شده)
    final versions = (json['versions'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {};
    final prefs = await SharedPreferences.getInstance();

    if (json['promos'] is List) {
      final list = (json['promos'] as List)
          .map((e) => Promo.fromJson(e as Map<String, dynamic>))
          .toList();
      PromoService.instance.applyList(list);
      await prefs.setString(_promosKey, jsonEncode(json['promos']));
    }
    if (json['plans'] is List) {
      await prefs.setString(_plansKey, jsonEncode(json['plans']));
    }
    if (json['options'] is Map) {
      await prefs.setString(optionsKey, jsonEncode(json['options']));
    }

    // نسخه‌ها فقط بعد از اعمالِ موفق ذخیره می‌شن.
    _versions = {..._versions, ...versions};
    await prefs.setString(_versionsKey, jsonEncode(_versions));
  }

  /// موقعِ خروج از حساب: داده‌ی این کاربر نباید برای حسابِ بعدی بمونه.
  Future<void> clear() async {
    _versions = {};
    _loaded = false;
    _last = null;
    _jitterTimer?.cancel();
    AppCounters.instance.clear();
    LikesStore.instance.clear();
    ConversationsStore.instance.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in [_versionsKey, _promosKey, _plansKey, optionsKey]) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
