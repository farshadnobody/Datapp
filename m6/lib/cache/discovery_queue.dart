import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/profile_models.dart';
import 'card_cache.dart';

/// صفِ پایدارِ Discovery روی دیسک — یه کلاس برای Swipe و Explore (هر کلید یه صفِ
/// مستقل: `swipe|<فیلترها>|<mode>` و `explore:<category.id>|<mode>`).
///
/// صف فقط «ترتیبِ public_id + version» رو نگه می‌داره؛ بدنه‌ی کارت‌ها تو [CardCache]ئه.
/// سیاستِ batch:
///  - هر batch ۲۰–۲۵ کارته.
///  - تا وقتی seen < ۷۰٪ و عمرِ batch < ۲۴ ساعت، Discovery جدید گرفته نمی‌شه.
///  - seen >= ۷۰٪ → batchِ بعدی. عمر >= ۲۴ ساعت → صفِ قبلی منقضیه و دور ریخته می‌شه.
///  - ۲۴ ساعت «حداکثر عمرِ batch»ـه، نه refresh دوره‌ای.
class DiscoveryQueue {
  static const int batchSize = 25;
  static const double fetchNextAtSeenRatio = 0.7;
  static const Duration maxAge = Duration(hours: 24);

  final String key;
  DateTime fetchedAt;
  final List<QueueItem> items;
  final Set<String> seen;

  /// سرور برای این mode کمتر از limit داد → این tier تموم شده.
  bool exhausted;

  /// فیلترهای استفاده‌شده برای ساختنِ این صف (تو کلید هم هست؛ برای دیباگ/اعتبارسنجی).
  final String filters;
  final String mode; // 'new' | 'all'

  DiscoveryQueue({
    required this.key,
    required this.fetchedAt,
    required this.items,
    required this.seen,
    this.exhausted = false,
    this.filters = '',
    this.mode = 'new',
  });

  bool isExpired(DateTime now) => now.difference(fetchedAt) >= maxAge;

  double get seenRatio => items.isEmpty ? 1.0 : seen.length / items.length;

  /// آیا باید batchِ بعدی گرفته بشه؟ (ثابت و مستقل از طولِ استک)
  bool shouldFetchNext(DateTime now) =>
      isExpired(now) || (!exhausted && (items.isEmpty || seenRatio >= fetchNextAtSeenRatio));

  List<QueueItem> get unseen => [for (final i in items) if (!seen.contains(i.id)) i];

  void markSeen(String id) => seen.add(id);
  void unmarkSeen(String id) => seen.remove(id);

  /// batchِ جدید: وقتی صف منقضیه کلاً جایگزین می‌شه؛ وگرنه نخوانده‌های قبلی + batch جدید.
  void applyBatch(List<QueueItem> batch, {required int limit, required DateTime now}) {
    final keep = isExpired(now) ? <QueueItem>[] : unseen;
    final have = {for (final i in keep) i.id};
    items
      ..clear()
      ..addAll(keep)
      ..addAll(batch.where((b) => !have.contains(b.id)));
    seen.clear();
    fetchedAt = now;
    exhausted = batch.length < limit;
  }

  /// استکِ قابل‌نمایش از روی CardCache: فقط نخوانده‌هایی که کارتشون (با نسخه‌ی کافی)
  /// تو کشه. کارتِ evict/ناموجود رد می‌شه.
  List<DiscoveryCandidate> resolveStack() {
    final out = <DiscoveryCandidate>[];
    for (final it in unseen) {
      final c = CardCache.instance.getIfFresh(it.id, it.version);
      if (c == null) continue;
      c.previousDirection = it.previousDirection;
      out.add(it.superLikedMe ? _withSuperLike(c) : c);
    }
    return out;
  }

  static DiscoveryCandidate _withSuperLike(DiscoveryCandidate c) => DiscoveryCandidate(
        publicId: c.publicId, name: c.name, age: c.age, bio: c.bio,
        interests: c.interests, prompts: c.prompts, photos: c.photos,
        distanceKm: c.distanceKm, version: c.version,
        previousDirection: c.previousDirection, superLikedMe: true,
        detailsLoaded: c.detailsLoaded,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'seen': seen.toList(),
        'exhausted': exhausted,
        'filters': filters,
        'mode': mode,
      };

  factory DiscoveryQueue.fromJson(Map<String, dynamic> j) => DiscoveryQueue(
        key: j['key'] as String,
        fetchedAt: DateTime.parse(j['fetched_at'] as String),
        items: [for (final e in (j['items'] as List)) QueueItem.fromJson(e as Map<String, dynamic>)],
        seen: {for (final e in (j['seen'] as List? ?? const [])) '$e'},
        exhausted: j['exhausted'] == true,
        filters: (j['filters'] as String?) ?? '',
        mode: (j['mode'] as String?) ?? 'new',
      );
}

class QueueItem {
  final String id;
  final int version;
  final String? previousDirection; // وابسته به بیننده → تو صف، نه تو کش
  final bool superLikedMe;
  const QueueItem(this.id, this.version, {this.previousDirection, this.superLikedMe = false});

  factory QueueItem.fromCandidate(DiscoveryCandidate c) => QueueItem(
        c.publicId, c.version,
        previousDirection: c.previousDirection, superLikedMe: c.superLikedMe);

  Map<String, dynamic> toJson() => {
        'id': id,
        'v': version,
        if (previousDirection != null) 'prev': previousDirection,
        if (superLikedMe) 'sl': true,
      };

  factory QueueItem.fromJson(Map<String, dynamic> j) => QueueItem(
        j['id'] as String, (j['v'] as num).toInt(),
        previousDirection: j['prev'] as String?, superLikedMe: j['sl'] == true);
}

/// ذخیره/بازیابیِ صف‌ها (هر کلید یه فایل زیرِ queues/). نوشتن: tmp → rename.
class DiscoveryQueueStore {
  DiscoveryQueueStore._({Future<Directory> Function()? dirProvider})
      : _dirProvider = dirProvider ?? getApplicationSupportDirectory;
  static final DiscoveryQueueStore instance = DiscoveryQueueStore._();
  factory DiscoveryQueueStore.forTesting(Future<Directory> Function() dirProvider) =>
      DiscoveryQueueStore._(dirProvider: dirProvider);

  final Future<Directory> Function() _dirProvider;

  Future<Directory> _dir() async {
    final base = await _dirProvider();
    final d = Directory('${base.path}/queues');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // اسمِ فایل از کلید ساخته می‌شه (hex)، پس کاراکترِ ناجور تو مسیر نمی‌ره.
  String _name(String key) =>
      '${key.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}.json';

  Future<DiscoveryQueue?> load(String key) async {
    try {
      final f = File('${(await _dir()).path}/${_name(key)}');
      if (!await f.exists()) return null;
      return DiscoveryQueue.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(DiscoveryQueue q) async {
    try {
      final f = File('${(await _dir()).path}/${_name(q.key)}');
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(q.toJson()), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }

  Future<void> delete(String key) async {
    try {
      final f = File('${(await _dir()).path}/${_name(key)}');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// logout: همه‌ی صف‌های Swipe و Explore.
  Future<void> clearAll() async {
    try {
      final d = Directory('${(await _dirProvider()).path}/queues');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}
