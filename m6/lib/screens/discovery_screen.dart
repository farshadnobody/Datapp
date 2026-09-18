import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../models/match_models.dart';
import '../widgets/profile_detail_sheet.dart';
import 'location_picker_screen.dart';
import 'matches_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  List<DiscoveryCandidate> _stack = [];
  final Set<String> _excluded = {};
  ProfileOptions? _options;
  bool _loading = true;
  String? _error;

  // وقتی true باشه، یعنی تو حالت «دوباره ببین» هستیم — کسایی که قبلاً
  // لایک/رد/سوپرلایک کردی هم نشون داده می‌شن (با نشونه‌ی وضعیتشون).
  bool _browsingAgain = false;

  int _minAge = 18;
  int _maxAge = 100;
  double? _maxDistanceKm; // null = بدون محدودیت
  String? _interestedIn; // دنبال چه کسی می‌گردم — از پروفایل واقعی می‌گیریم

  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0;

  late AnimationController _exitController;
  Offset _exitTarget = Offset.zero;
  String _pendingDirection = 'pass'; // برای وقتی از دکمه (نه کشیدن) exit می‌شه

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )
      ..addListener(() {
        setState(() {
          _dragOffset = Offset.lerp(Offset.zero, _exitTarget, _exitController.value)!;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finishSwipe();
        }
      });
    _init();
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // یه سقف زمانی کلی رو کل مرحله‌ی لوکیشن می‌ذاریم — چون بعضی پلتفرم‌ها
    // (خصوصاً دسکتاپ/وب) گاهی تو دیالوگ مجوز GPS گیر می‌کنن و هیچ‌وقت جواب
    // نمی‌دن؛ بدون این سقف، کل صفحه برای همیشه تو حالت لودینگ می‌مونه.
    await _tryUpdateLocation().timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    try {
      final options = await ApiClient.fetchProfileOptions();
      if (mounted) setState(() => _options = options);
    } catch (_) {
      // نبود این اختیاریه — فقط برای نشون دادن متن سؤال‌های پرامپت لازمه.
    }
    try {
      final profile = await ApiClient.fetchMyProfile();
      if (mounted) setState(() => _interestedIn = profile.interestedIn);
    } catch (_) {
      // نبودش هم مشکلی نیست؛ فقط تو شیت فیلتر گزینه‌ی فعلی از پیش انتخاب نمی‌شه.
    }
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
        return; // بی‌خیال؛ بدون فاصله ادامه می‌دیم.
      }
      final position = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.low))
          .timeout(const Duration(seconds: 8));
      await ApiClient.updateLocation(position.latitude, position.longitude);
    } catch (_) {
      // موقعیت اختیاریه؛ اگه نشد، Discovery فقط بدون فاصله کار می‌کنه.
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final candidates = await ApiClient.fetchDiscovery(
        minAge: _minAge,
        maxAge: _maxAge,
        maxDistanceKm: _maxDistanceKm,
        exclude: _excluded.toList(),
        includeSwiped: _browsingAgain,
      );
      if (mounted) setState(() => _stack = [..._stack, ...candidates]);
    } on NetworkException {
      if (mounted) setState(() => _error = 'ارتباط با سرور برقرار نشد.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 'profile_required'
            ? 'اول باید پروفایلت رو تکمیل کنی.'
            : 'دریافت لیست با مشکل مواجه شد.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // دکمه‌ی «دوباره ببین» تو حالت «همه رو دیدی» — فیلترهای فعلی رو نگه می‌داره،
  // فقط اجازه می‌ده کسایی که قبلاً swipe کردی هم دوباره نشون داده بشن.
  void _seeEveryoneAgain() {
    HapticFeedback.lightImpact();
    setState(() {
      _browsingAgain = true;
      _stack = [];
      _excluded.clear();
    });
    _loadMore();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragAngle = _dragOffset.dx / 300;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    const threshold = 100.0;

    // اگه بیشتر عمودی کشیده شده باشه (نه افقی)، یعنی قصدش سوپرلایکه.
    if (_dragOffset.dy < -threshold && _dragOffset.dy.abs() > _dragOffset.dx.abs()) {
      _trySuperLikeExit();
      return;
    }
    if (_dragOffset.dx > threshold) {
      _animateExit('like');
    } else if (_dragOffset.dx < -threshold) {
      _animateExit('pass');
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _dragAngle = 0;
      });
    }
  }

  // اگه کسی که الان بالای صفه‌ست قبلاً سوپرلایک شده، دوباره نمی‌شه سوپرلایکش
  // کرد — کارت رو برمی‌گردونیم و یه پیام کوتاه نشون می‌دیم.
  void _trySuperLikeExit() {
    if (_stack.isNotEmpty && _stack.first.previousDirection == 'super_like') {
      setState(() {
        _dragOffset = Offset.zero;
        _dragAngle = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('قبلاً این فرد رو سوپرلایک کردی.')));
      return;
    }
    _animateExit('super_like');
  }

  void _animateExit(String direction) {
    if (_stack.isEmpty || _exitController.isAnimating) return;
    HapticFeedback.mediumImpact();
    _pendingDirection = direction;
    switch (direction) {
      case 'like':
        _exitTarget = Offset(600, _dragOffset.dy);
        break;
      case 'pass':
        _exitTarget = Offset(-600, _dragOffset.dy);
        break;
      case 'super_like':
        _exitTarget = Offset(_dragOffset.dx, -600);
        break;
    }
    _exitController.forward(from: 0);
  }

  void _finishSwipe() {
    if (_stack.isEmpty) return;
    final swiped = _stack.first;
    final direction = _pendingDirection;

    _excluded.add(swiped.publicId);
    setState(() {
      _stack = _stack.skip(1).toList();
      _dragOffset = Offset.zero;
      _dragAngle = 0;
    });
    _exitController.reset();
    if (_stack.length < 5) {
      _loadMore();
    }

    ApiClient.swipe(swiped.publicId, direction).then((result) {
      if (result.matched && result.match != null && mounted) {
        _showMatchDialog(result.match!);
      }
    }).catchError((_) {
      // اگه ثبت swipe شکست بخوره، فقط بی‌خیال می‌شیم — کارت که رد شده برنمی‌گرده،
      // ولی چیز حیاتی‌ای هم از دست نرفته.
    });
  }

  Future<void> _removeLike(DiscoveryCandidate candidate) async {
    HapticFeedback.lightImpact();
    setState(() {
      _stack = _stack.where((c) => c.publicId != candidate.publicId).toList();
    });
    try {
      await ApiClient.removeLike(candidate.publicId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('حذف لایک با مشکل مواجه شد.')));
      }
    }
  }

  void _showMatchDialog(MatchSummary match) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text('متچ شدی!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
              Text('تو و ${match.name} همدیگه رو لایک کردین!',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text('ادامه‌ی کشف'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MatchesScreen()),
                  );
                },
                child: const Text('دیدن متچ‌ها'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String> get _promptTextMap {
    if (_options == null) return {};
    return {for (final p in _options!.prompts) p.id: p.text};
  }

  Map<String, String> get _interestLabelMap {
    if (_options == null) return {};
    return {for (final i in _options!.interests) i.id: i.label};
  }

  void _openFilters() {
    int tempMin = _minAge;
    int tempMax = _maxAge;
    double? tempDistance = _maxDistanceKm;
    String? tempInterestedIn = _interestedIn;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('فیلترها',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('دنبال چه کسی می‌گردم:'),
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
                Text('بازه‌ی سن: $tempMin تا $tempMax'),
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
                Text(tempDistance == null
                    ? 'حداکثر فاصله: بدون محدودیت'
                    : 'حداکثر فاصله: ${tempDistance!.round()} کیلومتر'),
                Slider(
                  min: 1,
                  max: 200,
                  divisions: 199,
                  value: tempDistance ?? 200,
                  onChanged: (v) => setSheetState(() => tempDistance = v >= 200 ? null : v),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);

                    if (tempInterestedIn != null && tempInterestedIn != _interestedIn) {
                      try {
                        await ApiClient.updateInterestedIn(tempInterestedIn!);
                      } catch (_) {
                        // اگه ذخیره نشد، فیلتر رو فقط همین session اعمال می‌کنیم.
                      }
                    }

                    setState(() {
                      _minAge = tempMin;
                      _maxAge = tempMax;
                      _maxDistanceKm = tempDistance;
                      _interestedIn = tempInterestedIn;
                      _stack = [];
                    });
                    _loadMore();
                  },
                  child: const Text('اعمال فیلتر'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _openDetail(DiscoveryCandidate candidate) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ProfileDetailSheet(
          candidate: candidate,
          promptTextMap: _promptTextMap,
          interestLabelMap: _interestLabelMap,
          scrollController: scrollController,
          onSwipe: (direction) => _swipeFromDetail(candidate, direction),
        ),
      ),
    );
  }

  // برای وقتی از تو شیت جزئیات (چه با تپ رو کارت، چه از نتیجه‌ی جستجو) لایک/
  // رد/سوپرلایک می‌زنی — لازم نیست حتماً تو صف اصلی swipe باشه.
  Future<void> _swipeFromDetail(DiscoveryCandidate candidate, String direction) async {
    Navigator.pop(context); // شیت رو ببند
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
      if (e.code == 'already_super_liked' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('قبلاً این فرد رو سوپرلایک کردی.')));
      }
    } catch (_) {
      // چیز حیاتی‌ای از دست نرفته؛ بی‌خیال می‌شیم.
    }
  }

  void _openSearch() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('جستجو با آیدی'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'آیدی فرد رو وارد کن'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = controller.text.trim();
              Navigator.pop(context);
              if (id.isNotEmpty) _searchAndShow(id);
            },
            child: const Text('جستجو'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAndShow(String publicId) async {
    try {
      final candidate = await ApiClient.fetchDiscoveryProfile(publicId);
      if (mounted) _openDetail(candidate);
    } on NetworkException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ارتباط با سرور برقرار نشد.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('پروفایلی با این آیدی پیدا نشد.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_browsingAgain ? 'کشف (بازبینی)' : 'کشف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'جستجو با آیدی',
            onPressed: _openSearch,
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'انتخاب موقعیت رو نقشه',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
              );
              if (changed == true) {
                setState(() => _stack = []);
                _loadMore();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.tune), onPressed: _openFilters),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _stack.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stack.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMore, child: const Text('تلاش دوباره')),
          ]),
        ),
      );
    }
    if (_stack.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = min(_stack.length, 3) - 1; i >= 1; i--)
                  Transform.translate(
                    offset: Offset(0, i * 8),
                    child: Transform.scale(
                      scale: 1 - i * 0.03,
                      child: _buildCardContent(_stack[i]),
                    ),
                  ),
                _buildTopCard(_stack.first),
              ],
            ),
          ),
        ),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildEmptyState() {
    // حالت عادی که هیچ‌کس (حتی قبلاً swipe‌شده) موجود نیست — یعنی هیچ‌کس تو
    // شعاع/بازه‌ی فیلترت اصلاً وجود نداره.
    if (_browsingAgain) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.explore_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('کسی با این فیلترها پیدا نشد.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _openFilters, child: const Text('تنظیم فیلترها')),
          ]),
        ),
      );
    }

    // حالت «همه رو دیدی» — پیشنهاد می‌دیم دوباره (با اولویت‌بندی) نگاهی بندازه.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('همه رو دیدی!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('همه‌ی افراد اطرافت رو دیدی.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _seeEveryoneAgain,
            icon: const Icon(Icons.refresh),
            label: const Text('دوباره ببین'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _openFilters, child: const Text('تنظیم فیلترها')),
        ]),
      ),
    );
  }

  Widget _buildTopCard(DiscoveryCandidate candidate) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: () => _openDetail(candidate),
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _dragAngle,
          child: Stack(
            children: [
              _buildCardContent(candidate),
              if (_dragOffset.dx > 0 && _dragOffset.dx.abs() >= _dragOffset.dy.abs())
                Positioned(
                  top: 24,
                  left: 24,
                  child: Opacity(
                    opacity: (_dragOffset.dx / 100).clamp(0, 1),
                    child: _buildBadge('لایک', Colors.green, -0.3),
                  ),
                ),
              if (_dragOffset.dx < 0 && _dragOffset.dx.abs() >= _dragOffset.dy.abs())
                Positioned(
                  top: 24,
                  right: 24,
                  child: Opacity(
                    opacity: (-_dragOffset.dx / 100).clamp(0, 1),
                    child: _buildBadge('رد', Colors.red, 0.3),
                  ),
                ),
              if (_dragOffset.dy < 0 && _dragOffset.dy.abs() > _dragOffset.dx.abs())
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: (-_dragOffset.dy / 100).clamp(0, 1),
                      child: _buildBadge('سوپرلایک', Colors.blue, 0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCardContent(DiscoveryCandidate candidate) {
    final photoUrl =
        candidate.photos.isNotEmpty ? '$backendBaseUrl${candidate.photos.first.url}' : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUrl != null)
              Image.network(photoUrl, fit: BoxFit.cover)
            else
              Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 96, color: Colors.white),
              ),
            // فقط تو حالت «دوباره ببین» نشون داده می‌شه — وضعیت قبلی این فرد.
            if (_browsingAgain && candidate.previousDirection != null)
              Positioned(
                top: 12,
                right: 12,
                child: _statusBadge(candidate.previousDirection!),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${candidate.name}, ${candidate.age}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ),
                        // دکمه‌ی سریع برای رفتن به جزئیات کامل پروفایل، کنار اسم.
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.white),
                          onPressed: () => _openDetail(candidate),
                        ),
                      ],
                    ),
                    if (candidate.distanceKm != null)
                      Text('${candidate.distanceKm} کیلومتر دورتر',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String direction) {
    final (icon, label, color) = switch (direction) {
      'like' => (Icons.favorite, 'لایک کردی', Colors.pink),
      'super_like' => (Icons.star, 'سوپرلایک کردی', Colors.blue),
      _ => (Icons.close, 'رد کردی', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final topCandidate = _stack.isNotEmpty ? _stack.first : null;
    final alreadyLiked = topCandidate?.previousDirection == 'like' ||
        topCandidate?.previousDirection == 'super_like';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionButton(Icons.close, Colors.red, () => _animateExit('pass')),
          _actionButton(Icons.star, Colors.blue, _trySuperLikeExit, small: true),
          // تو حالت «دوباره ببین»، رو کسی که قبلاً لایک/سوپرلایک کردی، به‌جای
          // دکمه‌ی لایک، دکمه‌ی «حذف لایک» نشون می‌دیم.
          if (_browsingAgain && alreadyLiked)
            _actionButton(Icons.delete_outline, Colors.grey, () {
              if (topCandidate != null) _removeLike(topCandidate);
            })
          else
            _actionButton(Icons.favorite, Colors.green, () => _animateExit('like')),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap, {bool small = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: CircleAvatar(
        radius: small ? 20 : 28,
        backgroundColor: Colors.white,
        child: Icon(icon, color: color, size: small ? 20 : 28),
      ),
    );
  }
}
