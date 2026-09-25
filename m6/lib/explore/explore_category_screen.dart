import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/match_models.dart';
import '../models/profile_models.dart';
import '../screens/matches_screen.dart';
import '../swipe/swipe_action_bar.dart';
import '../swipe/swipe_card.dart';
import '../swipe/swipe_deck.dart';
import '../swipe/swipe_style.dart';
import 'explore_data.dart';

/// استکِ سواپِ مخصوصِ یه دسته‌ی اکسپلور — دقیقاً همون رفتارِ تیندر: با تپِ یه
/// تایل تو Explore، یه صفحه‌ی تمام‌صفحه باز می‌شه که فقط کاندیدهایی که تویِ
/// همون دسته جا می‌شن رو نشون می‌ده و مثلِ تبِ سواپِ اصلی می‌شه لایک/رد/
/// سوپرلایک کرد.
///
/// چون بک‌اند فیلترِ دسته‌ای نداره، از همون /api/discovery معمولی صفحه‌صفحه
/// می‌گیریم و کلاینت با [ExploreCategory.matches] فیلتر می‌کنه؛ اگه صفحه‌ای
/// هیچ‌کدوم‌شون جا نشن، خودکار صفحه‌ی بعدی رو هم می‌گیره (تا سقفِ یه تعداد
/// دورِ مشخص، که درخواستِ بی‌نهایت نزنه).
class ExploreCategoryScreen extends StatefulWidget {
  final ExploreCategory category;
  const ExploreCategoryScreen({super.key, required this.category});

  @override
  State<ExploreCategoryScreen> createState() => _ExploreCategoryScreenState();
}

class _SwipeRecord {
  final DiscoveryCandidate candidate;
  final SwipeDirection direction;
  _SwipeRecord(this.candidate, this.direction);
}

class _ExploreCategoryScreenState extends State<ExploreCategoryScreen> {
  static const int _pageLimit = 30;
  static const int _maxRoundsPerLoad = 6;

  final SwipeDeckController _deck = SwipeDeckController();

  List<DiscoveryCandidate> _stack = [];
  final Set<String> _fetched = {}; // همه‌ی publicId هایی که تا الان از سرور اومدن
  final List<_SwipeRecord> _history = [];

  ProfileOptions? _options;
  Set<String> _myInterests = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false; // سرور دیگه چیزِ جدیدی نداره
  int _generation = 0;
  String? _error;

  String? _expandedId;
  String? _lockedId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
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
    await _loadMore();
  }

  Map<String, String> get _promptTextMap {
    if (_options == null) return {};
    return {for (final p in _options!.prompts) p.id: p.text};
  }

  Map<String, String> get _interestLabelMap {
    if (_options == null) return {};
    return {for (final i in _options!.interests) i.id: i.label};
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _exhausted) return;
    _loadingMore = true;
    final gen = _generation;
    if (mounted) setState(() => _error = null);

    try {
      var rounds = 0;
      final gathered = <DiscoveryCandidate>[];
      // چون فیلترِ دسته سمتِ کلاینته، ممکنه یه صفحه‌ی کامل هیچ عضوی از این
      // دسته نداشته باشه؛ پس تا وقتی یا چندتا پیدا بشه، یا سرور خالی برگردونه،
      // یا به سقفِ دور برسیم، ادامه می‌دیم.
      while (rounds < _maxRoundsPerLoad && gathered.length < 6) {
        final page = await ApiClient.fetchDiscovery(
          limit: _pageLimit,
          exclude: _fetched.toList(),
        );
        if (gen != _generation) return;
        rounds++;
        if (page.isEmpty) {
          _exhausted = true;
          break;
        }
        _fetched.addAll(page.map((c) => c.publicId));
        gathered.addAll(page.where(widget.category.matches));
      }
      if (!mounted || gen != _generation) return;
      final existing = _stack.map((c) => c.publicId).toSet();
      setState(() {
        _stack = [
          ..._stack,
          ...gathered.where((c) => !existing.contains(c.publicId)),
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
    _fetched.clear();
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = [];
      _error = null;
      _loading = true;
    });
    _loadMore();
  }

  void _precacheTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final c in _stack.take(3)) {
        if (c.photos.isEmpty) continue;
        precacheImage(
          NetworkImage('$backendBaseUrl${c.photos.first.url}'),
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
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = _stack.where((x) => !identical(x, c)).toList();
      _history.add(_SwipeRecord(c, dir));
      if (_history.length > 10) _history.removeAt(0);
    });
    if (_stack.length < 5) _loadMore();
    _precacheTop();

    ApiClient.swipe(c.publicId, _dirName(dir)).then((result) {
      if (result.matched && result.match != null && mounted) {
        _showMatchDialog(result.match!);
      }
    }).catchError((_) {});
  }

  bool _canSwipe(DiscoveryCandidate c, SwipeDirection dir) {
    if (dir == SwipeDirection.up && c.previousDirection == 'super_like') {
      return false;
    }
    return true;
  }

  void _onBlocked(DiscoveryCandidate c, SwipeDirection dir) {
    _toast('قبلاً این فرد رو سوپرلایک کردی.');
  }

  void _rewind() {
    if (_history.isEmpty || _deck.isFlying) return;
    final last = _history.removeLast();
    _deck.prepareRewind(last.direction);
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = [last.candidate, ..._stack];
    });
    if (last.direction != SwipeDirection.left) {
      ApiClient.removeLike(last.candidate.publicId).catchError((_) {});
    }
  }

  void _removeBlocked(DiscoveryCandidate c) {
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = _stack.where((x) => x.publicId != c.publicId).toList();
    });
    if (_stack.length < 5) _loadMore();
    _precacheTop();
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
                    child: Image.network('$backendBaseUrl${match.photoUrl}',
                        width: 100, height: 100, fit: BoxFit.cover),
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
    return Scaffold(
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
      return _centerMessage(
        icon: widget.category.icon,
        title: 'فعلاً کسی تو این دسته پیدا نشد.',
        subtitle: 'بعداً دوباره سر بزن، یا شعاعِ فاصله‌ت رو تو تنظیماتِ سواپ زیاد کن.',
        actions: [_pillButton('تلاش دوباره', _reload)],
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
        Positioned(
          left: 0,
          right: 0,
          bottom: SwipeMetrics.buttonsBottom,
          child: SwipeActionBar(
            progress: _deck.progress,
            extended: true,
            canRewind: _history.isNotEmpty,
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
