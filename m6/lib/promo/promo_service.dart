import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bootstrap/bootstrap_service.dart';
import 'promo_models.dart';

/// تبلیغ‌های داخلِ اپ (پاپ‌آپ و باکسِ شناور) که از پنلِ ادمین تنظیم می‌شن.
///
/// تکرارِ نمایش:
///  - always: پاپ‌آپ هر بار که اپ باز می‌شه (یک‌بار تو هر اجرا)؛ باکس تا وقتی کاربر
///    تو همین اجرا نبسته‌شون.
///  - daily: حداکثر روزی یک‌بار (روی همین دستگاه)
///  - once : فقط یک‌بار (روی همین دستگاه)
class PromoService extends ChangeNotifier {
  PromoService._();
  static final PromoService instance = PromoService._();

  static const String _onceKey = 'promo_once_ids';
  static const String _lastKey = 'promo_last_shown';

  List<Promo> _all = const [];
  final Set<int> _shownThisSession = {};
  final Set<int> _dismissedThisSession = {};
  Set<int> _onceSeen = {};
  Map<int, int> _lastShown = {};
  bool _prefsLoaded = false;

  Future<void> _loadPrefs() async {
    if (_prefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _onceSeen = (prefs.getStringList(_onceKey) ?? const []).map(int.tryParse).whereType<int>().toSet();
      final raw = prefs.getString(_lastKey);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _lastShown = m.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
      }
    } catch (_) {}
    _prefsLoaded = true;
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_onceKey, _onceSeen.map((e) => '$e').toList());
      await prefs.setString(_lastKey, jsonEncode(_lastShown.map((k, v) => MapEntry('$k', v))));
    } catch (_) {}
  }

  /// لیستِ تبلیغ‌ها از bootstrap میاد (فقط وقتی نسخه‌اش عوض شده) و روی گوشی هم ذخیره
  /// می‌شه تا با باز شدنِ اپ بدونِ درخواست در دسترس باشه.
  void applyList(List<Promo> list, {bool notify = true}) {
    _all = list;
    if (notify) notifyListeners();
  }

  /// سازگاری با کدِ قبلی: همون «درخواستِ اولیه» رو صدا می‌زنه (که خودش تبلیغ‌ها رو هم
  /// فقط در صورتِ تغییرِ نسخه می‌گیره).
  Future<void> refresh({bool force = false}) => BootstrapService.instance.refresh(force: force);

  void clear() {
    _all = const [];
    _shownThisSession.clear();
    _dismissedThisSession.clear();
    notifyListeners();
  }

  bool _recent(int id) {
    final t = _lastShown[id];
    if (t == null) return false;
    return DateTime.now().millisecondsSinceEpoch - t < const Duration(hours: 24).inMilliseconds;
  }

  bool _eligiblePopup(Promo p) {
    if (_shownThisSession.contains(p.id)) return false;
    if (p.frequency == 'once' && _onceSeen.contains(p.id)) return false;
    if (p.frequency == 'daily' && _recent(p.id)) return false;
    return true;
  }

  bool _hiddenBanner(Promo p) {
    if (!p.closable) return false; // غیرقابل‌بسته همیشه می‌مونه
    if (_dismissedThisSession.contains(p.id)) return true;
    if (p.frequency == 'once' && _onceSeen.contains(p.id)) return true;
    if (p.frequency == 'daily' && _recent(p.id)) return true;
    return false;
  }

  /// باکس‌هایی که الان باید تو این صفحه دیده بشن (حداکثر ۳ تا).
  List<Promo> bannersFor(String screen) =>
      _all.where((p) => p.isBanner && p.showsOn(screen) && !_hiddenBanner(p)).take(3).toList();

  /// پاپ‌آپِ بعدی که باید تو این صفحه نشون داده بشه (یا null).
  Promo? nextPopup(String screen) {
    for (final p in _all) {
      if (p.isPopup && p.showsOn(screen) && _eligiblePopup(p)) return p;
    }
    return null;
  }

  /// لحظه‌ی نمایشِ پاپ‌آپ ثبت می‌شه (نه بسته شدنش)، تا پاپ‌آپی که نصفه رها شد
  /// دوباره و دوباره نیاد.
  void markPopupShown(Promo p) {
    _shownThisSession.add(p.id);
    if (p.frequency == 'once') _onceSeen.add(p.id);
    if (p.frequency == 'daily') _lastShown[p.id] = DateTime.now().millisecondsSinceEpoch;
    _savePrefs();
  }

  void dismissBanner(Promo p) {
    if (!p.closable) return;
    _dismissedThisSession.add(p.id);
    if (p.frequency == 'once') _onceSeen.add(p.id);
    if (p.frequency == 'daily') _lastShown[p.id] = DateTime.now().millisecondsSinceEpoch;
    _savePrefs();
    notifyListeners();
  }
}
