import 'package:flutter/foundation.dart';

import '../api_client.dart';
import '../bootstrap/bootstrap_service.dart';
import '../cache/card_cache.dart';
import 'likes_data.dart';

/// لیستِ لایک‌های «اشتراکی‌ها» — صفحه‌ای (سی‌تایی) و بر پایه‌ی CardCache:
///   ۱) GET /api/likes/ids?limit=30 فقط شناسه + version می‌ده (بدنه‌ی کارت نه).
///   ۲) versionها با CardCache مقایسه می‌شن؛ فقط missing/stale با
///      POST /api/likes/cards (حداکثر ۵۰ تا) گرفته می‌شه.
///   ۳) گرید از CardCache ساخته می‌شه. اسکرول: همون روند با cursor.
///
/// هیچ sync حجیمی نیست و تو bootstrap هم صدا زده نمی‌شه: فقط وقتی صفحه‌ی Likes
/// واقعاً باز شده لود می‌شه. حذفِ یه لایک (remove / like_removed) فقط از «لیست»
/// برمی‌داره؛ کارت تو CardCache می‌مونه.
class LikesStore extends ChangeNotifier {
  LikesStore._();
  static final LikesStore instance = LikesStore._();

  static const int pageSize = 30;
  static const int _cardsPerRequest = 50;

  final List<_Ref> _refs = [];
  String? _nextCursor;
  bool _loading = false; // صفحه‌ی اول
  bool _loadingMore = false;
  bool _screenOpen = false;
  int _total = 0;
  int _superTotal = 0;

  /// صفحه‌ی Likes ساخته شده (تب باز شده و زنده‌ست) → likes_changed باید صفحه‌ی اول رو
  /// refresh کنه.
  bool get screenOpen => _screenOpen;
  set screenOpen(bool v) => _screenOpen = v;

  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _nextCursor != null && _nextCursor!.isNotEmpty;
  int get count => _total;
  int get superCount => _superTotal;

  List<LikeEntry> get entries {
    final out = <LikeEntry>[];
    for (final r in _refs) {
      final c = CardCache.instance.getIfFresh(r.id, r.version);
      if (c == null) continue;
      out.add(LikeEntry(candidate: c, isSuperLike: r.isSuper, likedAt: r.likedAt));
    }
    return out;
  }

  Future<void> ensureLoaded() => CardCache.instance.ensureLoaded();

  /// ورود به صفحه‌ی Likes و رویدادِ likes_changed: فقط صفحه‌ی اولِ IDها.
  Future<void> refreshFirstPage() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      await ensureLoaded();
      final res = await ApiClient.fetchLikesIds(limit: pageSize);
      final page = _parseRefs(res);
      await _ensureCards(page);

      final firstIds = {for (final r in page) r.id};
      if (_refs.length <= pageSize) {
        _refs
          ..clear()
          ..addAll(page);
        _nextCursor = res['next_cursor'] as String?;
      } else {
        // کاربر چند صفحه پایین رفته بود: صفحه‌ی اول جدید + بقیه‌ی قبلی (cursor قبلی سر جاشه).
        final rest = _refs.where((r) => !firstIds.contains(r.id)).toList();
        _refs
          ..clear()
          ..addAll(page)
          ..addAll(rest);
      }
      _applyCounts(res);
    } on ApiException catch (e) {
      if (e.code == 'premium_required') await clear(); // اشتراک تموم شده
    } catch (_) {
      // شبکه: همون چیزی که تو حافظه/کش هست می‌مونه.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// اسکرول به انتهای گرید: صفحه‌ی بعدی با cursor.
  Future<void> loadMore() async {
    if (_loadingMore || _loading || !hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final res = await ApiClient.fetchLikesIds(cursor: _nextCursor, limit: pageSize);
      final page = _parseRefs(res);
      await _ensureCards(page);
      final have = {for (final r in _refs) r.id};
      _refs.addAll(page.where((r) => !have.contains(r.id)));
      _nextCursor = res['next_cursor'] as String?;
      _applyCounts(res);
    } on ApiException catch (e) {
      if (e.code == 'premium_required') await clear();
    } catch (_) {
      // دفعه‌ی بعد (اسکرولِ بعدی) دوباره تلاش می‌شه.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  List<_Ref> _parseRefs(Map<String, dynamic> res) => [
        for (final raw in (res['items'] as List? ?? const []))
          _Ref(
            id: (raw as Map)['public_id'] as String,
            version: (raw['version'] as num?)?.toInt() ?? 0,
            isSuper: raw['is_super_like'] == true,
            likedAt: DateTime.tryParse('${raw['liked_at'] ?? ''}'),
          ),
      ];

  /// فقط missing/stale از سرور گرفته و تو CardCache ذخیره می‌شه.
  Future<void> _ensureCards(List<_Ref> refs) async {
    final need = CardCache.instance.missingOrStale({for (final r in refs) r.id: r.version});
    for (var i = 0; i < need.length; i += _cardsPerRequest) {
      final chunk = need.sublist(i, i + _cardsPerRequest > need.length ? need.length : i + _cardsPerRequest);
      final cards = await ApiClient.fetchLikesCards(chunk);
      await CardCache.instance.putAll(cards);
    }
  }

  void _applyCounts(Map<String, dynamic> res) {
    _total = (res['count'] as num?)?.toInt() ?? _refs.length;
    _superTotal = (res['super_like_count'] as num?)?.toInt() ?? _refs.where((r) => r.isSuper).length;
    AppCounters.instance.setLikes(_total, superCount: _superTotal);
  }

  /// حذفِ یه آیتم از «لیستِ لایک‌ها» (رویدادِ like_removed، یا خودم لایک/ردش کردم).
  /// عمداً به CardCache دست نمی‌زنه.
  void remove(String publicId) {
    final i = _refs.indexWhere((r) => r.id == publicId);
    if (i < 0) return;
    final wasSuper = _refs[i].isSuper;
    _refs.removeAt(i);
    if (_total > 0) _total--;
    if (wasSuper && _superTotal > 0) _superTotal--;
    AppCounters.instance.setLikes(_total, superCount: _superTotal);
    notifyListeners();
  }

  /// خروج از حساب / پایانِ اشتراک: state لیست (نه CardCache؛ اون تو logout جدا پاک می‌شه).
  Future<void> clear() async {
    _refs.clear();
    _nextCursor = null;
    _total = 0;
    _superTotal = 0;
    _loading = false;
    _loadingMore = false;
    notifyListeners();
  }
}

class _Ref {
  final String id;
  final int version;
  final bool isSuper;
  final DateTime? likedAt;
  const _Ref({required this.id, required this.version, required this.isSuper, required this.likedAt});
}
