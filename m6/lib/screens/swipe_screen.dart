import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../api_client.dart';
import '../models/match_models.dart';
import '../models/profile_models.dart';
import '../swipe/swipe_action_bar.dart';
import '../swipe/swipe_card.dart';
import '../swipe/swipe_deck.dart';
import '../swipe/swipe_header.dart';
import '../swipe/swipe_onboarding_store.dart';
import '../swipe/swipe_style.dart';
import '../widgets/profile_detail_sheet.dart';
import 'location_picker_screen.dart';
import 'matches_screen.dart';

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

  const SwipeScreen({super.key, this.onOpenMatches});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeRecord {
  final DiscoveryCandidate candidate;
  final SwipeDirection direction;
  _SwipeRecord(this.candidate, this.direction);
}

class _SwipeScreenState extends State<SwipeScreen> {
  /// شعاع تب «نزدیک» (کیلومتر).
  static const double _nearbyKm = 30;

  final SwipeDeckController _deck = SwipeDeckController();

  List<DiscoveryCandidate> _stack = [];
  final Set<String> _excluded = {};
  final List<_SwipeRecord> _history = [];

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
    _init();
  }

  @override
  void dispose() {
    _deck.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // داده
  // ---------------------------------------------------------------------

  Future<void> _init() async {
    // سقف زمانی برای مرحله‌ی لوکیشن (بعضی پلتفرم‌ها تو دیالوگ مجوز گیر می‌کنن).
    await _tryUpdateLocation().timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    try {
      final options = await ApiClient.fetchProfileOptions();
      if (mounted) setState(() => _options = options);
    } catch (_) {}
    try {
      final profile = await ApiClient.fetchMyProfile();
      if (mounted) {
        setState(() {
          _interestedIn = profile.interestedIn;
          _myInterests = profile.interests.toSet();
        });
      }
    } catch (_) {}
    await _loadMore();
  }

  Future<void> _tryUpdateLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.low))
          .timeout(const Duration(seconds: 8));
      await ApiClient.updateLocation(position.latitude, position.longitude);
    } catch (_) {}
  }

  double? get _effectiveDistance {
    if (_tab == 1) {
      final d = _maxDistanceKm;
      if (d == null) return _nearbyKm;
      return d < _nearbyKm ? d : _nearbyKm;
    }
    return _maxDistanceKm;
  }

  Future<void> _loadMore() async {
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
      final candidates = await ApiClient.fetchDiscovery(
        minAge: _minAge,
        maxAge: _maxAge,
        maxDistanceKm: _effectiveDistance,
        exclude: _excluded.toList(),
        includeSwiped: _browsingAgain,
      );
      if (!mounted || gen != _generation) return;
      final existing = _stack.map((c) => c.publicId).toSet();
      setState(() {
        _stack = [
          ..._stack,
          ...candidates.where((c) => !existing.contains(c.publicId)),
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
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = [];
      _error = null;
    });
    _loadMore();
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
          NetworkImage('$backendBaseUrl${c.photos.first.url}'),
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
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = _stack.where((x) => !identical(x, c)).toList();
      _history.add(_SwipeRecord(c, dir));
      if (_history.length > 10) _history.removeAt(0);
    });
    if (_stack.length < 5) _loadMore();
    _precacheTop();
    _countOnboarding(direction);

    ApiClient.swipe(c.publicId, direction).then((result) {
      if (result.matched && result.match != null && mounted) {
        _showMatchDialog(result.match!);
      }
    }).catchError((_) {
      // ثبت swipe شکست خورد؛ چیز حیاتی‌ای از دست نرفته.
    });
  }

  void _countOnboarding(String direction) {
    if (!SwipeOnboarding.isActive) return;
    final finished = SwipeOnboarding.register(direction);
    setState(() => _remaining = SwipeOnboarding.remaining);
    if (finished) HapticFeedback.mediumImpact();
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
    _excluded.remove(last.candidate.publicId);
    _deck.prepareRewind(last.direction);
    setState(() {
      _expandedId = null;
      _lockedId = null;
      _stack = [last.candidate, ..._stack];
    });
    // لایک/سوپرلایکِ ثبت‌شده رو برمی‌داریم؛ برای «رد» endpoint جدایی نیست.
    if (last.direction != SwipeDirection.left) {
      ApiClient.removeLike(last.candidate.publicId).catchError((_) {});
    }
  }

  /// بعد از مسدودسازیِ موفق از تو کارت: کارت بدونِ ثبتِ سواپ از Deck برداشته می‌شه.
  void _removeBlocked(DiscoveryCandidate c) {
    _excluded.add(c.publicId);
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
                    child: Image.network(
                      '$backendBaseUrl${match.photoUrl}',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
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
          ),
        ),
      ),
    );
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
    setState(() {
      _stack = _stack.where((c) => c.publicId != candidate.publicId).toList();
    });
    try {
      final result = await ApiClient.swipe(candidate.publicId, direction);
      if (result.matched && result.match != null && mounted) {
        _showMatchDialog(result.match!);
      }
    } on ApiException catch (e) {
      if (e.code == 'already_super_liked') {
        _toast('قبلاً این فرد رو سوپرلایک کردی.');
      }
    } catch (_) {}
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
