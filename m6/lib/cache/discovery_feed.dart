import '../models/profile_models.dart';
import 'card_cache.dart';
import 'discovery_queue.dart';

/// چسبی بینِ [DiscoveryQueue]، [CardCache] و درخواستِ /api/discovery — همون کد برای
/// Swipe و Explore (Explore فقط یه کلیدِ دیگه و `exploreId` تو closureِ [fetch] داره؛
/// منطقِ Discoveryِ جدایی وجود نداره).
///
/// [fetch] باید دقیقاً یه درخواست به GET /api/discovery (lean=1، limit=25) بزنه و
/// [exclude] رو بفرسته.
class DiscoveryFeed {
  DiscoveryFeed({
    required this.key,
    required this.filters,
    required this.mode,
    required this.fetch,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String key;
  final String filters;
  final String mode; // 'new' | 'all'
  final Future<List<DiscoveryCandidate>> Function(List<String> exclude) fetch;
  final DateTime Function() _clock;

  DiscoveryQueue? queue;
  bool fetching = false;

  /// دیسک → صف → استک (از CardCache). صفِ منقضی‌شده (>= ۲۴ ساعت) دور ریخته می‌شه.
  Future<List<DiscoveryCandidate>> restore() async {
    await CardCache.instance.ensureLoaded();
    final q = await DiscoveryQueueStore.instance.load(key);
    if (q == null) return const [];
    if (q.isExpired(_clock())) {
      await DiscoveryQueueStore.instance.delete(key);
      return const [];
    }
    queue = q;
    return q.resolveStack();
  }

  /// باید batchِ بعدی گرفته بشه؟ (seen >= 70٪، یا صفِ خالی/منقضی)؛ معیارش طولِ استک نیست.
  bool get needsFetch => queue == null || queue!.shouldFetchNext(_clock());

  bool get exhausted => queue?.exhausted ?? false;

  /// یه batch از سرور می‌گیره، کارت‌ها رو تو CardCache می‌ذاره، صف رو به‌روز و ذخیره
  /// می‌کنه و استکِ کاملِ نخوانده‌ها رو برمی‌گردونه.
  Future<List<DiscoveryCandidate>> fetchNext({List<String> exclude = const []}) async {
    final now = _clock();
    final q = queue;
    final carried = (q == null || q.isExpired(now)) ? const <String>[] : q.unseen.map((e) => e.id).toList();
    final batch = await fetch({...exclude, ...carried}.toList());

    await CardCache.instance.putAll(batch);
    final next = q ??
        DiscoveryQueue(key: key, fetchedAt: now, items: [], seen: {}, filters: filters, mode: mode);
    next.applyBatch(
      [for (final c in batch) QueueItem.fromCandidate(c)],
      limit: DiscoveryQueue.batchSize,
      now: now,
    );
    queue = next;
    await DiscoveryQueueStore.instance.save(next);
    return next.resolveStack();
  }

  void markSeen(String id) {
    final q = queue;
    if (q == null) return;
    q.markSeen(id);
    DiscoveryQueueStore.instance.save(q);
  }

  /// Rewind: کارت دوباره نخوانده حساب می‌شه.
  void unmarkSeen(String id) {
    final q = queue;
    if (q == null) return;
    q.unmarkSeen(id);
    DiscoveryQueueStore.instance.save(q);
  }
}
