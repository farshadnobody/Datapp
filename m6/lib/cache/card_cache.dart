import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/profile_models.dart';

/// CardCache سراسری: یه نسخه‌ی مشترک برای Likes، Swipe و Explore.
///
/// قوانین:
///  - کارت با public_id شناخته می‌شه و فقط وقتی دوباره گرفته می‌شه که تو کش نباشه یا
///    version سرور (profiles.updated_at به UnixMilli) از نسخه‌ی کش بزرگ‌تر باشه.
///  - حذفِ یه کارت از لیستِ Likes (یا هر صفحه‌ی دیگه) ربطی به کش نداره؛ کش فقط تو
///    [clear] (logout) و تو [evictIfNeeded] (LRU) کم می‌شه.
///  - سقف: ۲۰۰۰ کارت یا ۲۰۰MB، هرکدوم زودتر رسید؛ eviction بر اساس last_accessed (LRU).
///  - رمزگذاری نمی‌شه. نوشتن اتمیک: فایل tmp → rename.
///  - فقط «محتوای کارت» نگه داشته می‌شه (نگاه کن به DiscoveryCandidate.toCacheJson)؛
///    previous_direction / super_liked_me وابسته به بیننده‌ان و تو کش نیستن.
class CardCache {
  CardCache({
    Future<Directory> Function()? dirProvider,
    this.maxCards = 2000,
    this.maxBytes = 200 * 1024 * 1024,
    DateTime Function()? clock,
  })  : _dirProvider = dirProvider ?? getApplicationSupportDirectory,
        _clock = clock ?? DateTime.now;

  static final CardCache instance = CardCache();

  final int maxCards;
  final int maxBytes;
  final Future<Directory> Function() _dirProvider;
  final DateTime Function() _clock;

  final Map<String, _Entry> _map = {};
  int _bytes = 0;
  bool _loaded = false;
  Future<void>? _loading;
  Timer? _flushTimer;
  Future<void> _writeChain = Future.value();

  int get length => _map.length;
  int get totalBytes => _bytes;
  bool contains(String id) => _map.containsKey(id);

  Future<File> _file() async {
    final dir = await _dirProvider();
    return File('${dir.path}/card_cache.json');
  }

  /// قبل از هر استفاده (و قبل از getIfFresh که sync ـه) یه بار صدا زده می‌شه.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final data = jsonDecode(await f.readAsString());
        final items = (data is Map ? data['items'] : null) as List? ?? const [];
        for (final raw in items) {
          final e = _Entry.fromJson(raw as Map<String, dynamic>);
          _map[e.id] = e;
          _bytes += e.bytes;
        }
      }
    } catch (_) {
      // فایل خراب = کشِ خالی؛ کارت‌ها دوباره گرفته می‌شن.
      _map.clear();
      _bytes = 0;
    }
    _loaded = true;
  }

  /// کارت فقط وقتی برمی‌گرده که نسخه‌ی کش >= نسخه‌ی سرور باشه. دسترسی موفق،
  /// last_accessed رو به‌روز می‌کنه (LRU).
  DiscoveryCandidate? getIfFresh(String id, int serverVersion) {
    final e = _map[id];
    if (e == null || e.version < serverVersion) return null;
    e.lastAccessed = _clock().millisecondsSinceEpoch;
    _scheduleFlush();
    return DiscoveryCandidate.fromJson(e.card);
  }

  /// کارتِ کش‌شده بدونِ چکِ تازگی (برای مقایسه‌ی نسخه با سرور موقعِ باز کردنِ پروفایل).
  /// null اگه تو کش نیست. detailsLoaded اونجا true ـه که جزئیاتِ همون نسخه هم تو کشه.
  DiscoveryCandidate? getAny(String id) {
    final e = _map[id];
    if (e == null) return null;
    e.lastAccessed = _clock().millisecondsSinceEpoch;
    _scheduleFlush();
    return DiscoveryCandidate.fromJson(e.card);
  }

  /// از بین {public_id: serverVersion}، اونایی که تو کش نیستن یا کهنه‌ان.
  List<String> missingOrStale(Map<String, int> idsWithVersions) {
    final out = <String>[];
    idsWithVersions.forEach((id, serverVersion) {
      final e = _map[id];
      if (e == null || e.version < serverVersion) out.add(id);
    });
    return out;
  }

  /// کارت‌ها رو (با version خودشون) تو کش می‌ذاره. نسخه‌ی قدیمی‌تر هیچ‌وقت جای
  /// جدیدتر نمی‌شینه.
  Future<void> putAll(Iterable<DiscoveryCandidate> cards) async {
    await ensureLoaded();
    final now = _clock().millisecondsSinceEpoch;
    for (final c in cards) {
      if (c.publicId.isEmpty) continue;
      final old = _map[c.publicId];
      if (old != null && old.version > c.version) continue;
      if (old != null && old.version == c.version) {
        old.lastAccessed = now;
        // همون نسخه: فقط وقتی جایگزین می‌شه که الان جزئیات رو داریم و کش نداره.
        final oldHasDetails = old.card['lean'] != true;
        if (oldHasDetails || !c.detailsLoaded) continue;
      }
      final json = c.toCacheJson();
      final bytes = utf8.encode(jsonEncode(json)).length;
      if (old != null) _bytes -= old.bytes;
      _map[c.publicId] = _Entry(c.publicId, c.version, now, json, bytes);
      _bytes += bytes;
    }
    await evictIfNeeded();
    await _flushNow();
  }

  /// یه کارت رو از کش پاک می‌کنه (مثلاً وقتی سرور گفته این کاربر دیگه وجود نداره / بن شده).
  Future<void> remove(String id) async {
    await ensureLoaded();
    final old = _map.remove(id);
    if (old == null) return;
    _bytes -= old.bytes;
    await _flushNow();
  }

  /// LRU: کم‌ترین last_accessed اول حذف می‌شه تا هر دو سقف رعایت بشه.
  Future<void> evictIfNeeded() async {
    await ensureLoaded();
    if (_map.length <= maxCards && _bytes <= maxBytes) return;
    final order = _map.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));
    for (final e in order) {
      if (_map.length <= maxCards && _bytes <= maxBytes) break;
      _map.remove(e.id);
      _bytes -= e.bytes;
    }
  }

  /// فقط موقعِ logout.
  Future<void> clear() async {
    _flushTimer?.cancel();
    _map.clear();
    _bytes = 0;
    _loaded = true;
    _loading = null;
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
      final tmp = File('${f.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {}
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(const Duration(seconds: 3), () {
      _flushTimer = null;
      _flushNow();
    });
  }

  Future<void> _flushNow() {
    _flushTimer?.cancel();
    _flushTimer = null;
    // نوشتن‌ها پشتِ هم می‌رن تا دو rename هم‌زمان با هم قاطی نشن.
    return _writeChain = _writeChain.then((_) async {
      try {
        final f = await _file();
        final tmp = File('${f.path}.tmp');
        final body = jsonEncode({'items': _map.values.map((e) => e.toJson()).toList()});
        await tmp.writeAsString(body, flush: true);
        await tmp.rename(f.path);
      } catch (_) {}
    });
  }
}

class _Entry {
  final String id;
  final int version;
  int lastAccessed;
  final Map<String, dynamic> card;
  final int bytes;
  _Entry(this.id, this.version, this.lastAccessed, this.card, this.bytes);

  factory _Entry.fromJson(Map<String, dynamic> j) {
    final card = Map<String, dynamic>.from(j['card'] as Map);
    return _Entry(
      j['public_id'] as String,
      (j['version'] as num).toInt(),
      (j['last_accessed'] as num).toInt(),
      card,
      utf8.encode(jsonEncode(card)).length,
    );
  }

  Map<String, dynamic> toJson() => {
        'public_id': id,
        'version': version,
        'last_accessed': lastAccessed,
        'card': card,
      };
}
