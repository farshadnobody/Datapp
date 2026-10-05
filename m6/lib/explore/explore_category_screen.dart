import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/match_models.dart';
import '../models/profile_models.dart';
import '../screens/matches_screen.dart';
import '../swipe/remove_like_flow.dart';
import '../swipe/rewind_memory.dart';
import '../swipe/swipe_action_bar.dart';
import '../swipe/swipe_card.dart';
import '../swipe/swipe_deck.dart';
import '../swipe/swipe_style.dart';
import 'explore_data.dart';
import '../widgets/app_network_image.dart';
import '../subscription/subscription_state.dart';
import '../subscription/premium_paywall.dart';
import '../swipe/swipe_outbox.dart';
import '../likes/likes_store.dart';
import '../cache/discovery_feed.dart';
import '../cache/discovery_queue.dart';

/// استکِ سواپِ مخصوصِ یه دسته‌ی اکسپلور — دقیقاً همون رفتارِ تیندر: با تپِ یه
/// تایل تو Explore، یه صفحه‌ی تمام‌صفحه باز می‌شه که فقط کاندیدهایی که تویِ
/// همون دسته جا می‌شن رو نشون می‌ده و مثلِ تبِ سواپِ اصلی می‌شه لایک/رد/
/// سوپرلایک کرد.
///
/// فیلترِ دسته کاملاً سمتِ سرور و تو همون /api/discovery انجام می‌شه
/// (`explore_id=<category.id>`)؛ کلاینت هیچ فیلتری انجام نمی‌ده و درخواستِ اضافه
/// برای پیدا کردنِ کارتِ مناسب نمی‌زنه. هر دسته (و هر mode: ندیده‌ها / دوباره ببین)
/// صفِ پایدارِ مستقلِ خودش رو داره؛ سیاستِ ۷۰٪ / ۲۴ ساعت مثلِ تبِ سواپ.
class ExploreCategoryScreen extends StatefulWidget {
  final ExploreCategory category;
  const ExploreCategoryScreen({super.key, required this.category});

  @override
  State<ExploreCategoryScreen> createState() => _ExploreCategoryScreenState();
}

class _ExploreCategoryScreenState extends State<ExploreCategoryScreen> {
  final SwipeDeckController _deck = SwipeDeckController();

  List<DiscoveryCandidate> _stack = [];
  final Set<String> _excluded = {}; // کارت‌هایی که تو همین session ازشون رد شدیم
  DiscoveryFeed? _feed;
  bool _rewinding = false;

  /// حالت «دوباره ببین»: بعد از دیدنِ همه‌ی پروفایل‌های دسته، با همون
  /// /api/discovery (mode=all) دوباره نشون داده می‌شن. هیچ تعاملی خودکار ثبت
  /// نمی‌شه — فقط وقتی کاربر خودش لایک/رد/سوپرلایک بزنه (upsert، بدون تکرار).
  bool _seeingAgain = false;

  ProfileOptions? _options;
  Set<String> _myInterests = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false; // سرور برای tierِ فعلی کمتر از limit داد
  int _generation = 0;
  String? _error;

  String? _expandedId;
  String? _lockedId;

  @override
  void initState() {
    super.initState();
    RewindMemory.instance.addListener(_onRewindMemoryChanged);
    SubscriptionState.instance.addListener(_onSubscriptionChanged);
    _init();
  }

  void _onRewindMemoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RewindMemory.instance.removeListener(_onRewindMemoryChanged);
    SubscriptionState.instance.removeListener(_onSubscriptionChanged);
    _deck.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final options = await ApiClient.fetchProfileOptions();
      if (mounted) setState(() => _options = options);
    } catch (_) {}
    try {
      final profile = await ApiClient.fetchMyProfile();
      if (mounted) setState(() => _myInterests = profile.interests.toSet());
    } catch (_) {}
    await _loadMore(restore: true);
  }

  Map<String, String> get _promptTextMap {
    if (_options == null) return {};
    return {for (final p in _options!.prompts) p.id: p.text};
  }

  Map<String, String> get _interestLabelMap {
    if (_options == null) return {};
    return {for (final i in _options!.interests) i.id: i.label};
  }

  DiscoveryFeed _buildFeed() {
    final mode = _seeingAgain ? 'all' : 'new';
    return DiscoveryFeed(
      key: 'explore:${widget.category.id}|$mode',
      filters: widget.category.id,
      mode: mode,
      fetch: (exclude) => ApiClient.fetchDiscovery(
        lean: true,
        limit: DiscoveryQueue.batchSize,
        exploreId: widget.category.id, // فیلترِ دسته سمتِ سرور (قبل از limit)
        exclude: exclude,
        includeSwiped: _seeingAgain, // mode=all فقط با «دوباره ببین»
      ),
    );
  }

  void _maybeLoadNext() {
    final feed = _feed;
    if (feed == null || _loadingMore) return;
    if (feed.needsFetch) _loadMore();
  }

  Future<void> _loadMore({bool restore = false}) async {
    if (_loadingMore) return;
    _loadingMore = true;
    final gen = _generation;
    if (mounted) setState(() => _error = null);

    try {
      final feed = _feed ??= _buildFeed();
      var resolved = restore ? await feed.restore() : const <DiscoveryCandidate>[];
      if (!mounted || gen != _generation) return;
      // یه درخواست در هر batch؛ هیچ loop یا درخواستِ اضافه‌ای نیست.
      _exhausted = feed.exhausted;
      final stackEmpty = _stack.isEmpty && resolved.isEmpty;
      if (feed.needsFetch || (stackEmpty && !_exhausted)) {
        resolved = await feed.fetchNext(
          exclude: {..._excluded, ...SwipeOutbox.instance.ids}.toList(),
        );
      }
      if (!mounted || gen != _generation) return;
      _exhausted = feed.exhausted;
      final existing = _stack.map((c) => c.publicId).toSet();
      setState(() {
        _stack = [
          ..._stack,
          ...resolved.where((c) => !existing.contains(c.publicId) && !_excluded.contains(c.publicId)),
        ];
      });
      _precacheTop();
    } on NetworkException {
      if (mounted && gen == _generation) {
        setState(() => _error = 'ارتباط با سرور برقرار نشد.');
      }
    } on ApiException {
      if (mounted && gen == _generation) {
        setState(() => _error = 'دریافت لیست با مشکل مواجه شد.');
      }
    } finally {
      if (gen == _generation) {
        _loadingMore = false;
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _reload() {
    _generation++;
    _loadingMore = false;
    _exhausted = false;
    _feed = null; // هر mode صفِ مستقلِ خودش رو داره
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = [];
      _error = null;
      _loading = true;
    });
    _loadMore(restore: true);
  }

  void _seeAgain() {
    HapticFeedback.lightImpact();
    _seeingAgain = true; // mode=all؛ صفِ مستقلِ خودش رو داره
    _excluded.clear();
    _reload();
  }

  void _precacheTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final c in _stack.take(3)) {
        if (c.photos.isEmpty) continue;
        precacheImage(
          appImageProvider('$backendBaseUrl${c.photos.first.url}'),
          context,
          onError: (e, s) {},
        );
        precacheImage(
          appImageProvider(photoThumbUrl('$backendBaseUrl${c.photos.first.url}')),
          context,
          onError: (e, s) {},
        );
      }
    });
  }

  String _dirName(SwipeDirection d) {
    switch (d) {
      case SwipeDirection.right:
        return 'like';
      case SwipeDirection.left:
        return 'pass';
      case SwipeDirection.up:
        return 'super_like';
    }
  }

  void _onSwiped(DiscoveryCandidate c, SwipeDirection dir) {
    final direction = _dirName(dir);
    _excluded.add(c.publicId);
    _feed?.markSeen(c.publicId);
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = _stack.where((x) => !identical(x, c)).toList();
    });
    // اکشنِ تکراری هیچ تغییری تو بک‌اند نمی‌ده، پس چیزی هم برای Rewind نیست.
    final pushed = swipeChangesState(c.previousDirection, direction);
    if (pushed) RewindMemory.instance.push(c, dir); // حافظه‌ی session، مشترک با تب سواپ
    _maybeLoadNext();
    _precacheTop();

    // اکشنِ بی‌اثر → درخواستی نمی‌فرستیم (سرور هم همین قوانین رو داره).
    if (!pushed) return;

    // رد: جوابِ فوری نمی‌خواد؛ تو صفِ ارسال می‌ره و همراهِ لایکِ بعدی (یا با تایمر) یکجا
    // فرستاده می‌شه. (Rewindِ یه ردِ هنوز-ارسال‌نشده هم هیچ درخواستی نمی‌خواد.)
    if (direction == 'pass') {
      SwipeOutbox.instance.add(c.publicId);
      return;
    }
    final pending = SwipeOutbox.instance.pendingForPiggyback();

    RewindMemory.instance
        .enqueue(() => ApiClient.swipe(c.publicId, direction, pendingPasses: pending))
        .then((result) {
      SwipeOutbox.instance.confirmSent(pending);
      if (!result.changed && pushed) {
        RewindMemory.instance.discardLatestFor(c.publicId);
      }
      if (direction == 'super_like' && result.changed) {
        SubscriptionState.instance.noteSuperLikeSpent();
      } else if (direction == 'like' && result.changed) {
        SubscriptionState.instance.noteLikeSpent();
      }
      if (result.matched) LikesStore.instance.remove(c.publicId);
      if (result.matched && result.match != null) {
        RewindMemory.instance.discardLatestFor(c.publicId);
        if (mounted) _showMatchDialog(result.match!);
      }
    }).catchError((Object e) {
      _handleSwipeError(e);
      RewindMemory.instance.discardLatestFor(c.publicId);
    });
  }

  /// همون Rewindِ تب سواپ: آخرین swipeِ قابل‌برگشت (تو کل session)، به‌ترتیبِ
  /// معکوسِ زمانی؛ اول بک‌اند وضعیتِ قبلی رو برمی‌گردونه، بعد کارت برمی‌گرده.
  Future<void> _rewind() async {
    final memory = RewindMemory.instance;
    final last = memory.latest;
    if (last == null || _deck.isFlying || _rewinding) return;
    // Rewind قابلیتِ اشتراکیه (سرور هم چک می‌کنه).
    if (SubscriptionState.instance.loaded && !SubscriptionState.instance.isPremium) {
      showPremiumPaywall(context, PaywallReason.rewind);
      return;
    }
    _rewinding = true;
    try {
      if (!SwipeOutbox.instance.removeIfQueued(last.candidate.publicId)) {
        await SwipeOutbox.instance.flush();
        await memory.enqueue(() => ApiClient.rewind(last.candidate.publicId));
      }
      memory.remove(last);
      if (!mounted) return;
      _excluded.remove(last.candidate.publicId);
      _feed?.unmarkSeen(last.candidate.publicId);
      _deck.prepareRewind(last.direction);
      setState(() {
        _expandedId = null;
        _lockedId = null;
        _stack = [
          last.candidate,
          ..._stack.where((x) => x.publicId != last.candidate.publicId),
        ];
      });
    } on ApiException catch (e) {
      if (e.code == 'rewind_unavailable' || e.code == 'rewind_not_latest') {
        memory.remove(last);
        _toast('این حرکت دیگه قابل برگشت نیست.');
      } else {
        _toast('برگردوندن انجام نشد.');
      }
    } catch (_) {
      _toast('ارتباط با سرور برقرار نشد.');
    } finally {
      _rewinding = false;
    }
  }

  void _removeBlocked(DiscoveryCandidate c) {
    _excluded.add(c.publicId);
    _feed?.markSeen(c.publicId);
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = _stack.where((x) => x.publicId != c.publicId).toList();
    });
    _maybeLoadNext();
    _precacheTop();
  }

  /// نگه داشتنِ دکمه‌ی روشنِ لایک/سوپرلایک روی کارتِ بالا.
  Future<void> _removeLikeOnTop() async {
    if (_stack.isEmpty) return;
    final r = await confirmAndRemoveLike(context, _stack.first);
    if (!mounted) return;
    if (r.removed) setState(() {});
    if (r.message != null) _toast(r.message!);
  }

  // ---------------------------------------------------------------------
  // قفلِ سوپرلایک (اشتراک + سهمیه‌ی روزانه)
  // ---------------------------------------------------------------------

  void _onSubscriptionChanged() {
    if (mounted) setState(() {});
  }

  /// کشیدنِ کارت به بالا / دکمه‌ی ⭐: اگه کاربر اشتراک نداره یا سهمیه‌ی امروزش
  /// تموم شده، کارت برمی‌گرده و پیام نشون داده می‌شه. (سرور هم دوباره چک می‌کنه.)
  bool _canSwipe(DiscoveryCandidate c, SwipeDirection dir) {
    if (dir == SwipeDirection.right) {
      // لایکِ بی‌اثر (قبلاً لایک/سوپرلایک شده) مصرفِ سهمیه ندارد.
      if (!swipeChangesState(c.previousDirection, 'like')) return true;
      return SubscriptionState.instance.canLike;
    }
    if (dir != SwipeDirection.up) return true;
    // سوپرلایکِ بی‌اثر (قبلاً سوپرلایک شده) مصرفِ سهمیه نداره.
    if (!swipeChangesState(c.previousDirection, 'super_like')) return true;
    return SubscriptionState.instance.canSuperLike;
  }

  void _onBlocked(DiscoveryCandidate c, SwipeDirection dir) {
    final s = SubscriptionState.instance;
    if (dir == SwipeDirection.right) {
      showPremiumPaywall(context, PaywallReason.likeLimit);
    } else if (!s.isPremium) {
      showPremiumPaywall(context, PaywallReason.superLike);
    } else {
      _toast('سوپرلایک‌های امروزت تموم شد. فردا دوباره ${s.superLikesDaily} تا داری.');
    }
  }

  /// خطاهای قفلِ سوپرلایک که سرور برمی‌گردونه (وقتی وضعیتِ اپ قدیمی بوده).
  void _handleSwipeError(Object e) {
    if (e is! ApiException || !mounted) return;
    if (e.code == 'premium_required') {
      SubscriptionState.instance.refresh();
      showPremiumPaywall(context, PaywallReason.superLike);
    } else if (e.code == 'super_like_limit') {
      SubscriptionState.instance.refresh();
      _toast('سوپرلایک‌های امروزت تموم شد.');
    } else if (e.code == 'like_limit') {
      SubscriptionState.instance.refresh();
      showPremiumPaywall(context, PaywallReason.likeLimit);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _showMatchDialog(MatchSummary match) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: kSwipeTextDirection,
        child: Dialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                const Text('متچ شدین!',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                if (match.photoUrl.isNotEmpty)
                  ClipOval(
                    child: AppNetworkImage('$backendBaseUrl${match.photoUrl}',
                        thumb: true,
                        placeholderColor: const Color(0xFF2C2C2E),
                        width: 100,
                        height: 100),
                  ),
                const SizedBox(height: 12),
                Text('تو و ${match.name} همدیگه رو لایک کردین!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFD0D0D2), fontSize: 15)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwipeColors.like,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('ادامه‌ی کشف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchesScreen()));
                  },
                  child: const Text('دیدن متچ‌ها', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    // ریشه‌ی «چپ‌چین‌بودنِ اسمِ کارت» تو اکسپلور: این صفحه با Navigator.push
    // باز می‌شه و خارج از Directionalityِ rtl ی HomeScreen قرار می‌گیره؛ پس
    // ویجت‌های start-aligned ی کارت (اسم، سن، بج‌ها، بلوک‌های اطلاعات) LTR
    // می‌شدن. با همون kSwipeTextDirection ی تب سواپ، دقیقاً همون چیدمان.
    return Directionality(
      textDirection: kSwipeTextDirection,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: topPad + SwipeMetrics.headerHeight,
              child: _buildDeckArea(),
            ),
            Positioned(top: topPad, left: 0, right: 0, child: _buildHeader()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final cat = widget.category;
    return SizedBox(
      height: SwipeMetrics.headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: cat.gradient),
              ),
              alignment: Alignment.center,
              child: Icon(cat.icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckArea() {
    if (_loading && _stack.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null && _stack.isEmpty) {
      return _centerMessage(
        icon: Icons.cloud_off,
        title: _error!,
        actions: [_pillButton('تلاش دوباره', _reload)],
      );
    }
    if (_stack.isEmpty) {
      if (_seeingAgain) {
        return _centerMessage(
          icon: widget.category.icon,
          title: 'کسی تو این دسته پیدا نشد.',
          subtitle: 'بعداً دوباره سر بزن، یا شعاعِ فاصله‌ت رو تو تنظیماتِ سواپ زیاد کن.',
          actions: [_pillButton('تلاش دوباره', _reload)],
        );
      }
      return _centerMessage(
        icon: widget.category.icon,
        title: 'همه‌ی پروفایل‌های این دسته رو دیدی.',
        subtitle: 'می‌تونی دوباره ببینیشون؛ اینکار چیزی رو تغییر نمی‌ده مگه خودت لایک/رد کنی.',
        actions: [
          _pillButton('دوباره ببین', _seeAgain),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _reload,
            child: const Text('تلاش دوباره', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        SwipeDeck<DiscoveryCandidate>(
          items: _stack,
          controller: _deck,
          superLikeEnabled: true,
          swipeEnabled: _stack.first.publicId != _lockedId,
          canSwipe: _canSwipe,
          onBlocked: _onBlocked,
          onSwiped: _onSwiped,
          itemBuilder: (context, c) => SwipeProfileCard(
            key: ValueKey(c.publicId),
            candidate: c,
            interestLabels: _interestLabelMap,
            promptTextMap: _promptTextMap,
            myInterests: _myInterests,
            onExpandedChanged: (open) {
              if (!mounted) return;
              setState(() => _expandedId = open ? c.publicId : (_expandedId == c.publicId ? null : _expandedId));
            },
            onSend: () => _toast('این قابلیت به‌زودی اضافه می‌شه.'),
            onBlocked: () => _removeBlocked(c),
            onSwipeLockChanged: (locked) {
              if (!mounted) return;
              setState(() => _lockedId = locked ? c.publicId : (_lockedId == c.publicId ? null : _lockedId));
            },
          ),
        ),
        if (_seeingAgain)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1C1C1E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay, size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text('دوباره داری این پروفایل‌ها رو می‌بینی',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: SwipeMetrics.buttonsBottom,
          child: SwipeActionBar(
            progress: _deck.progress,
            extended: true,
            canRewind: RewindMemory.instance.canRewind && !_rewinding,
            likeLit: _stack.isNotEmpty && _stack.first.previousDirection == 'like',
            superLikeLit:
                _stack.isNotEmpty && _stack.first.previousDirection == 'super_like',
            onRemoveLike: _removeLikeOnTop,
            litToken: _stack.isNotEmpty ? _stack.first.publicId : null,
            superLikeLocked: SubscriptionState.instance.loaded && !SubscriptionState.instance.isPremium,
            hideActions: _expandedId != null,
            hideSend: _lockedId != null,
            onPass: () => _deck.swipe(SwipeDirection.left),
            onLike: () => _deck.swipe(SwipeDirection.right),
            onSuperLike: () => _deck.swipe(SwipeDirection.up),
            onRewind: _rewind,
            onSend: () => _toast('این قابلیت به‌زودی اضافه می‌شه.'),
          ),
        ),
      ],
    );
  }

  Widget _centerMessage({
    IconData? icon,
    required String title,
    String? subtitle,
    List<Widget> actions = const [],
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 48, color: const Color(0xFF8E8E93)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 15, height: 1.5)),
            ],
            const SizedBox(height: 20),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: SwipeColors.like,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }
}
