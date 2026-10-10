import 'package:flutter/foundation.dart';

import '../api_client.dart';

/// ثابت‌های نمایشیِ بوست. منبعِ حقیقت سرورِ (store/boost_config.go)؛ مقدارِ واقعی از
/// GET /api/boost/status می‌آد و این‌ها فقط پیش‌فرضِ قبل از رسیدنِ جوابن.
class BoostConfig {
  BoostConfig._();
  static const int defaultViewBudget = 200;
  static const int defaultDurationHours = 72;
}

/// یه بوست (فعال یا تاریخچه). فقط عدد؛ هیچ هویتی از لایک‌کننده‌ها نیست.
class BoostInfo {
  final int id;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime? finishedAt;
  final bool active;
  final int views, likes, supers, passes, matches, viewBudget;

  const BoostInfo({
    required this.id,
    required this.startedAt,
    required this.endsAt,
    required this.finishedAt,
    required this.active,
    required this.views,
    required this.likes,
    required this.supers,
    required this.passes,
    required this.matches,
    required this.viewBudget,
  });

  factory BoostInfo.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return BoostInfo(
      id: n('id'),
      startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
      endsAt: DateTime.parse(j['ends_at'] as String).toLocal(),
      finishedAt: j['finished_at'] == null ? null : DateTime.parse(j['finished_at'] as String).toLocal(),
      active: j['status'] == 'active',
      views: n('views'),
      likes: n('likes'),
      supers: n('supers'),
      passes: n('passes'),
      matches: n('matches'),
      viewBudget: n('view_budget') == 0 ? BoostConfig.defaultViewBudget : n('view_budget'),
    );
  }

  Duration get remaining {
    final d = endsAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }
}

/// پیام‌های فارسیِ خطاهای بوست (کدها از سرورن).
String boostErrorMessage(Object e) {
  final code = e is ApiException ? e.code : '';
  switch (code) {
    case 'boost_no_credits':
      return 'بوستی تو موجودیت نیست.';
    case 'boost_disabled':
      return 'بوست فعلاً غیرفعاله.';
    case 'boost_buy_closed':
      return 'فعلاً امکان خرید بوست جدید نیست.';
    case 'boost_already_active':
      return 'الان یه بوست فعال داری.';
    case 'boost_profile_incomplete':
      return 'برای بوست، اول پروفایلت رو کامل کن و حداقل یه عکس بذار.';
    case 'boost_capacity':
      return 'الان ظرفیت بوست پره؛ کمی بعد دوباره امتحان کن.';
    case 'payment_unavailable':
      return 'پرداخت هنوز فعال نشده.';
    case 'too_many_requests':
      return 'چند لحظه صبر کن و دوباره امتحان کن.';
  }
  if (e is NetworkException) return 'ارتباط با سرور برقرار نشد.';
  return 'مشکلی پیش اومد؛ دوباره امتحان کن.';
}

/// وضعیتِ بوستِ کاربر: موجودی، بوستِ فعال و اجازه‌ی خریدِ امروز (can_buy).
class BoostState extends ChangeNotifier {
  BoostState._();
  static final BoostState instance = BoostState._();

  bool loaded = false;
  int credits = 0;
  BoostInfo? active;

  /// «امروز خریدِ بوستِ جدید مجازه؟» — فقط خرید رو می‌بنده، نه فعال‌سازی و نه بوستِ در حال اجرا.
  bool canBuy = true;

  /// کلیدِ سراسریِ ادمین: false = بوست کلاً خاموشه (نه خرید، نه فعال‌سازی).
  bool enabled = true;
  int viewBudget = BoostConfig.defaultViewBudget;
  int durationHours = BoostConfig.defaultDurationHours;

  void _apply(Map<String, dynamic> j) {
    loaded = true;
    credits = (j['credits'] as num?)?.toInt() ?? 0;
    final a = j['active'];
    active = a is Map ? BoostInfo.fromJson(Map<String, dynamic>.from(a)) : null;
    canBuy = j['can_buy'] != false;
    enabled = j['enabled'] != false;
    viewBudget = (j['view_budget'] as num?)?.toInt() ?? viewBudget;
    durationHours = (j['duration_hours'] as num?)?.toInt() ?? durationHours;
    notifyListeners();
  }

  /// خطا (شبکه) بی‌صدا نادیده گرفته می‌شه؛ مقدارِ قبلی می‌مونه.
  Future<void> refresh() async {
    try {
      _apply(await ApiClient.fetchBoostStatus());
    } catch (_) {}
  }

  /// فعال‌سازی از موجودی. خطا رو (ApiException) برای نمایش پرت می‌کنه.
  Future<void> activate() async => _apply(await ApiClient.activateBoost());

  Future<void> buy() async => _apply(await ApiClient.buyBoost());

  /// خروج از حساب.
  void clear() {
    loaded = false;
    credits = 0;
    active = null;
    canBuy = true;
    enabled = true;
    notifyListeners();
  }
}
