import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/match_models.dart';
import '../models/profile_models.dart';
import '../swipe/location_gate.dart';
import '../swipe/remove_like_flow.dart';
import '../swipe/rewind_memory.dart';
import '../swipe/swipe_action_bar.dart';
import '../swipe/swipe_card.dart';
import '../swipe/swipe_deck.dart';
import '../swipe/swipe_header.dart';
import '../swipe/swipe_onboarding_store.dart';
import '../swipe/swipe_style.dart';
import '../widgets/profile_detail_sheet.dart';
import 'location_picker_screen.dart';
import 'matches_screen.dart';
import '../widgets/app_network_image.dart';
import '../subscription/subscription_state.dart';
import '../subscription/premium_paywall.dart';
import '../swipe/swipe_outbox.dart';
import '../likes/likes_store.dart';
import '../cache/discovery_feed.dart';
import '../cache/discovery_queue.dart';

/// تب «Swipe» — صفحه‌ی اصلی اپ (سبک تیندر).
///
/// دو حالت داره:
/// - حالت ۱: کاربر تازه از اونبوردینگ اومده و هنوز ۲۰ نفر رو لایک/رد نکرده →
///   بنر «داریم سلیقه‌ات رو یاد می‌گیریم» بالا، فقط دکمه‌ی ضربدر و قلب،
///   و کشیدن به بالا (سوپرلایک) غیرفعاله.
/// - حالت ۲: بعد از اون → نوار «برای تو / نزدیک» بالا، ۵ دکمه‌ی پایین، و
///   کشیدن کارت به بالا = سوپرلایک.
class SwipeScreen extends StatefulWidget {
  /// وقتی تو دیالوگ متچ «دیدن متچ‌ها» زده شد صدا زده می‌شه (شل، تب چت رو
  /// باز می‌کنه). اگه null باشه صفحه‌ی متچ‌ها push می‌شه.
  final VoidCallback? onOpenMatches;

  /// هر بار که کاربر دوباره وارد تب سواپ می‌شه تغییر می‌کنه (برای چکِ لوکیشن).
  final Listenable? enterSignal;

  const SwipeScreen({super.key, this.onOpenMatches, this.enterSignal});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> with WidgetsBindingObserver {
  /// شعاع تب «نزدیک» (کیلومتر).
  static const double _nearbyKm = 30;

  final SwipeDeckController _deck = SwipeDeckController();

  List<DiscoveryCandidate> _stack = [];
  final Set<String> _excluded = {};

  /// صفِ پایدارِ روی دیسک (هر ترکیبِ فیلتر/mode یه صف) + CardCache. batch = ۲۵ کارت؛ تا
  /// وقتی seen < ۷۰٪ و عمرِ batch < ۲۴ ساعت، Discoveryِ جدید نمی‌گیریم.
  DiscoveryFeed? _feed;
  bool _rewinding = false;

  ProfileOptions? _options;
  Set<String> _myInterests = {};

  bool _loading = true;
  bool _loadingMore = false;
  int _generation = 0; // برای دور ریختن جواب‌های قدیمی بعد از عوض شدن فیلتر
  String? _error;

  bool _browsingAgain = false;
  int _minAge = 18;
  int _maxAge = 100;
  double? _maxDistanceKm; // null = بدون محدودیت
  String? _interestedIn;

  int _tab = 0; // 0 = برای تو، 1 = نزدیک

  /// publicId کارتی که اطلاعاتش باز شده؛ تا وقتی باز مونده دکمه‌های لایک/رد/
  /// سوپرلایک/واگرد هاید می‌شن.
  String? _expandedId;

  /// publicId کارتی که کشیدنش قفله (از باز شدنِ اطلاعات تا تموم شدنِ برگشت)، تا
  /// کشیدنِ کارت با اسکرولِ اطلاعات تداخل نکنه.
  String? _lockedId;

  int _remaining = SwipeOnboarding.remaining;
  bool get _onboarding => _remaining > 0;

  @override
  void initState() {
    super.initState();
    RewindMemory.instance.addListener(_onRewindMemoryChanged);
    SubscriptionState.instance.addListener(_onSubscriptionChanged);
    WidgetsBinding.instance.addObserver(this);
    widget.enterSignal?.addListener(_onEnterSwipeTab);
    _init();
  }

  void _onRewindMemoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RewindMemory.instance.removeListener(_onRewindMemoryChanged);
    SubscriptionState.instance.removeListener(_onSubscriptionChanged);
    widget.enterSignal?.removeListener(_onEnterSwipeTab);
    WidgetsBinding.instance.removeObserver(this);
    _deck.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // داده
  // ---------------------------------------------------------------------

  Future<void> _init() async {
    // گزینه‌ها و پروفایل به لیستِ افراد ربطی ندارن: موازی و بدونِ منتظر موندن.
    _loadOptionsAndProfile();

    // لوکیشن فقط وقتی وقت می‌گیره که واقعاً لازم باشه (≥۴۸ ساعت از آخرین
    // ارسال گذشته)؛ چون لیستِ افراد به لوکیشن نیاز داره، قبلش تمومش می‌کنیم.
    await _ensureLocation(firstEntry: true, waitAtMost: const Duration(seconds: 30));
    await _loadMore(restore: true); // صفِ ذخیره‌شده روی دیسک (بعد از restartِ اپ) ادامه پیدا می‌کنه
  }

  void _loadOptionsAndProfile() {
    ApiClient.fetchProfileOptions().then((options) {
      if (mounted) setState(() => _options = options);
    }).catchError((_) {});
    ApiClient.fetchMyProfile().then((profile) {
      if (!mounted) return;
      setState(() {
        _interestedIn = profile.interestedIn;
        _myInterests = profile.interests.toSet();
      });
    }).catchError((_) {});
  }

  // ---------------------------------------------------------------------
  // لوکیشن
  // ---------------------------------------------------------------------

  LocationIssue _locationIssue = LocationIssue.none;
  bool _locationBannerDismissed = false;
  bool _locationBusy = false;

  /// چکِ لوکیشن. [firstEntry] فقط برای اولین ورود بعد از باز شدنِ اپ: فقط همون‌جا
  /// ممکنه دیالوگِ مجوز بیاد و پیامِ «مجوز لازمه» نشون داده بشه. بقیه‌ی چک‌ها
  /// (رفت‌وآمد بین تب‌ها) بی‌صدان: اگه مجوز باشه و لوکیشن منقضی شده باشه، لوکیشنِ
  /// جدید بی‌سروصدا فرستاده می‌شه، ولی هیچ پیامی نمایش داده نمی‌شه.
  /// [waitAtMost]: بیشتر از این منتظرِ جوابش نمی‌مونیم.
  Future<void> _ensureLocation({
    bool firstEntry = false,
    bool userInitiated = false,
    Duration? waitAtMost,
  }) async {
    if (_locationBusy) return;
    _locationBusy = true;
    final task = LocationGate.ensure(
      allowPrompt: firstEntry,
      userInitiated: userInitiated,
    ).then((r) {
      _locationBusy = false;
      if (!mounted) return r;
      final hadIssue = _locationIssue != LocationIssue.none;
      setState(() {
        if (r.issue == LocationIssue.none) {
          _locationIssue = LocationIssue.none; // مشکل حل شده
        } else if (firstEntry || userInitiated) {
          _locationIssue = r.issue;
          _locationBannerDismissed = false;
        }
        // چکِ بی‌صدا: پیامی که هست/نیست همون‌طور می‌مونه.
      });
      // مشکل حل شد (مثلاً مجوز رو دادی): لیست رو با لوکیشنِ جدید بگیر.
      if (hadIssue && r.issue == LocationIssue.none) _reload();
      return r;
    });
    if (waitAtMost != null) {
      await task.timeout(waitAtMost, onTimeout: () => const LocationResult(LocationIssue.none));
    } else {
      await task;
    }
  }

  void _onEnterSwipeTab() {
    // هر بار که از تب دیگه برمی‌گردی به سواپ: پیامِ مجوز (اگه هنوز رو صفحه‌ست)
    // بسته می‌شه تا اسپم نشه، و فقط بی‌صدا چک می‌شه که لوکیشن منقضی نشده باشه.
    if (_locationIssue != LocationIssue.none && !_locationBannerDismissed) {
      setState(() => _locationBannerDismissed = true);
    }
    _ensureLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // از تنظیماتِ گوشی برگشتی: اگه مجوز/GPS رو درست کرده باشی، همین‌جا حل می‌شه.
    if (state == AppLifecycleState.resumed && _locationIssue != LocationIssue.none) {
      _ensureLocation();
    }
  }

  Future<void> _onLocationAction() async {
    switch (_locationIssue) {
      case LocationIssue.deniedForever:
      case LocationIssue.serviceOff:
        await LocationGate.openSettings(_locationIssue);
        break;
      default:
        await _ensureLocation(userInitiated: true);
    }
  }

  String get _locationMessage => _locationIssue == LocationIssue.serviceOff
      ? 'برای دیدن افراد نزدیک به خودت، GPS گوشیت رو روشن کن.'
      : 'برای دیدن افراد نزدیک به خودت، مجوز لوکیشن لازمه.';

  Widget _buildLocationBanner() {
    final needsSettings = _locationIssue == LocationIssue.deniedForever ||
        _locationIssue == LocationIssue.serviceOff;
    return Material(
      color: const Color(0xEE2C2C2E),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationMessage,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
              ),
            ),
            TextButton(
              onPressed: _onLocationAction,
              child: Text(
                needsSettings ? 'تنظیمات' : 'فعال‌سازی',
                style: const TextStyle(color: SwipeColors.like, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
              onPressed: () => setState(() => _locationBannerDismissed = true),
            ),
          ],
        ),
      ),
    );
  }

  double? get _effectiveDistance {
    if (_tab == 1) {
      final d = _maxDistanceKm;
      if (d == null) return _nearbyKm;
      return d < _nearbyKm ? d : _nearbyKm;
    }
    return _maxDistanceKm;
  }

  DiscoveryFeed _buildFeed() {
    final mode = _browsingAgain ? 'all' : 'new';
    final filters = 'a$_minAge-$_maxAge|d${_effectiveDistance ?? 'x'}';
    return DiscoveryFeed(
      key: 'swipe|$filters|$mode',
      filters: filters,
      mode: mode,
      fetch: (exclude) => ApiClient.fetchDiscovery(
        minAge: _minAge,
        maxAge: _maxAge,
        maxDistanceKm: _effectiveDistance,
        limit: DiscoveryQueue.batchSize,
        exclude: exclude,
        includeSwiped: _browsingAgain,
        lean: true, // فقط شناسه، نام، سن، درباره، علایق، عکس؛ بقیه با زدنِ فلشِ کارت
      ),
    );
  }

  /// بعد از هر swipe: فقط وقتی seen >= ۷۰٪ (یا عمرِ batch >= ۲۴ ساعت) شد batchِ بعدی.
  /// طولِ استک معیارِ fetch نیست.
  void _maybeLoadNext() {
    final feed = _feed;
    if (feed == null || _loadingMore) return;
    if (feed.needsFetch) _loadMore();
  }

  Future<void> _loadMore({bool restore = false}) async {
    if (_loadingMore) return;
    _loadingMore = true;
    final gen = _generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final feed = _feed ??= _buildFeed();
      var resolved = restore ? await feed.restore() : const <DiscoveryCandidate>[];
      if (!mounted || gen != _generation) return;
      // صفِ ذخیره‌شده کافیه (seen < ۷۰٪، < ۲۴h، کارت‌ها تو کش) → هیچ درخواستی نمی‌زنیم.
      final stackEmpty = _stack.isEmpty && resolved.isEmpty;
      if (feed.needsFetch || (stackEmpty && !feed.exhausted)) {
        resolved = await feed.fetchNext(
          // ردهایی که هنوز به سرور نرسیدن (تو صفِ ارسال) هم باید دوباره نشون داده نشن.
          exclude: {..._excluded, ...SwipeOutbox.instance.ids}.toList(),
        );
      }
      if (!mounted || gen != _generation) return;
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
    } on ApiException catch (e) {
      if (mounted && gen == _generation) {
        setState(() => _error = e.code == 'profile_required'
            ? 'اول باید پروفایلت رو تکمیل کنی.'
            : 'دریافت لیست با مشکل مواجه شد.');
      }
    } finally {
      if (gen == _generation) {
        _loadingMore = false;
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  /// لیست رو خالی می‌کنه و از اول می‌گیره (بعد از عوض شدن فیلتر/تب/موقعیت).
  void _reload() {
    _generation++;
    _loadingMore = false;
    _feed = null; // کلیدِ صف از فیلتر/mode ساخته می‌شه؛ هر ترکیب صفِ خودش رو داره
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = [];
      _error = null;
    });
    _loadMore(restore: true);
  }

  void _seeEveryoneAgain() {
    HapticFeedback.lightImpact();
    _browsingAgain = true;
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

  Map<String, String> get _promptTextMap {
    if (_options == null) return {};
    return {for (final p in _options!.prompts) p.id: p.text};
  }

  Map<String, String> get _interestLabelMap {
    if (_options == null) return {};
    return {for (final i in _options!.interests) i.id: i.label};
  }

  // ---------------------------------------------------------------------
  // swipe
  // ---------------------------------------------------------------------

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
    // حافظه‌ی Rewind (فقط session، مشترک با اکسپلور).
    // اکشنِ تکراری (مثلاً لایک روی کسی که قبلاً لایک شده) هیچ تغییری تو بک‌اند
    // نمی‌ده، پس چیزی هم برای Rewind نیست.
    final pushed = swipeChangesState(c.previousDirection, direction);
    if (pushed) RewindMemory.instance.push(c, dir);
    _maybeLoadNext();
    _precacheTop();
    _countOnboarding(direction);

    // اکشنِ بی‌اثر (مثلاً رد روی لایک‌شده): درخواستی نمی‌فرستیم. سرور هم
    // همین قوانین رو داره، پس اگه اطلاعاتِ کارت قدیمی باشه بازم امنه.
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
        // swipeِ منجر به متچ دیگه قابل‌برگشت نیست.
        RewindMemory.instance.discardLatestFor(c.publicId);
        if (mounted) _showMatchDialog(result.match!);
      }
    }).catchError((Object e) {
      _handleSwipeError(e);
      // ثبت swipe شکست خورد (شبکه/رد شدن تو بک‌اند)؛ چیزی تو تاریخچه‌ی بک‌اند
      // نیست، پس رکوردِ Rewindش رو هم برمی‌داریم.
      RewindMemory.instance.discardLatestFor(c.publicId);
    });
  }

  void _countOnboarding(String direction) {
    if (!SwipeOnboarding.isActive) return;
    final finished = SwipeOnboarding.register(direction);
    setState(() => _remaining = SwipeOnboarding.remaining);
    if (finished) HapticFeedback.mediumImpact();
  }

  /// Rewind = برگردوندنِ *آخرین* swipeِ قابل‌برگشت (فقط به‌ترتیبِ معکوسِ
  /// زمانی؛ هیچ لیستی برای انتخابِ دلخواه نیست). اول بک‌اند وضعیتِ قبلی رو
  /// برمی‌گردونه (لایک/رد/سوپرلایک → وضعیتِ قبلش یا هیچ)، بعد کارت به
  /// Deck برمی‌گرده تا کاربر بتونه اکشنِ دیگه‌ای بزنه.
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
      // ردِ هنوز-ارسال‌نشده: فقط از صف برداشته می‌شه (بدونِ درخواست). وگرنه اول صف خالی
      // می‌شه (تا ترتیبِ تاریخچه تو سرور درست باشه) و بعد Rewind می‌ره.
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

  /// بعد از مسدودسازیِ موفق از تو کارت: کارت بدونِ ثبتِ سواپ از Deck برداشته می‌شه.
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
      ..showSnackBar(SnackBar(
        content: Directionality(
          textDirection: kSwipeTextDirection,
          child: Text(message),
        ),
        duration: const Duration(seconds: 2),
      ));
  }

  // ---------------------------------------------------------------------
  // دیالوگ‌ها و شیت‌ها
  // ---------------------------------------------------------------------

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
                const Text(
                  'متچ شدین!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (match.photoUrl.isNotEmpty)
                  ClipOval(
                    child: AppNetworkImage(
                      '$backendBaseUrl${match.photoUrl}',
                      thumb: true,
                      width: 100,
                      height: 100,
                      placeholderColor: const Color(0xFF2C2C2E),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'تو و ${match.name} همدیگه رو لایک کردین!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD0D0D2), fontSize: 15),
                ),
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
                    child: const Text('ادامه‌ی کشف',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (widget.onOpenMatches != null) {
                      widget.onOpenMatches!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MatchesScreen()),
                      );
                    }
                  },
                  child: const Text('دیدن متچ‌ها',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(DiscoveryCandidate candidate) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Directionality(
          textDirection: kSwipeTextDirection,
          child: ProfileDetailSheet(
            candidate: candidate,
            promptTextMap: _promptTextMap,
            interestLabelMap: _interestLabelMap,
            scrollController: scrollController,
            onSwipe: (direction) => _swipeFromDetail(candidate, direction),
            onRemoveLike: () => _removeLikeFromDetail(candidate),
          ),
        ),
      ),
    );
  }

  /// نگه داشتنِ دکمه‌ی روشنِ لایک/سوپرلایک روی کارتِ بالا.
  Future<void> _removeLikeOnTop() async {
    if (_stack.isEmpty) return;
    final r = await confirmAndRemoveLike(context, _stack.first);
    if (!mounted) return;
    if (r.removed) setState(() {});
    if (r.message != null) _toast(r.message!);
  }

  /// همون کار، از تو شیتِ جزئیات (شیت اول بسته می‌شه).
  Future<void> _removeLikeFromDetail(DiscoveryCandidate candidate) async {
    Navigator.pop(context);
    final r = await confirmAndRemoveLike(context, candidate);
    if (!mounted) return;
    if (r.removed) {
      // اگه همون فرد تو Deck هم هست، دکمه‌هاش هم خاموش بشه.
      for (final x in _stack) {
        if (x.publicId == candidate.publicId) x.previousDirection = null;
      }
      setState(() {});
    }
    if (r.message != null) _toast(r.message!);
  }

  // لایک/رد/سوپرلایک از تو شیت جزئیات. اگه کارتِ بالای صفحه باشه با همون
  // انیمیشن پرتش می‌کنیم؛ اگه از جستجو اومده باشه مستقیم ثبت می‌شه.
  Future<void> _swipeFromDetail(DiscoveryCandidate candidate, String direction) async {
    Navigator.pop(context); // شیت رو ببند

    if (_stack.isNotEmpty && _stack.first.publicId == candidate.publicId) {
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      _deck.swipe(direction == 'like'
          ? SwipeDirection.right
          : direction == 'pass'
              ? SwipeDirection.left
              : SwipeDirection.up);
      return;
    }

    _excluded.add(candidate.publicId);
    _feed?.markSeen(candidate.publicId);
    setState(() {
      _stack = _stack.where((c) => c.publicId != candidate.publicId).toList();
    });
    final pushed = swipeChangesState(candidate.previousDirection, direction);
    if (pushed) {
      RewindMemory.instance.push(
          candidate,
          direction == 'like'
              ? SwipeDirection.right
              : direction == 'pass'
                  ? SwipeDirection.left
                  : SwipeDirection.up);
    }
    if (!pushed) return; // اکشنِ بی‌اثر → درخواستی لازم نیست.
    if (direction == 'pass') {
      SwipeOutbox.instance.add(candidate.publicId);
      return;
    }
    final pending = SwipeOutbox.instance.pendingForPiggyback();
    try {
      final result = await RewindMemory.instance.enqueue(
          () => ApiClient.swipe(candidate.publicId, direction, pendingPasses: pending));
      SwipeOutbox.instance.confirmSent(pending);
      if (!result.changed && pushed) {
        RewindMemory.instance.discardLatestFor(candidate.publicId);
      }
      if (direction == 'super_like' && result.changed) {
        SubscriptionState.instance.noteSuperLikeSpent();
      } else if (direction == 'like' && result.changed) {
        SubscriptionState.instance.noteLikeSpent();
      }
      if (result.matched) LikesStore.instance.remove(candidate.publicId);
      if (result.matched && result.match != null) {
        RewindMemory.instance.discardLatestFor(candidate.publicId);
        if (mounted) _showMatchDialog(result.match!);
      }
    } catch (e) {
      if (pushed) RewindMemory.instance.discardLatestFor(candidate.publicId);
      _handleSwipeError(e);
    }
  }

  void _openSearch() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: kSwipeTextDirection,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('جستجو با آیدی', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'آیدی فرد رو وارد کن',
              hintStyle: TextStyle(color: Color(0xFF8E8E93)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف', style: TextStyle(color: Color(0xFFBDBDBD))),
            ),
            TextButton(
              onPressed: () {
                final id = controller.text.trim();
                Navigator.pop(dialogContext);
                if (id.isNotEmpty) _searchAndShow(id);
              },
              child: const Text('جستجو', style: TextStyle(color: SwipeColors.like)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchAndShow(String publicId) async {
    try {
      final candidate = await ApiClient.fetchDiscoveryProfile(publicId);
      if (mounted) _openDetail(candidate);
    } on NetworkException {
      _toast('ارتباط با سرور برقرار نشد.');
    } catch (_) {
      _toast('پروفایلی با این آیدی پیدا نشد.');
    }
  }

  void _openFilters() {
    int tempMin = _minAge;
    int tempMax = _maxAge;
    double? tempDistance = _maxDistanceKm;
    String? tempInterestedIn = _interestedIn;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: kSwipeTextDirection,
          child: Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: SwipeColors.like),
            ),
            child: StatefulBuilder(builder: (context, setSheetState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('فیلترها',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('دنبال چه کسی می‌گردم:',
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: (_options?.interestedIn ?? [])
                          .map((o) => ChoiceChip(
                                label: Text(o.label),
                                selected: tempInterestedIn == o.id,
                                onSelected: (_) =>
                                    setSheetState(() => tempInterestedIn = o.id),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    Text('بازه‌ی سن: $tempMin تا $tempMax',
                        style: const TextStyle(color: Colors.white)),
                    RangeSlider(
                      min: 18,
                      max: 100,
                      divisions: 82,
                      values: RangeValues(tempMin.toDouble(), tempMax.toDouble()),
                      onChanged: (values) => setSheetState(() {
                        tempMin = values.start.round();
                        tempMax = values.end.round();
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tempDistance == null
                          ? 'حداکثر فاصله: بدون محدودیت'
                          : 'حداکثر فاصله: ${tempDistance!.round()} کیلومتر',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Slider(
                      min: 1,
                      max: 200,
                      divisions: 199,
                      value: tempDistance ?? 200,
                      onChanged: (v) =>
                          setSheetState(() => tempDistance = v >= 200 ? null : v),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.map_outlined, color: Colors.white),
                      title: const Text('انتخاب موقعیت روی نقشه',
                          style: TextStyle(color: Colors.white)),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
                        );
                        if (changed == true && mounted) _reload();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.search, color: Colors.white),
                      title: const Text('جستجو با آیدی',
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openSearch();
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SwipeColors.like,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          Navigator.pop(sheetContext);

                          if (tempInterestedIn != null &&
                              tempInterestedIn != _interestedIn) {
                            try {
                              await ApiClient.updateInterestedIn(tempInterestedIn!);
                            } catch (_) {
                              // اگه ذخیره نشد، فقط همین session اعمال می‌شه.
                            }
                          }
                          if (!mounted) return;
                          _minAge = tempMin;
                          _maxAge = tempMax;
                          _maxDistanceKm = tempDistance;
                          _interestedIn = tempInterestedIn;
                          _reload();
                        },
                        child: const Text('اعمال فیلتر',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    // هدر روی کارت کشیده می‌شه (کارت موقع کشیدن می‌تونه زیرش بره — مثل تیندر).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: topPad + SwipeMetrics.headerHeight,
          child: _buildDeckArea(),
        ),
        Positioned(
          top: topPad,
          left: 0,
          right: 0,
          child: _buildHeader(),
        ),
        if (_locationIssue != LocationIssue.none && !_locationBannerDismissed)
          Positioned(
            top: topPad + SwipeMetrics.headerHeight + 4,
            left: 12,
            right: 12,
            child: _buildLocationBanner(),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: SwipeMetrics.headerHeight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _onboarding
            ? Align(
                key: const ValueKey('swipe_banner'),
                alignment: Alignment.topCenter,
                child: SwipeLearningBanner(remaining: _remaining),
              )
            : Align(
                key: const ValueKey('swipe_topbar'),
                alignment: Alignment.center,
                child: SwipeTopBar(
                  selectedTab: _tab,
                  onTabChanged: (i) {
                    setState(() => _tab = i);
                    _reload();
                  },
                  onFilters: _openFilters,
                  onBoost: () => _toast('Boost به‌زودی اضافه می‌شه.'),
                ),
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
    if (_stack.isEmpty) return _buildEmptyState();

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        SwipeDeck<DiscoveryCandidate>(
          items: _stack,
          controller: _deck,
          superLikeEnabled: !_onboarding,
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
            showSend: !_onboarding,
            onSend: () => _toast('این قابلیت به‌زودی اضافه می‌شه.'),
            onBlocked: () => _removeBlocked(c),
            onSwipeLockChanged: (locked) {
              if (!mounted) return;
              setState(() => _lockedId = locked ? c.publicId : (_lockedId == c.publicId ? null : _lockedId));
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: SwipeMetrics.buttonsBottom,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: SwipeActionBar(
              key: ValueKey<bool>(_onboarding),
              progress: _deck.progress,
              extended: !_onboarding,
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
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_browsingAgain) {
      return _centerMessage(
        icon: Icons.explore_off,
        title: 'کسی با این فیلترها پیدا نشد.',
        actions: [_pillButton('تنظیم فیلترها', _openFilters)],
      );
    }
    return _centerMessage(
      emoji: '🎉',
      title: 'همه رو دیدی!',
      subtitle: 'همه‌ی افراد اطرافت رو دیدی.',
      actions: [
        _pillButton('دوباره ببین', _seeEveryoneAgain),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _openFilters,
          child: const Text('تنظیم فیلترها', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _centerMessage({
    IconData? icon,
    String? emoji,
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
            if (emoji != null) Text(emoji, style: const TextStyle(fontSize: 48)),
            if (icon != null) Icon(icon, size: 48, color: const Color(0xFF8E8E93)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 15),
              ),
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
